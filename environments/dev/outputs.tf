# environments/production/outputs.tf

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.infrastructure.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.infrastructure.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.infrastructure.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "IDs of private app subnets"
  value       = module.infrastructure.private_app_subnet_ids
}

output "private_data_subnet_ids" {
  description = "IDs of private data subnets"
  value       = module.infrastructure.private_data_subnet_ids
}

# WAF Outputs
output "waf_web_acl_arn" {
  description = "ARN of the WAF WebACL"
  value       = module.infrastructure.waf_web_acl_arn
}

output "waf_web_acl_name" {
  description = "Name of the WAF WebACL"
  value       = module.infrastructure.waf_web_acl_name
}

# ALB Outputs
output "public_alb_dns_name" {
  description = "DNS name of the public ALB"
  value       = module.infrastructure.public_alb_dns_name
}

output "internal_alb_dns_name" {
  description = "DNS name of the internal ALB"
  value       = module.infrastructure.internal_alb_dns_name
}

# EC2 Outputs
output "ec2_autoscaling_group_name" {
  description = "Name of the EC2 Auto Scaling Group"
  value       = module.infrastructure.ec2_autoscaling_group_name
}

# Security Group Outputs
output "security_group_ids" {
  description = "Map of security group IDs"
  value       = module.infrastructure.security_group_ids
}

# Parameter Store Outputs
output "parameter_names" {
  description = "Map of Parameter Store parameter names"
  value       = module.infrastructure.parameter_names
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.infrastructure.rds_endpoint
}

output "rds_address" {
  description = "RDS instance address"
  value       = module.infrastructure.rds_address
}

output "rds_port" {
  description = "RDS instance port"
  value       = module.infrastructure.rds_port
}

output "rds_id" {
  description = "RDS instance ID"
  value       = module.infrastructure.rds_id
}

output "rds_arn" {
  description = "RDS instance ARN"
  value       = module.infrastructure.rds_arn
}

# Elasticache Outputs
output "redis_primary_endpoint" {
  description = "Redis primary endpoint"
  value       = module.infrastructure.redis_primary_endpoint
}

output "redis_reader_endpoint" {
  description = "Redis reader endpoint"
  value       = module.infrastructure.redis_reader_endpoint
}

# MSK Outputs
output "msk_bootstrap_brokers_tls" {
  description = "MSK TLS bootstrap brokers"
  value       = module.infrastructure.msk_bootstrap_brokers_tls
}

output "msk_zookeeper_connect_string" {
  description = "MSK Zookeeper connection string"
  value       = module.infrastructure.msk_zookeeper_connect_string
}

# OpenSearch Outputs
output "opensearch_endpoint" {
  description = "OpenSearch domain endpoint"
  value       = module.infrastructure.opensearch_endpoint
}

output "opensearch_dashboard_endpoint" {
  description = "OpenSearch Dashboards endpoint"
  value       = module.infrastructure.opensearch_dashboard_endpoint
}

# KMS Outputs
output "kms_parameter_store_key_id" {
  description = "KMS key ID for Parameter Store"
  value       = module.infrastructure.kms_parameter_store_key_id
}

output "kms_parameter_store_key_arn" {
  description = "KMS key ARN for Parameter Store"
  value       = module.infrastructure.kms_parameter_store_key_arn
}

output "kms_cloudwatch_logs_key_id" {
  description = "KMS key ID for CloudWatch Logs"
  value       = module.infrastructure.kms_cloudwatch_logs_key_id
}

output "kms_cloudwatch_logs_key_arn" {
  description = "KMS key ARN for CloudWatch Logs"
  value       = module.infrastructure.kms_cloudwatch_logs_key_arn
}

output "kms_rds_key_arn" {
  description = "KMS key ARN for RDS"
  value       = module.infrastructure.kms_rds_key_arn
}

output "kms_elasticache_key_arn" {
  description = "KMS key ARN for ElastiCache"
  value       = module.infrastructure.kms_elasticache_key_arn
}

output "kms_opensearch_key_arn" {
  description = "KMS key ARN for OpenSearch"
  value       = module.infrastructure.kms_opensearch_key_arn
}

output "kms_msk_key_arn" {
  description = "KMS key ARN for MSK"
  value       = module.infrastructure.kms_msk_key_arn
}

# VPC Flow Logs Outputs
output "vpc_flow_log_id" {
  description = "ID of the VPC Flow Log"
  value       = module.infrastructure.vpc_flow_log_id
}

output "vpc_flow_log_group_name" {
  description = "CloudWatch Log Group name for VPC Flow Logs"
  value       = module.infrastructure.vpc_flow_log_group_name
}
