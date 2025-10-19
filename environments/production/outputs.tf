# environments/production/outputs.tf

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.networking.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "IDs of private app subnets"
  value       = module.networking.private_app_subnet_ids
}

output "private_data_subnet_ids" {
  description = "IDs of private data subnets"
  value       = module.networking.private_data_subnet_ids
}

# ALB Outputs
output "public_alb_dns_name" {
  description = "DNS name of the public ALB"
  value       = module.alb_public.alb_dns_name
}

output "internal_alb_dns_name" {
  description = "DNS name of the internal ALB"
  value       = module.alb_internal.alb_dns_name
}

# EC2 Outputs
output "ec2_autoscaling_group_name" {
  description = "Name of the EC2 Auto Scaling Group"
  value       = module.ec2_app.autoscaling_group_name
}

# Security Group Outputs
output "security_group_ids" {
  description = "Map of security group IDs"
  value       = { for k, v in module.security_groups : k => v.security_group_id }
}

# Parameter Store Outputs
output "parameter_names" {
  description = "Map of Parameter Store parameter names"
  value       = module.parameter_store.parameter_names
}
