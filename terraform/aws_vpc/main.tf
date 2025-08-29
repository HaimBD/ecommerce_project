data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.0.1"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, max(length(var.vpc_public_subnets), length(var.vpc_private_subnets)))
  public_subnets  = var.vpc_public_subnets
  private_subnets = var.vpc_private_subnets

  # ensure public subnets auto-assign public IPs
  map_public_ip_on_launch = true

  enable_nat_gateway     = true
  one_nat_gateway_per_az = true
  enable_vpn_gateway     = false

  tags = var.tags
}
