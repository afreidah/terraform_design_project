# -----------------------------------------------------------------------------
# VPC / GENERAL NETWORKING MODULE
# -----------------------------------------------------------------------------
#
# This module creates a production-ready AWS Virtual Private Cloud (VPC) with
# a three-tier subnet architecture (public, private application, private data)
# across multiple availability zones for high availability and fault isolation.
#
# Components Created:
#   - VPC: Virtual network with DNS support
#   - Internet Gateway: Public internet access for public subnets
#   - Public Subnets: NAT gateways, load balancers, bastion hosts
#   - Private App Subnets: Application servers, containers, compute
#   - Private Data Subnets: Databases, caches, storage services
#   - NAT Gateways: Outbound internet access for private subnets (one per AZ)
#   - Route Tables: Traffic routing for each tier
#
# Architecture:
#   - Public Tier: Direct internet access via Internet Gateway
#   - Private App Tier: Per-AZ NAT Gateways for HA (isolated failure domains)
#   - Private Data Tier: Shared route table with NAT access for updates
#   - Multi-AZ: Resources distributed across availability zones
#
# Security Model:
#   - Network Isolation: Three-tier architecture separates concerns
#   - Private by Default: App and data tiers have no direct internet access
#   - NAT High Availability: One NAT Gateway per AZ (app tier)
#   - DNS Support: Enables Route53 private hosted zones
#   - Least Privilege Routing: Data tier has minimal internet access
#
# IMPORTANT:
#   - NAT Gateways incur hourly charges and data transfer costs
#   - Each NAT Gateway requires an Elastic IP address
#   - Private app subnets get dedicated NAT per AZ for fault isolation
#   - Private data subnets share a single route table to minimize routes
#   - Public subnets enable map_public_ip_on_launch for NAT and ALB
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

# Virtual Private Cloud with DNS support
# Provides isolated network environment for all resources
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-vpc"
    }
  )
}

# -----------------------------------------------------------------------------
# INTERNET GATEWAY
# -----------------------------------------------------------------------------

# Provides internet connectivity for public subnets
# Required for NAT Gateways and public-facing load balancers
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-igw"
    }
  )
}

# -----------------------------------------------------------------------------
# PUBLIC SUBNETS
# -----------------------------------------------------------------------------

# Public subnets for internet-facing resources
# Hosts: NAT Gateways, Application Load Balancers, bastion hosts
resource "aws_subnet" "public" {
  #tfsec:ignore:aws-ec2-no-public-ip-subnet Public subnets need public IPs for NAT gateways and ALBs
  #checkov:skip=CKV_AWS_130:Public subnets require public IP assignment for NAT gateways
  #trivy:ignore:AVD-AWS-0164
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-public-${var.availability_zones[count.index]}"
      Tier = "public"
    }
  )
}

# -----------------------------------------------------------------------------
# PRIVATE APPLICATION SUBNETS
# -----------------------------------------------------------------------------

# Private subnets for application tier (EC2, ECS, EKS, Lambda)
# Internet access via NAT Gateway, no direct inbound from internet
resource "aws_subnet" "private_app" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-private-app-${var.availability_zones[count.index]}"
      Tier = "private-app"
    }
  )
}

# -----------------------------------------------------------------------------
# PRIVATE DATA SUBNETS
# -----------------------------------------------------------------------------

# Private subnets for data tier (RDS, ElastiCache, Redshift)
# Isolated from internet with minimal NAT access for updates only
resource "aws_subnet" "private_data" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_data_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-private-data-${var.availability_zones[count.index]}"
      Tier = "private-data"
    }
  )
}

# -----------------------------------------------------------------------------
# ELASTIC IPS FOR NAT GATEWAYS
# -----------------------------------------------------------------------------

# Static public IP addresses for NAT Gateways
# One EIP per NAT Gateway for consistent outbound IP addressing
resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-nat-eip-${count.index + 1}"
    }
  )
}

# -----------------------------------------------------------------------------
# NAT GATEWAYS
# -----------------------------------------------------------------------------

# NAT Gateways for private subnet outbound internet access
# One per availability zone for high availability and fault isolation
resource "aws_nat_gateway" "main" {
  count = length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-nat-gw-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# PUBLIC ROUTE TABLE
# -----------------------------------------------------------------------------

# Route table for public subnets
# All traffic destined for internet routes through Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-public-rt"
    }
  )
}

# -------------------------------------------------------------------------
# PUBLIC INTERNET ROUTE
# -------------------------------------------------------------------------

# Default route for public subnets to Internet Gateway
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# -------------------------------------------------------------------------
# PUBLIC ROUTE TABLE ASSOCIATIONS
# -------------------------------------------------------------------------

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# PRIVATE APP ROUTE TABLES
# -----------------------------------------------------------------------------

# Route tables for private application subnets (one per AZ)
# Isolated per AZ for fault tolerance - NAT Gateway failure in one AZ
# does not affect other AZs
resource "aws_route_table" "private_app" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-private-app-rt-${var.availability_zones[count.index]}"
    }
  )
}

# -------------------------------------------------------------------------
# PRIVATE APP NAT ROUTES
# -------------------------------------------------------------------------

# Default routes for private app subnets to NAT Gateways
# Each AZ routes to its own NAT Gateway for fault isolation
resource "aws_route" "private_app_nat" {
  count = length(var.availability_zones)

  route_table_id         = aws_route_table.private_app[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id
}

# -------------------------------------------------------------------------
# PRIVATE APP ROUTE TABLE ASSOCIATIONS
# -------------------------------------------------------------------------

# Associate private app subnets with their respective route tables
resource "aws_route_table_association" "private_app" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

# -----------------------------------------------------------------------------
# PRIVATE DATA ROUTE TABLE
# -----------------------------------------------------------------------------

# Shared route table for all private data subnets across AZs
# Uses single NAT Gateway to minimize cost for infrequent updates
resource "aws_route_table" "private_data" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-private-data-rt"
    }
  )
}

# -------------------------------------------------------------------------
# PRIVATE DATA NAT ROUTE
# -------------------------------------------------------------------------

# Default route for private data subnets to first NAT Gateway
# Shared across all AZs for cost optimization (data tier rarely needs internet)
resource "aws_route" "private_data_nat" {
  count = 1

  route_table_id         = aws_route_table.private_data.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

# -------------------------------------------------------------------------
# PRIVATE DATA ROUTE TABLE ASSOCIATIONS
# -------------------------------------------------------------------------

# Associate all private data subnets with shared route table
resource "aws_route_table_association" "private_data" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.private_data[count.index].id
  route_table_id = aws_route_table.private_data.id
}
