variable "region"          { type = string }
variable "cluster_name"    { type = string }
variable "oidc_provider_arn" { type = string }

variable "enable_irsa_alb"               {
    type = bool
    default = true
    }
variable "enable_irsa_cluster_autoscaler"{
    type = bool
    default = true
    }
variable "enable_irsa_external_dns"      {
    type = bool
    default = false
    }
variable "enable_irsa_fluent_bit"        {
    type = bool
    default = false
    }
variable "enable_irsa_ebs_csi"           {
    type = bool
    default = true
    }

variable "tags" {
  type = map(string)
  default = {
    Project     = "project"
    Environment = "production"
  }
}
