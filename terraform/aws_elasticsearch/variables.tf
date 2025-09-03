variable "region"                  { type = string }
variable "domain_name"             {
    type = string
    default = "ecommerce"
    }
variable "engine_version"          {
    type = string
    default = "OpenSearch_2.11"
    }

variable "vpc_id"                  { type = string }
variable "subnet_ids"              { type = list(string) }
variable "allowed_cidrs"           {
    type = list(string)
    default = []
    }

variable "instance_type"           {
    type = string
    default = "m6g.large.search"
    }
variable "instance_count"          {
    type = number
    default = 2
    }
variable "zone_awareness_enabled"  {
    type = bool
    default = true
    }
variable "availability_zone_count" {
    type = number
    default = 2
    }
variable "master_enabled"          {
    type = bool
    default = true
    }
variable "master_instance_type"    {
    type = string
    default = "m6g.large.search"
    }
variable "master_instance_count"   {
    type = number
    default = 3
    }

variable "ultrawarm_enabled"       {
    type = bool
    default = false
    }
variable "ultrawarm_type"          {
    type = string
    default = "ultrawarm1.medium.search"
    }
variable "ultrawarm_count"         {
    type = number
    default = 2
    }

variable "ebs_volume_type"         {
    type = string
    default = "gp3"
    }
variable "ebs_volume_size"         {
    type = number
    default = 100
    }
variable "ebs_iops"                {
    type = number
    default = null
    }
variable "ebs_throughput"          {
    type = number
    default = null
    }

variable "kms_key_id"              {
    type = string
    default = null
    }
variable "tls_security_policy"     {
    type = string
    default = "Policy-Min-TLS-1-2-2019-07"
    }

variable "fgac_internal_user_db"   {
    type = bool
    default = true
    }
variable "master_user_name"        {
    type = string
    default = "admin"
    }
variable "master_user_password"    {
    type = string
    default = "Pa55w.rd"
    sensitive = true
    }

variable "cognito_enabled"         {
    type = bool
    default = false
    }
variable "cognito_user_pool_id"    {
    type = string
    default = null
    }
variable "cognito_identity_pool_id"{
    type = string
    default = null
    }
variable "cognito_role_arn"        {
    type = string
    default = null
    }

variable "cw_log_group_arn"        {
    type = string
    default = null
    }
variable "log_retention_days"      {
    type = number
    default = 30
    }
variable "automated_snapshot_start_hour" {
    type = number
    default = 3
    }

variable "allowed_iam_arns"        {
    type = list(string)
    default = null
    }

variable "custom_endpoint_enabled"         {
    type = bool
    default = false
    }
variable "custom_endpoint"                 {
    type = string
    default = null
    }
variable "custom_endpoint_certificate_arn" {
    type = string
    default = null
    }

variable "tags" {
  type = map(string)
  default = {
    Project     = "search"
    Environment = "production"
  }
}
