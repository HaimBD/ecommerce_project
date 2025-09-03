# modules/aws_vpc/main.tf
data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs = slice(
    data.aws_availability_zones.available.names,
    0,
    max(length(var.vpc_public_subnets), length(var.vpc_private_subnets))
  )

  public_subnets  = var.vpc_public_subnets
  private_subnets = var.vpc_private_subnets

  # Correct flag name for this module version
  map_public_ip_on_launch = true

  # Internet/NAT
  enable_dns_support   = true
  enable_dns_hostnames = true
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  # Helpful tags for EKS/ALB
  public_subnet_tags = merge(
    { "kubernetes.io/role/elb" = "1" },
    var.public_subnet_tags
  )

  private_subnet_tags = merge(
    { "kubernetes.io/role/internal-elb" = "1" },
    var.private_subnet_tags
  )

  tags = var.tags
}
