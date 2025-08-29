variable "region"                 { type = string }
variable "vpc_id"                 { type = string }
variable "private_subnet_ids"     { type = list(string) }


variable "app_sg_id"              { type = string }

variable "db_identifier"          { type = string }
variable "engine"                 { type = string  default = "postgres" }     # "postgres" | "mysql"
variable "engine_version"         { type = string  default = "16.3" }
variable "engine_family"          { type = string  default = "postgres16" }   # "mysql8.0" for MySQL
variable "db_port"                { type = number  default = 5432 }           # 3306 for MySQL

variable "instance_class"         { type = string  default = "db.t4g.medium" }
variable "allocated_storage"      { type = number  default = 50 }             # GiB
variable "max_allocated_storage"  { type = number  default = 200 }            # autoscale cap
variable "iops"                   { type = number  default = null }           # gp3 optional
variable "storage_throughput"     { type = number  default = null }           # gp3 optional

variable "multi_az"               { type = bool    default = true }
variable "backup_retention_days"  { type = number  default = 7 }
variable "backup_window"          { type = string  default = "03:00-04:00" }
variable "maintenance_window"     { type = string  default = "sun:04:00-sun:05:00" }

variable "deletion_protection"    { type = bool    default = true }
variable "skip_final_snapshot"    { type = bool    default = false }
variable "ca_cert_identifier"     { type = string  default = "rds-ca-rsa2048-g1" }

variable "performance_insights_enabled"   { type = bool   default = true }
variable "performance_insights_retention" { type = number default = 7 } # or 731 for long-term

variable "monitoring_interval"    { type = number  default = 15 }       # 0 disables EM

variable "master_username"        { type = string  default = "appuser" }

variable "tags" {
  type = map(string)
  default = {
    Project     = "terraform"
    Environment = "production"
  }
}
