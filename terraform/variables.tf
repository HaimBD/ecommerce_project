
# Identity variables
variable "region" {
  type    = string
  default = "us-east-1"
}

variable "tags" {
  type = map(string)
  default = {
      environment = "production"
      project_name = "ecommerce"
      }
  description = "Tags to apply to the table."
}

variable "project" {
  type    = string
  default = "platform"
}

variable "environment" {
  type    = string
  default = "production"
}

variable "name" {
  type    = string
  default = "shared"
}

# VPC
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.3.0/24", "10.0.4.0/24"]
}

# --- EKS ---
variable "cluster_name" {
  type    = string
  default = "eks-ecommerce"
}

variable "cluster_version" {
  type    = string
  default = "1.30"
}

variable "enable_external_dns" {
  type    = bool
  default = false
}

variable "enable_fluentbit" {
  type    = bool
  default = false
}

variable "enable_cloudwatch_observability" {
  type    = bool
  default = false
}

# RDS
variable "db_engine" {
  type    = string
  default = "postgres"
}

variable "db_engine_version" {
  type    = string
  default = "16.3"
}

variable "db_engine_family" {
  type    = string
  default = "postgres16"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "db_allocated_storage" {
  type    = number
  default = 50
}

variable "db_max_allocated_storage" {
  type    = number
  default = 200
}

variable "db_backup_retention_days" {
  type    = number
  default = 7
}

variable "db_backup_window" {
  type    = string
  default = "03:00-04:00"
}

variable "db_maintenance_window" {
  type    = string
  default = "sun:04:00-sun:05:00"
}

variable "db_multi_az" {
  type    = bool
  default = true
}

variable "db_master_username" {
  type    = string
  default = "appuser"
}

variable "db_master_password" {
  type      = string
  default   = "Pa55w.rd"
  sensitive = true
}

# OpenSearch
variable "os_engine_version" {
  type    = string
  default = "OpenSearch_2.11"
}

variable "os_allowed_cidrs" {
  type    = list(string)
  default = []
}

variable "os_allowed_iam_arns" {
  type    = list(string)
  default = []
}

variable "os_kms_key_id" {
  type    = string
  default = null
}

variable "os_tls_security_policy" {
  type    = string
  default = "Policy-Min-TLS-1-2-2019-07"
}

variable "os_cw_log_group_arn" {
  type    = string
  default = null
}

variable "os_snapshot_hour" {
  type    = number
  default = 3
}

variable "os_instance_type" {
  type    = string
  default = "m6g.large.search"
}

variable "os_instance_count" {
  type    = number
  default = 2
}

variable "os_zone_awareness_enabled" {
  type    = bool
  default = true
}

variable "os_availability_zone_count" {
  type    = number
  default = 2
}

variable "os_master_enabled" {
  type    = bool
  default = true
}

variable "os_master_instance_type" {
  type    = string
  default = "m6g.large.search"
}

variable "os_master_instance_count" {
  type    = number
  default = 3
}

variable "os_ultrawarm_enabled" {
  type    = bool
  default = false
}

variable "os_ultrawarm_type" {
  type    = string
  default = "ultrawarm1.medium.search"
}

variable "os_ultrawarm_count" {
  type    = number
  default = 2
}

variable "os_ebs_volume_type" {
  type    = string
  default = "gp3"
}

variable "os_ebs_volume_size" {
  type    = number
  default = 100
}

variable "os_ebs_iops" {
  type    = number
  default = null
}

variable "os_ebs_throughput" {
  type    = number
  default = null
}

variable "os_fgac_internal_user_db" {
  type    = bool
  default = true
}

variable "os_master_user_name" {
  type    = string
  default = "admin"
}

variable "os_master_user_password" {
  type      = string
  default   = "Pa55w.rd"
  sensitive = true
}

variable "os_cognito_enabled" {
  type    = bool
  default = false
}

variable "os_cognito_user_pool_id" {
  type    = string
  default = null
}

variable "os_cognito_identity_pool_id" {
  type    = string
  default = null
}

variable "os_cognito_role_arn" {
  type    = string
  default = null
}

variable "os_custom_endpoint_enabled" {
  type    = bool
  default = false
}

variable "os_custom_endpoint" {
  type    = string
  default = null
}

variable "os_custom_endpoint_certificate_arn" {
  type    = string
  default = null
}

variable "public_subnet_tags" {
  description = "Extra tags applied to each public subnet"
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Extra tags applied to each private subnet"
  type        = map(string)
  default     = {}
}

variable "eks_public_endpoint_cidrs" {
  description = "CIDRs allowed to access the EKS public API endpoint"
  type        = list(string)
  # Replace with your IP/32 for security, e.g. ["203.0.113.10/32"]
  default     = ["0.0.0.0/0"]
}
