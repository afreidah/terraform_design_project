# environments/production/variables.tf

variable "region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

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

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}

variable "ssl_certificate_arn" {
  description = "ARN of ACM SSL certificate for HTTPS listeners (optional)"
  type        = string
  default     = null
}

variable "eks_public_access_cidrs" {
  description = "CIDR blocks that can access the EKS public API endpoint. Restrict to VPN/office IPs in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "devops_ip_ranges" {
  description = "CIDR blocks for DevOps access to admin ports (SSH, RDP)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # TODO: Restrict to VPN/office IPs in production
}
