############################################
# modules/rds/variables.tf
############################################

# Core networking
variable "vpc_id" {
  type        = string
  description = "VPC ID where the DB will live."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the DB subnet group."
}

# You can pass either a single SG id or a list
variable "app_sg_id" {
  type        = string
  default     = null
  description = "Optional single security group allowed to reach the DB."
}

variable "app_sg_ids" {
  type        = list(string)
  default     = []
  description = "Optional list of security groups allowed to reach the DB."
}

variable "allowed_cidrs" {
  type        = list(string)
  default     = []
  description = "Optional CIDR blocks allowed to reach the DB (use sparingly)."
}

# DB identity & engine
variable "db_identifier" {
  type        = string
  description = "DB instance identifier."
}

variable "engine" {
  type        = string
  default     = "postgres"
  description = "Database engine: postgres or mysql."
}

variable "engine_version" {
  type        = string
  default     = "16.3"
  description = "Engine version (e.g., 16.3 for Postgres, 8.0.xx for MySQL)."
}

variable "engine_family" {
  type        = string
  default     = "postgres16"
  description = "Parameter group family (e.g., postgres16 or mysql8.0)."
}

variable "db_port" {
  type        = number
  default     = 5432
  description = "DB port (5432 for Postgres, 3306 for MySQL)."
}

# Instance & storage
variable "instance_class" {
  type        = string
  default     = "db.t4g.medium"
  description = "Instance class (e.g., db.t4g.medium)."
}

variable "allocated_storage" {
  type        = number
  default     = 50
  description = "Initial storage (GiB)."
}

variable "max_allocated_storage" {
  type        = number
  default     = 200
  description = "Autoscaling storage cap (GiB)."
}

variable "iops" {
  type        = number
  default     = null
  description = "Optional IOPS for gp3."
}

variable "storage_throughput" {
  type        = number
  default     = null
  description = "Optional throughput for gp3."
}

variable "kms_key_id" {
  type        = string
  default     = null
  description = "KMS key for storage encryption (null = AWS managed)."
}

# Availability & operations
variable "multi_az" {
  type        = bool
  default     = true
  description = "Enable Multi-AZ for HA."
}

variable "allow_major_version_upgrade" {
  type        = bool
  default     = false
  description = "Allow major version upgrades."
}

variable "backup_retention_days" {
  type        = number
  default     = 7
  description = "Automated backup retention (days)."
}

variable "backup_window" {
  type        = string
  default     = "03:00-04:00"
  description = "Preferred backup window (UTC)."
}

variable "maintenance_window" {
  type        = string
  default     = "sun:04:00-sun:05:00"
  description = "Preferred maintenance window (UTC)."
}

variable "deletion_protection" {
  type        = bool
  default     = true
  description = "Protect DB from deletion."
}

variable "skip_final_snapshot" {
  type        = bool
  default     = false
  description = "Skip final snapshot on destroy."
}

variable "ca_cert_identifier" {
  type        = string
  default     = "rds-ca-rsa2048-g1"
  description = "RDS CA bundle for TLS."
}

# Monitoring & Performance Insights
variable "monitoring_interval" {
  type        = number
  default     = 15
  description = "Enhanced Monitoring interval in seconds (0 disables EM)."
}

variable "performance_insights_enabled" {
  type        = bool
  default     = true
  description = "Enable Performance Insights."
}

variable "performance_insights_retention" {
  type        = number
  default     = 7
  description = "PI retention in days (7 or 731)."
}

variable "performance_insights_kms_key_id" {
  type        = string
  default     = null
  description = "KMS key for Performance Insights (optional)."
}

# Auth
variable "master_username" {
  type        = string
  default     = "appuser"
  description = "Master username."
}

variable "master_password" {
  type        = string
  default     = "Pa55w.rd"
  sensitive   = true
  description = "Master password (null = auto-generate and store in Secrets Manager)."
}

variable "enable_iam_auth" {
  type        = bool
  default     = false
  description = "Enable IAM database authentication."
}

# NEW: pass env so the secret name is unique (avoids 'scheduled for deletion' conflict)
variable "environment" {
  type        = string
  description = "Environment name used to scope the secret name (e.g. production, staging)."
}

# Tags
variable "tags" {
  type = map(string)
  default = {
    Project     = "terraform"
    Environment = "production"
  }
  description = "Tags to apply to created resources."
}
