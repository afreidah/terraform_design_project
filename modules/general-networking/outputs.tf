# -----------------------------------------------------------------------------
# VPC / GENERAL NETWORKING MODULE - OUTPUT VALUES
# -----------------------------------------------------------------------------
#
# This file exposes attributes of the created VPC and networking resources
# for use by parent modules, compute resources, and data services.
#
# Output Categories:
#   - VPC Core: VPC identifiers and CIDR information
#   - Internet Gateway: Public internet connectivity resource
#   - Subnets: Subnet IDs for each tier (public, app, data)
#   - NAT Gateways: Outbound internet access resources
#   - Route Tables: Routing configuration identifiers
#   - Availability Zones: AZ distribution information
#
# Usage:
#   - vpc_id: Required for security groups, endpoints, and other VPC resources
#   - public_subnet_ids: For ALBs, NAT gateways, bastion hosts
#   - private_app_subnet_ids: For EC2, ECS, EKS, Lambda functions
#   - private_data_subnet_ids: For RDS, ElastiCache, Redshift
#   - nat_gateway_ids: For security group rules or monitoring
#   - route_table_ids: For VPC endpoints or additional routes
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# VPC CORE OUTPUTS
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

# -----------------------------------------------------------------------------
# INTERNET GATEWAY OUTPUT
# -----------------------------------------------------------------------------

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

# -----------------------------------------------------------------------------
# SUBNET OUTPUTS
# -----------------------------------------------------------------------------

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "List of private application tier subnet IDs"
  value       = aws_subnet.private_app[*].id
}

output "private_data_subnet_ids" {
  description = "List of private data tier subnet IDs"
  value       = aws_subnet.private_data[*].id
}

# -----------------------------------------------------------------------------
# NAT GATEWAY OUTPUTS
# -----------------------------------------------------------------------------

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[*].id : []
}

# -----------------------------------------------------------------------------
# ROUTE TABLE OUTPUTS
# -----------------------------------------------------------------------------

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_app_route_table_ids" {
  description = "List of private app route table IDs"
  value       = aws_route_table.private_app[*].id
}

output "private_data_route_table_id" {
  description = "ID of the private data route table"
  value       = aws_route_table.private_data.id
}

# -----------------------------------------------------------------------------
# AVAILABILITY ZONE OUTPUT
# -----------------------------------------------------------------------------

output "availability_zones" {
  description = "List of availability zones used"
  value       = var.availability_zones
}
