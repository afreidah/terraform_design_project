# -----------------------------------------------------------------------------
# INPUT VARIABLES
# -----------------------------------------------------------------------------
#
# This file defines all input variables for the environment configuration.
# Variables are organized by functional area for easy navigation.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# ENVIRONMENT & REGION
# -----------------------------------------------------------------------------

variable "region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

# -----------------------------------------------------------------------------
# VPC & NETWORKING CONFIGURATION
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private app subnets"
  type        = list(string)
}

variable "private_data_subnet_cidrs" {
  description = "CIDR blocks for private data subnets"
  type        = list(string)
}

# -----------------------------------------------------------------------------
# EC2 CONFIGURATION
# -----------------------------------------------------------------------------

variable "ec2_ami_id" {
  description = "AMI ID for EC2 instances (if not specified, latest Amazon Linux 2 will be used)"
  type        = string
  default     = null
}

variable "ec2_instance_type" {
  description = "Instance type for EC2 instances"
  type        = string
  default     = "t3.medium"
}

# -----------------------------------------------------------------------------
# SECURITY & ENCRYPTION
# -----------------------------------------------------------------------------

variable "kms_key_id" {
  description = "KMS key ID for encryption (RDS, Performance Insights, etc.)"
  type        = string
  default     = null
}

variable "ssl_certificate_arn" {
  description = "ARN of ACM SSL certificate for HTTPS listeners (optional)"
  type        = string
  default     = null
}

variable "devops_ip_ranges" {
  description = "CIDR blocks for DevOps access to admin ports (SSH, RDP)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # TODO: Restrict to VPN/office IPs in production
}

# -----------------------------------------------------------------------------
# EKS CLUSTER CONFIGURATION
# -----------------------------------------------------------------------------

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.31"
}

variable "eks_public_access_cidrs" {
  description = "CIDR blocks that can access the EKS public API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"] # TODO: Restrict in production
}

variable "eks_aws_auth_roles" {
  description = "Additional IAM roles to map to Kubernetes RBAC"
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

# -----------------------------------------------------------------------------
# EKS NODE GROUP CONFIGURATION
# -----------------------------------------------------------------------------

variable "eks_node_instance_types" {
  description = "Instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_capacity_type" {
  description = "Capacity type for nodes (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "eks_node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "eks_node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 10
}

variable "eks_node_disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 50
}
