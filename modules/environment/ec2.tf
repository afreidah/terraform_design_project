# -----------------------------------------------------------------------------
# EC2 COMPUTE INSTANCES
# -----------------------------------------------------------------------------
#
# This file defines EC2 instances deployed in an Auto Scaling Group for the
# application tier. Instances are:
#   - Deployed across multiple AZs for high availability
#   - Placed in private app subnets (no direct internet access)
#   - Registered with both public and internal ALB target groups
#   - Auto-scaled based on CPU and request metrics (see ec2-autoscaling.tf)
#
# Architecture:
#   - Default: Amazon Linux 2 AMI (automatically uses latest)
#   - Instance Type: Configurable via variable (default: t3.medium)
#   - Capacity: 2 desired, 1 minimum, 4 maximum instances
#   - Network: Private app subnets with NAT gateway for internet access
#
# IAM:
#   - Instance profile grants access to:
#     * SSM Session Manager for secure shell access (no SSH keys needed)
#     * CloudWatch for metrics and logs
#     * Parameter Store for configuration/secrets
#
# IMPORTANT:
#   - Instances must expose /health endpoint on port 8080 for ALB health checks
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# AMI SELECTION
# -----------------------------------------------------------------------------

# Get latest Amazon Linux 2 AMI from AWS
# Automatically updated when new AMI versions are released
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -----------------------------------------------------------------------------
# AUTO SCALING GROUP
# -----------------------------------------------------------------------------

module "ec2_app" {
  source = "../../modules/ec2"

  name                 = "${var.environment}-app"
  ami_id               = var.ec2_ami_id != null ? var.ec2_ami_id : data.aws_ami.amazon_linux_2.id
  instance_type        = var.ec2_instance_type
  subnet_ids           = module.networking.private_app_subnet_ids
  security_group_ids   = [module.security_groups["ec2_app"].security_group_id]
  iam_instance_profile = module.ec2_iam_role.instance_profile_name

  # -------------------------------------------------------------------------
  # CAPACITY CONFIGURATION
  # -------------------------------------------------------------------------
  # Auto scaling policies (ec2-autoscaling.tf) will adjust capacity between
  # min and max based on CPU and request metrics
  desired_capacity = 2 # Initial instance count
  min_size         = 1 # Minimum instances for availability
  max_size         = 4 # Maximum instances for cost control

  # -------------------------------------------------------------------------
  # LOAD BALANCER INTEGRATION
  # -------------------------------------------------------------------------
  # Register instances with both public and internal ALB target groups
  # Health checks from ALBs determine instance health status
  target_group_arns = [
    module.alb_public.target_group_arns["ec2"],
    module.alb_internal.target_group_arns["ec2"]
  ]

  tags = {
    Environment = var.environment
    Purpose     = "application"
  }
}
