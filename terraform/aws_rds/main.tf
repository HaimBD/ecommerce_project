############################################
# modules/rds/main.tf  (AWS provider v5.x)
############################################

terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

############################################
# Password generation (used unless provided)
############################################
resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!@#%^*-_=+?"
}

locals {
  effective_app_sg_ids = length(var.app_sg_ids) > 0 ? var.app_sg_ids : (var.app_sg_id == null ? [] : [var.app_sg_id])
  db_password          = coalesce(var.master_password, random_password.db.result)
}

############################################
# Store credentials in Secrets Manager
# (include environment in the name to avoid collisions)
############################################
resource "aws_secretsmanager_secret" "db" {
  name = "${var.db_identifier}-${var.environment}/credentials"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.master_username
    password = local.db_password
  })
}

############################################
# Networking
############################################
resource "aws_security_group" "rds" {
  name        = "${var.db_identifier}-sg"
  description = "RDS SG for ${var.db_identifier}"
  vpc_id      = var.vpc_id

  ingress {
    description     = "App/EKS SGs to RDS"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = local.effective_app_sg_ids
  }

  dynamic "ingress" {
    for_each = length(var.allowed_cidrs) > 0 ? [true] : []
    content {
      description = "Allowed CIDRs to RDS"
      from_port   = var.db_port
      to_port     = var.db_port
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.db_identifier}-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

resource "aws_db_parameter_group" "this" {
  name        = "${var.db_identifier}-params"
  family      = var.engine_family
  description = "Parameters for ${var.db_identifier}"

  parameter {
    name  = "log_min_duration_statement"
    value = "250"
  }

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  tags = var.tags
}

data "aws_iam_policy_document" "monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  count              = var.monitoring_interval > 0 ? 1 : 0
  name               = "${var.db_identifier}-monitoring"
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count      = var.monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "this" {
  identifier = var.db_identifier

  engine         = var.engine
  engine_version = var.engine_version

  instance_class = var.instance_class
  port           = var.db_port

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  iops                  = var.iops
  storage_throughput    = var.storage_throughput
  storage_encrypted     = true
  kms_key_id            = var.kms_key_id

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  username                             = var.master_username
  password                             = local.db_password
  parameter_group_name                 = aws_db_parameter_group.this.name
  iam_database_authentication_enabled  = var.enable_iam_auth

  multi_az                        = var.multi_az
  allow_major_version_upgrade     = var.allow_major_version_upgrade
  auto_minor_version_upgrade      = true
  backup_retention_period         = var.backup_retention_days
  backup_window                   = var.backup_window
  maintenance_window              = var.maintenance_window
  copy_tags_to_snapshot           = true
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = var.skip_final_snapshot
  final_snapshot_identifier       = var.skip_final_snapshot ? null : "${var.db_identifier}-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  monitoring_interval                   = var.monitoring_interval
  monitoring_role_arn                   = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_retention
  performance_insights_kms_key_id       = var.performance_insights_kms_key_id

  ca_cert_identifier = var.ca_cert_identifier

  tags = var.tags

  depends_on = [
    aws_secretsmanager_secret_version.db
  ]
}

output "security_group_id" {
  value = aws_security_group.rds.id
}

output "db_subnet_group_name" {
  value = aws_db_subnet_group.this.name
}

output "db_parameter_group_name" {
  value = aws_db_parameter_group.this.name
}

output "db_instance_id" {
  value = aws_db_instance.this.id
}

output "db_endpoint" {
  value = aws_db_instance.this.address
}

output "db_port" {
  value = aws_db_instance.this.port
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}
