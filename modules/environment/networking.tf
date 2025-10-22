# -----------------------------------------------------------------------------
# NETWORKING CONFIGURATION
# -----------------------------------------------------------------------------
#
# This file defines the VPC and subnet architecture for the environment.
# The networking module creates:
#   - VPC with DNS support enabled
#   - Internet Gateway for public subnet internet access
#   - NAT Gateways for private subnet outbound internet access
#   - Route tables for public and private subnets
#   - Three-tier subnet architecture across multiple AZs
#
# Subnet Architecture:
#   - Public Subnets: Internet-facing load balancers, NAT gateways
#   - Private App Subnets: EC2 instances, EKS nodes, application tier
#   - Private Data Subnets: RDS, ElastiCache, OpenSearch, MSK (no internet)
#
# High Availability:
#   - Multi-AZ deployment for redundancy
#   - NAT Gateway per AZ for fault tolerance
#   - Subnets distributed across availability zones
#
# IMPORTANT:
#   - CIDR blocks must not overlap with other VPCs if peering planned
# -----------------------------------------------------------------------------

module "networking" {
  source = "../../modules/general-networking"

  vpc_cidr                  = var.vpc_cidr
  vpc_name                  = var.environment
  availability_zones        = var.availability_zones
  public_subnet_cidrs       = var.public_subnet_cidrs
  private_app_subnet_cidrs  = var.private_app_subnet_cidrs
  private_data_subnet_cidrs = var.private_data_subnet_cidrs

  tags = {
    Environment = var.environment
  }
}
