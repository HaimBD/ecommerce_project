############################################################
# root/main.tf — VPC (child), EKS on PUBLIC subnets, RDS, OpenSearch, DynamoDB
############################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0, < 6.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
    }
  }
}

# Who runs Terraform? Use this ARN for cluster admin
data "aws_caller_identity" "current" {}

locals {
  name         = var.name
  cluster_name = var.cluster_name
  db_name      = "${var.project}-db"
  os_domain    = "${var.project}-os"
  ddb_table    = "${var.project}-orders"
  admin_arn    = data.aws_caller_identity.current.arn
}

# -------------------------
# VPC (child module)
# -------------------------
module "vpc" {
  source = "./aws_vpc"

  vpc_name            = local.name
  vpc_cidr            = var.vpc_cidr
  vpc_public_subnets  = var.public_subnet_cidrs
  vpc_private_subnets = var.private_subnet_cidrs

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  public_subnet_tags  = var.public_subnet_tags
  private_subnet_tags = var.private_subnet_tags

  tags = {
    Project     = "platform"
    Environment = var.environment
  }
}

# -------------------------
# EKS (child) — USE PUBLIC SUBNETS
# -------------------------
module "eks" {
  source = "./aws_eks"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.public_subnet_ids

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version
  region          = var.region
  environment     = var.environment
  aws_profile     = "default"

  # ✅ Pass the principal to be granted cluster-admin
  admin_principal_arn       = local.admin_arn

  eks_public_endpoint_cidrs = var.eks_public_endpoint_cidrs

  enable_external_dns             = var.enable_external_dns
  enable_fluentbit                = var.enable_fluentbit
  enable_cloudwatch_observability = var.enable_cloudwatch_observability
}

# App SG
resource "aws_security_group" "app" {
  name        = "${var.project}-app"
  description = "App/EKS to data-plane access"
  vpc_id      = module.vpc.vpc_id
}

# -------------------------
# RDS (private subnets)
# -------------------------
module "rds" {
  source = "./aws_rds"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  app_sg_ids = compact([
    try(module.eks.node_security_group_id, null),
    aws_security_group.app.id
  ])

  environment           = var.environment
  db_identifier         = local.db_name
  engine                = var.db_engine
  engine_version        = var.db_engine_version
  engine_family         = var.db_engine_family
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  backup_retention_days = var.db_backup_retention_days
  maintenance_window    = var.db_maintenance_window
  backup_window         = var.db_backup_window
  multi_az              = var.db_multi_az
  master_username       = var.db_master_username
  master_password       = var.db_master_password

  tags = {
    Component   = "rds"
    Project     = var.project
    Environment = var.environment
  }
}

# -------------------------
# OpenSearch (private subnets)
# -------------------------
module "opensearch" {
  source         = "./aws_elasticsearch"
  region         = var.region
  domain_name    = local.os_domain
  engine_version = var.os_engine_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  allowed_cidrs    = length(var.os_allowed_cidrs) > 0 ? var.os_allowed_cidrs : [var.vpc_cidr]
  allowed_iam_arns = var.os_allowed_iam_arns

  kms_key_id                    = var.os_kms_key_id
  tls_security_policy           = var.os_tls_security_policy
  cw_log_group_arn              = var.os_cw_log_group_arn
  automated_snapshot_start_hour = var.os_snapshot_hour

  instance_type           = var.os_instance_type
  instance_count          = var.os_instance_count
  zone_awareness_enabled  = var.os_zone_awareness_enabled
  availability_zone_count = var.os_availability_zone_count
  master_enabled          = var.os_master_enabled
  master_instance_type    = var.os_master_instance_type
  master_instance_count   = var.os_master_instance_count

  ultrawarm_enabled = var.os_ultrawarm_enabled
  ultrawarm_type    = var.os_ultrawarm_type
  ultrawarm_count   = var.os_ultrawarm_count

  ebs_volume_type = var.os_ebs_volume_type
  ebs_volume_size = var.os_ebs_volume_size
  ebs_iops        = var.os_ebs_iops
  ebs_throughput  = var.os_ebs_throughput

  fgac_internal_user_db = var.os_fgac_internal_user_db
  master_user_name      = var.os_master_user_name
  master_user_password  = var.os_master_user_password

  cognito_enabled          = var.os_cognito_enabled
  cognito_user_pool_id     = var.os_cognito_user_pool_id
  cognito_identity_pool_id = var.os_cognito_identity_pool_id
  cognito_role_arn         = var.os_cognito_role_arn

  custom_endpoint_enabled         = var.os_custom_endpoint_enabled
  custom_endpoint                 = var.os_custom_endpoint
  custom_endpoint_certificate_arn = var.os_custom_endpoint_certificate_arn

  tags = {
    Component   = "opensearch"
    Project     = var.project
    Environment = var.environment
  }
}

# -------------------------
# DynamoDB
# -------------------------
module "dynamodb" {
  source        = "./aws_dynamodb"
  table_name    = local.ddb_table
  hash_key      = "order_id"
  hash_key_type = "S"
  billing_mode  = "PAY_PER_REQUEST"
  tags          = var.tags
}

# -------------------------
# Outputs
# -------------------------
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "eks_cluster_name" {
  value = var.cluster_name
}

output "rds_endpoint" {
  value = module.rds.db_endpoint
}

output "opensearch_endpoint" {
  value = try(module.opensearch.opensearch_endpoint, null)
}

output "dynamodb_table_name" {
  value = module.dynamodb.table_name
}
