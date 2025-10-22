# -----------------------------------------------------------------------------
# VPC / GENERAL NETWORKING MODULE - INPUT VARIABLES
# -----------------------------------------------------------------------------
#
# This file defines all configurable parameters for the VPC and networking
# module, including VPC configuration, subnet CIDR allocations, availability
# zone placement, and NAT Gateway settings.
#
# Variable Categories:
#   - Core Configuration: VPC name and CIDR block
#   - Availability Zones: Multi-AZ deployment configuration
#   - Subnet Configuration: CIDR blocks for three-tier architecture
#   - NAT Gateway Options: High availability vs cost optimization
#   - Tagging: Resource tags for organization
#
# Architecture Notes:
#   - Public subnets: NAT gateways, load balancers, bastion hosts
#   - Private app subnets: Application servers, containers, compute
#   - Private data subnets: Databases, caches, storage services
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# CORE VPC CONFIGURATION
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

# -----------------------------------------------------------------------------
# AVAILABILITY ZONES
# -----------------------------------------------------------------------------

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# -----------------------------------------------------------------------------
# SUBNET CONFIGURATION
# -----------------------------------------------------------------------------

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private application tier subnets"
  type        = list(string)
}

variable "private_data_subnet_cidrs" {
  description = "CIDR blocks for private data tier subnets"
  type        = list(string)
}

# -----------------------------------------------------------------------------
# NAT GATEWAY CONFIGURATION
# -----------------------------------------------------------------------------

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway instead of one per AZ (cost optimization vs HA)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# TAGGING
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
