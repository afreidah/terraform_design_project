# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------
#
# This file defines output values that expose information about created resources.
# Outputs serve multiple purposes:
#   - Reference values in other Terraform configurations
#   - Display important information after deployment (terraform output)
#   - Pass values to CI/CD pipelines or external systems
#   - Document key resource identifiers and endpoints
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# VPC & NETWORKING OUTPUTS
# -----------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------
# WAF OUTPUTS
# -----------------------------------------------------------------------------

output "waf_web_acl_arn" {
  description = "ARN of the WAF WebACL"
  value       = module.waf.web_acl_arn
}

output "waf_web_acl_name" {
  description = "Name of the WAF WebACL"
  value       = module.waf.web_acl_name
}

# -----------------------------------------------------------------------------
# LOAD BALANCER OUTPUTS
# -----------------------------------------------------------------------------

output "public_alb_dns_name" {
  description = "DNS name of the public ALB"
  value       = module.alb_public.alb_dns_name
}

output "internal_alb_dns_name" {
  description = "DNS name of the internal ALB"
  value       = module.alb_internal.alb_dns_name
}

# -----------------------------------------------------------------------------
# EC2 OUTPUTS
# -----------------------------------------------------------------------------

output "ec2_autoscaling_group_name" {
  description = "Name of the EC2 Auto Scaling Group"
  value       = module.ec2_app.autoscaling_group_name
}

# -----------------------------------------------------------------------------
# SECURITY GROUP OUTPUTS
# -----------------------------------------------------------------------------

output "security_group_ids" {
  description = "Map of security group IDs"
  value       = { for k, v in module.security_groups : k => v.security_group_id }
}

# -----------------------------------------------------------------------------
# PARAMETER STORE OUTPUTS
# -----------------------------------------------------------------------------

output "parameter_names" {
  description = "Map of Parameter Store parameter names"
  value       = module.parameter_store.parameter_names
}

# -----------------------------------------------------------------------------
# RDS DATABASE OUTPUTS
# -----------------------------------------------------------------------------

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.endpoint
}

output "rds_address" {
  description = "RDS instance address"
  value       = module.rds.address
}

output "rds_port" {
  description = "RDS instance port"
  value       = module.rds.port
}

output "rds_id" {
  description = "RDS instance ID"
  value       = module.rds.id
}

output "rds_arn" {
  description = "RDS instance ARN"
  value       = module.rds.arn
}

# -----------------------------------------------------------------------------
# ELASTICACHE (REDIS) OUTPUTS
# -----------------------------------------------------------------------------

output "redis_primary_endpoint" {
  description = "Redis primary endpoint"
  value       = module.elasticache.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Redis reader endpoint"
  value       = module.elasticache.reader_endpoint_address
}

# -----------------------------------------------------------------------------
# MSK (KAFKA) OUTPUTS
# -----------------------------------------------------------------------------

output "msk_bootstrap_brokers_tls" {
  description = "MSK TLS bootstrap brokers"
  value       = module.msk.bootstrap_brokers_tls
}

output "msk_zookeeper_connect_string" {
  description = "MSK Zookeeper connection string"
  value       = module.msk.zookeeper_connect_string
}

# -----------------------------------------------------------------------------
# OPENSEARCH OUTPUTS
# -----------------------------------------------------------------------------

output "opensearch_endpoint" {
  description = "OpenSearch domain endpoint"
  value       = module.opensearch.endpoint
}

output "opensearch_dashboard_endpoint" {
  description = "OpenSearch Dashboards endpoint"
  value       = module.opensearch.dashboard_endpoint
}
