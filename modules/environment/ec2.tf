# -----------------------------------------------------------------------------
# EC2 INSTANCES
# -----------------------------------------------------------------------------

# Get latest Amazon Linux 2 AMI
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

module "ec2_app" {
  source = "../../modules/ec2"

  name                 = "${var.environment}-app"
  ami_id               = var.ec2_ami_id != null ? var.ec2_ami_id : data.aws_ami.amazon_linux_2.id
  instance_type        = var.ec2_instance_type
  subnet_ids           = module.networking.private_app_subnet_ids
  security_group_ids   = [module.security_groups["ec2_app"].security_group_id]
  iam_instance_profile = module.ec2_iam_role.instance_profile_name

  desired_capacity = 2
  min_size         = 1
  max_size         = 4

  # Attach to ALB target groups
  target_group_arns = [
    module.alb_public.target_group_arns["ec2"],
    module.alb_internal.target_group_arns["ec2"]
  ]

  tags = {
    Environment = var.environment
    Purpose     = "application"
  }
}
