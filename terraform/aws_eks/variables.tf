############################################
# modules/aws_eks/variables.tf
############################################

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of subnet IDs to use for the EKS cluster"
  type        = list(string)
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment tag (e.g., dev, staging, prod)"
  type        = string
}

variable "eks_public_endpoint_cidrs" {
  description = "CIDRs allowed to access the EKS public API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# NEW: the IAM principal that should have cluster-admin via EKS Access Entries
variable "admin_principal_arn" {
  description = "IAM principal ARN (role/user) to grant EKS admin access"
  type        = string
}

# Optional: if you want providers to use a named profile locally
variable "aws_profile" {
  description = "Optional AWS profile name to export to 'exec' auth env"
  type        = string
  default     = null
}

variable "enable_external_dns" {
  description = "Enable the ExternalDNS Helm chart"
  type        = bool
  default     = false
}

variable "enable_fluentbit" {
  description = "Enable Fluent Bit Helm chart for CloudWatch logs"
  type        = bool
  default     = false
}

variable "enable_cloudwatch_observability" {
  description = "Enable CloudWatch observability addon (if supported)"
  type        = bool
  default     = false
}

variable "enable_adot" {
  description = "Enable AWS Distro for OpenTelemetry (ADOT) addon"
  type        = bool
  default     = false
}

variable "alb_chart_version" {
  description = "Helm chart version for AWS Load Balancer Controller"
  type        = string
  default     = "1.8.1"
}

variable "metrics_server_chart_version" {
  description = "Helm chart version for Metrics Server"
  type        = string
  default     = "3.12.1"
}

variable "cluster_autoscaler_chart_version" {
  description = "Helm chart version for Cluster Autoscaler"
  type        = string
  default     = "9.43.1"
}

variable "external_dns_chart_version" {
  description = "Helm chart version for ExternalDNS"
  type        = string
  default     = "1.14.4"
}

variable "fluentbit_chart_version" {
  description = "Helm chart version for aws-for-fluent-bit"
  type        = string
  default     = "0.39.1"
}
