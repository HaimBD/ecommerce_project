variable "vpc_name" {
  description = "VPC name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "vpc_private_subnets" {
  description = "Private subnet CIDRs"
  type        = list(string)
}

variable "vpc_public_subnets" {
  description = "Public subnet CIDRs"
  type        = list(string)
}

# NAT / VPN toggles
variable "enable_nat_gateway" {
  description = "Create NAT gateway(s)"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway for the whole VPC"
  type        = bool
  default     = true
}

variable "one_nat_gateway_per_az" {
  description = "Create one NAT per AZ (set to true only if single_nat_gateway=false)"
  type        = bool
  default     = false
}

# Tags
variable "tags" {
  description = "Tags for VPC and children"
  type        = map(string)
  default     = { Env = "Practice" }
}

variable "public_subnet_tags" {
  description = "Extra tags for each public subnet"
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Extra tags for each private subnet"
  type        = map(string)
  default     = {}
}
