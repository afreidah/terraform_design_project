# Environment Configuration
region      = "us-east-1"
environment = "production"

# VPC Configuration
vpc_cidr = "10.20.0.0/16"

availability_zones = [
  "us-east-1a",
  "us-east-1b",
  "us-east-1c"
]

# Public subnets
public_subnet_cidrs = [
  "10.20.1.0/24",
  "10.20.2.0/24",
  "10.20.3.0/24"
]

# Private app subnets
private_app_subnet_cidrs = [
  "10.20.11.0/24",
  "10.20.12.0/24",
  "10.20.13.0/24"
]

# Private data subnets
private_data_subnet_cidrs = [
  "10.20.21.0/24",
  "10.20.22.0/24",
  "10.20.23.0/24"
]

# EC2 Configuration
# AMI ID is dynamically fetched in main.tf
ec2_instance_type = "t3.medium"

# EKS Configuration
# Restrict to your VPN/office IP ranges in production
eks_public_access_cidrs = ["0.0.0.0/0"] # TODO: Restrict before production deployment

# DevOps Access
# Restrict SSH/RDP access to DevOps team IP ranges
devops_ip_ranges = ["0.0.0.0/0"] # TODO: Restrict to VPN/office IPs

# Optional: SSL Certificate ARN (uncomment when you have a cert)
# ssl_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
