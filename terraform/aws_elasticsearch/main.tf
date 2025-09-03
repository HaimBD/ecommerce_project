############################################
# main.tf — Amazon OpenSearch on AWS
############################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  domain_name   = var.domain_name
  domain_arn    = "arn:${data.aws_partition.current.partition}:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${local.domain_name}"
  domain_arn_all = "${local.domain_arn}/*"

  os_allowed_principals = length(coalesce(var.allowed_iam_arns, [])) > 0 ? var.allowed_iam_arns : ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
}

# ----------------------------
# CloudWatch Log Group
# ----------------------------
resource "aws_cloudwatch_log_group" "opensearch" {
  name              = "/aws/opensearch/${local.domain_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# **IMPORTANT**: Resource policy to allow OpenSearch to write logs
data "aws_iam_policy_document" "cwl_for_opensearch" {
  statement {
    sid    = "AllowOpenSearchToWriteLogs"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["es.amazonaws.com"]
    }

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]

    resources = [
      "${aws_cloudwatch_log_group.opensearch.arn}:*",
      aws_cloudwatch_log_group.opensearch.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [local.domain_arn]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "opensearch" {
  policy_name     = "OpenSearchLogs-${local.domain_name}"
  policy_document = data.aws_iam_policy_document.cwl_for_opensearch.json
}

# ----------------------------
# Access policy (no cyclic refs)
# ----------------------------
data "aws_iam_policy_document" "opensearch_access" {
  statement {
    sid    = "AllowAccountIAM"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = local.os_allowed_principals
    }

    actions = [
      "es:ESHttpGet",
      "es:ESHttpHead",
      "es:ESHttpPost",
      "es:ESHttpPut",
      "es:ESHttpDelete"
    ]

    resources = [
      local.domain_arn,
      local.domain_arn_all
    ]
  }
}

resource "aws_security_group" "opensearch" {
  name        = "${local.domain_name}-sg"
  description = "Security group for OpenSearch domain ${local.domain_name}"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from application CIDR(s)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_opensearch_domain" "this" {
  domain_name    = local.domain_name
  engine_version = var.engine_version

  cluster_config {
    instance_type            = var.instance_type
    instance_count           = var.instance_count
    dedicated_master_enabled = var.master_enabled
    dedicated_master_type    = var.master_instance_type
    dedicated_master_count   = var.master_instance_count

    zone_awareness_enabled = var.zone_awareness_enabled
    dynamic "zone_awareness_config" {
      for_each = var.zone_awareness_enabled ? [1] : []
      content {
        availability_zone_count = var.availability_zone_count
      }
    }

    warm_enabled = var.ultrawarm_enabled
    warm_type    = var.ultrawarm_type
    warm_count   = var.ultrawarm_count
  }

  ebs_options {
    ebs_enabled = true
    volume_type = var.ebs_volume_type
    volume_size = var.ebs_volume_size
    iops        = var.ebs_iops
    throughput  = var.ebs_throughput
  }

  vpc_options {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.opensearch.id]
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = var.kms_key_id
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https                   = true
    tls_security_policy             = var.tls_security_policy
    custom_endpoint_enabled         = var.custom_endpoint_enabled
    custom_endpoint                 = var.custom_endpoint
    custom_endpoint_certificate_arn = var.custom_endpoint_certificate_arn
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = var.fgac_internal_user_db
    master_user_options {
      master_user_name     = var.master_user_name
      master_user_password = var.master_user_password
    }
  }

  dynamic "cognito_options" {
    for_each = var.cognito_enabled ? [1] : []
    content {
      enabled          = true
      user_pool_id     = var.cognito_user_pool_id
      identity_pool_id = var.cognito_identity_pool_id
      role_arn         = var.cognito_role_arn
    }
  }

  # Use the CW log group above; the resource policy allows OpenSearch to write
  log_publishing_options {
    log_type                 = "INDEX_SLOW_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    enabled                  = true
  }

  log_publishing_options {
    log_type                 = "SEARCH_SLOW_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    enabled                  = true
  }

  log_publishing_options {
    log_type                 = "ES_APPLICATION_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    enabled                  = true
  }

  snapshot_options {
    automated_snapshot_start_hour = var.automated_snapshot_start_hour
  }

  access_policies = data.aws_iam_policy_document.opensearch_access.json

  tags = var.tags

  depends_on = [
    aws_cloudwatch_log_resource_policy.opensearch
  ]
}

output "opensearch_endpoint" {
  value = aws_opensearch_domain.this.endpoint
}

output "opensearch_dashboard_url" {
  value = "https://${aws_opensearch_domain.this.endpoint}/_dashboards/"
}
