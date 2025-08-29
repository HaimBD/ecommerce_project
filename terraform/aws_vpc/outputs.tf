# output "vpc_public_subnets" {
#   description = "IDs of the VPC's public subnets"
#   value       = module.aws_vpc.public_subnets
# }
# output "vpc_id"              { value = module.aws_vpc.vpc_id }
# output "public_subnets_ids"  { value = module.aws_vpc.public_subnet_ids }
# output "private_subnets_ids" { value = module.aws_vpc.private_subnet_ids }

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets_ids" {
  value = module.vpc.public_subnets
}

output "private_subnets_ids" {
  value = module.vpc.private_subnets
}
