

terraform {
  required_version = ">= 1.5.0"
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

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}


resource "aws_security_group" "rds" {
  name        = "${var.db_identifier}-sg"
  description = "RDS access for ${var.db_identifier}"
  vpc_id      = var.vpc_id


  ingress {
    description      = "App/EKS to RDS"
    from_port        = var.db_port
    to_port          = var.db_port
    protocol         = "tcp"
    security_groups  = [var.app_sg_id] # only this SG can connect
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}


resource "aws_db_subnet_group" "rds" {
  name       = "${var.db_identifier}-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}


resource "aws_db_parameter_group" "rds" {
  name        = "${var.db_identifier}-params"
  family      = var.engine_family          # e.g., "postgres16" or "mysql8.0"
  description = "Parameters for ${var.db_identifier}"

  # Add your favorite tuning here:
  parameters = [
    {
      name  = "log_min_duration_statement"
      value = "250"            # ms
    },
    {
      name  = "rds.force_ssl"
      value = "1"
      apply_method = "pending-reboot"
    }
  ]

  tags = var.tags
}


resource "random_password" "db" {
  length           = 32
  special          = true
  override_characters = "!@#%^*-_=+?"
}

resource "aws_secretsmanager_secret" "db" {
  name = "${var.db_identifier}/credentials"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id     = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.db.result
  })
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
  name               = "${var.db_identifier}-monitoring"
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}


resource "aws_db_instance" "rds" {
  identifier                  = var.db_identifier
  engine                      = var.engine              # "postgres" | "mysql"
  engine_version              = var.engine_version      # e.g., "16.3" or "8.0.36"
  instance_class              = var.instance_class      # e.g., "db.t4g.medium"
  allocated_storage           = var.allocated_storage
  max_allocated_storage       = var.max_allocated_storage

  username                    = var.master_username
  password                    = random_password.db.result

  port                        = var.db_port
  db_subnet_group_name        = aws_db_subnet_group.rds.name
  vpc_security_group_ids      = [aws_security_group.rds.id]
  parameter_group_name        = aws_db_parameter_group.rds.name

  multi_az                    = var.multi_az
  storage_type                = "gp3"
  iops                        = var.iops
  storage_throughput          = var.storage_throughput

  backup_retention_period     = var.backup_retention_days
  backup_window               = var.backup_window
  maintenance_window          = var.maintenance_window
  auto_minor_version_upgrade  = true
  apply_immediately           = false

  deletion_protection         = var.deletion_protection
  skip_final_snapshot         = var.skip_final_snapshot
  final_snapshot_identifier   = var.skip_final_snapshot ? null : "${var.db_identifier}-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  performance_insights_enabled = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_retention
  monitoring_interval          = var.monitoring_interval   # >= 1 to enable EM
  monitoring_role_arn          = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring.arn : null

  publicly_accessible          = false
  copy_tags_to_snapshot        = true

  # Require SSL at the client level (pair with rds.force_ssl in parameter group)
  ca_cert_identifier           = var.ca_cert_identifier    # e.g., "rds-ca-rsa2048-g1"

  tags = var.tags

  depends_on = [
    aws_secretsmanager_secret_version.db
  ]
}


output "rds_endpoint" {
  value = aws_db_instance.rds.address
}

output "rds_port" {
  value = aws_db_instance.rds.port
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}
