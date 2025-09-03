# aws_vpc/outputs.tf

# Re-export basics from the inner terraform-aws-modules/vpc
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

# IMPORTANT: these are subnet **IDs**
output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.vpc.private_subnets
}

# (Optional but often handy)
output "public_route_table_ids" {
  description = "Public route table IDs"
  value       = module.vpc.public_route_table_ids
}

output "private_route_table_ids" {
  description = "Private route table IDs"
  value       = module.vpc.private_route_table_ids
}
