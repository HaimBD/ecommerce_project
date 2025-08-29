############################################
# main.tf — Amazon OpenSearch (Elasticsearch) on AWS
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

# Optional: Security group that only allows inbound 443 from your app subnets / CIDR
resource "aws_security_group" "opensearch" {
  name        = "${var.domain_name}-sg"
  description = "Security group for OpenSearch domain ${var.domain_name}"
  vpc_id      = var.vpc_id

  # Allow HTTPS from app CIDRs / SGs (pick one)
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

# ----------------------------
# OpenSearch Domain
# ----------------------------
resource "aws_opensearch_domain" "this" {
  domain_name    = var.domain_name
  engine_version = var.engine_version # e.g., "OpenSearch_2.11" (or newer)

  # ---- Capacity / AZ awareness ----
  cluster_config {
    instance_type            = var.instance_type        # e.g., "m6g.large.search"
    instance_count           = var.instance_count       # e.g., 2 or 3
    dedicated_master_enabled = var.master_enabled
    dedicated_master_type    = var.master_instance_type
    dedicated_master_count   = var.master_instance_count

    zone_awareness_enabled = var.zone_awareness_enabled
    dynamic "zone_awareness_config" {
      for_each = var.zone_awareness_enabled ? [1] : []
      content {
        availability_zone_count = var.availability_zone_count # usually 2 or 3
      }
    }

    warm_enabled = var.ultrawarm_enabled
    warm_type    = var.ultrawarm_type
    warm_count   = var.ultrawarm_count
  }

  # ---- Storage ----
  ebs_options {
    ebs_enabled = true
    volume_type = var.ebs_volume_type # "gp3"
    volume_size = var.ebs_volume_size # in GiB
    iops        = var.ebs_iops        # only for certain types (e.g., io1, gp3)
    throughput  = var.ebs_throughput  # gp3 only
  }

  # ---- Networking (VPC only) ----
  vpc_options {
    subnet_ids         = var.subnet_ids         # private subnets recommended
    security_group_ids = [aws_security_group.opensearch.id]
  }

  # ---- Security ----
  encrypt_at_rest {
    enabled    = true
    kms_key_id = var.kms_key_id # null to use AWS managed key
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https                   = true
    tls_security_policy             = var.tls_security_policy # "Policy-Min-TLS-1-2-2019-07"
    custom_endpoint_enabled         = var.custom_endpoint_enabled
    custom_endpoint                 = var.custom_endpoint
    custom_endpoint_certificate_arn = var.custom_endpoint_certificate_arn
  }

  # ---- FGAC (Fine-Grained Access Control) ----
  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = var.fgac_internal_user_db
    master_user_options {
      master_user_name     = var.master_user_name
      master_user_password = var.master_user_password
    }
  }

  # ---- Cognito auth to Dashboards (optional) ----
  dynamic "cognito_options" {
    for_each = var.cognito_enabled ? [1] : []
    content {
      enabled          = true
      user_pool_id     = var.cognito_user_pool_id
      identity_pool_id = var.cognito_identity_pool_id
      role_arn         = var.cognito_role_arn
    }
  }

  # ---- Logs ----
  log_publishing_options {
    log_type = "INDEX_SLOW_LOGS"
    cloudwatch_log_group_arn = var.cw_log_group_arn
    enabled = true
  }

  log_publishing_options {
    log_type = "SEARCH_SLOW_LOGS"
    cloudwatch_log_group_arn = var.cw_log_group_arn
    enabled = true
  }

  log_publishing_options {
    log_type = "ES_APPLICATION_LOGS"
    cloudwatch_log_group_arn = var.cw_log_group_arn
    enabled = true
  }

  # Daily snapshot time (UTC hour 0..23)
  snapshot_options {
    automated_snapshot_start_hour = var.automated_snapshot_start_hour
  }

  # ---- Access policy: allow IAM principals in this account ----
  access_policies = data.aws_iam_policy_document.opensearch_access.json

  tags = var.tags
}

# Least-privilege IAM policy document (adjust as needed)
data "aws_iam_policy_document" "opensearch_access" {
  statement {
    sid    = "AllowAccountIAM"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.allowed_iam_arns != null && length(var.allowed_iam_arns) > 0
        ? var.allowed_iam_arns
        : ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = [
      "es:ESHttpGet",
      "es:ESHttpHead",
      "es:ESHttpPost",
      "es:ESHttpPut",
      "es:ESHttpDelete"
    ]

    resources = [
      aws_opensearch_domain.this.arn,
      "${aws_opensearch_domain.this.arn}/*"
    ]

    # OPTIONAL: additionally restrict by source VPC/SG with condition keys
    # condition {
    #   test     = "StringEquals"
    #   variable = "aws:sourceVpce"
    #   values   = [aws_vpc_endpoint.es.id]
    # }
  }
}

# ----------------------------
# (Optional) CloudWatch Log Group
# ----------------------------
resource "aws_cloudwatch_log_group" "opensearch" {
  name              = "/aws/opensearch/${var.domain_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# Output endpoints
output "opensearch_endpoint" {
  value = aws_opensearch_domain.this.endpoint
}

output "opensearch_dashboard_url" {
  value = "https://${aws_opensearch_domain.this.endpoint}/_dashboards/"
}
