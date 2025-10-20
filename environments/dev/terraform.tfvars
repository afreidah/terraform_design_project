# Environment Configuration
region      = "us-east-1"
environment = "dev"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"

availability_zones = [
  "us-east-1a",
  "us-east-1b",
  "us-east-1c"
]

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24",
  "10.0.3.0/24"
]

private_app_subnet_cidrs = [
  "10.0.11.0/24",
  "10.0.12.0/24",
  "10.0.13.0/24"
]

private_data_subnet_cidrs = [
  "10.0.21.0/24",
  "10.0.22.0/24",
  "10.0.23.0/24"
]

# EC2 Configuration
# AMI ID is dynamically fetched in main.tf - no need to specify here
# Uncomment below to override with specific AMI
# ec2_ami_id = "ami-xxxxx"
ec2_instance_type = "t3.medium"

# EKS Configuration
# Restrict to your VPN/office IP ranges in production
# Example: ["203.0.113.0/24", "198.51.100.0/24"]
eks_public_access_cidrs = ["0.0.0.0/0"] # TODO: Restrict before production deployment

# DevOps Access
# Restrict SSH/RDP access to DevOps team IP ranges
# Example: ["203.0.113.0/24", "198.51.100.0/24"]
devops_ip_ranges = ["0.0.0.0/0"] # TODO: Restrict to VPN/office IPs in production

# Optional: SSL Certificate ARN (uncomment when you have a cert)
# ssl_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"

# Optional: KMS Key (if you have one)
# kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
