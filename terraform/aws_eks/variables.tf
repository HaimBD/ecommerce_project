variable "region"                  { type = string }
variable "cluster_name"            { type = string }
variable "cluster_version"         { type = string default = "1.30" }
variable "vpc_id"                  { type = string }
variable "private_subnet_ids"      { type = list(string) }
variable "environment"             { type = string default = "production" }
variable "enable_external_dns"     { type = bool   default = false }
variable "enable_fluentbit"        { type = bool   default = false }
variable "enable_cloudwatch_observability" { type = bool default = false }

# Chart versions (pin if you want)
variable "alb_chart_version"             { type = string default = null }
variable "metrics_server_chart_version"  { type = string default = null }
variable "cluster_autoscaler_chart_version" { type = string default = null }
variable "external_dns_chart_version"    { type = string default = null }
variable "fluentbit_chart_version"       { type = string default = null }