# -----------------------------------------------------------------------------
# EC2 AUTO SCALING GROUP MODULE
# -----------------------------------------------------------------------------
#
# This module creates an Auto Scaling Group (ASG) with a Launch Template for
# automatically scaling EC2 instances based on demand. It provides self-healing
# capabilities, automated instance replacement, and integration with load
# balancers for high availability applications.
#
# Components Created:
#   - Launch Template: Instance configuration blueprint with security hardening
#   - Auto Scaling Group: Manages instance lifecycle and scaling operations
#
# Features:
#   - Automated instance scaling based on min/max/desired capacity
#   - Self-healing with automatic instance replacement on health check failure
#   - IMDSv2 enforcement for enhanced instance metadata security
#   - EBS encryption for data at rest protection
#   - CloudWatch detailed monitoring enabled by default
#   - Load balancer integration via target group attachment
#   - Configurable health checks (EC2 or ELB)
#
# Security Model:
#   - IMDSv2 Required: Prevents SSRF attacks on instance metadata
#   - EBS Encryption: All volumes encrypted at rest
#   - IAM Instance Profile: Role-based AWS service access
#   - Security Groups: Network-level access control
#   - No SSH Keys Required: Optional key_name for emergency access only
#
# IMPORTANT:
#   - Launch template uses name_prefix for blue-green deployments
#   - ASG ignores desired_capacity changes to prevent drift
#   - Latest launch template version always used ($Latest)
#   - Root volume automatically deleted on instance termination
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# LAUNCH TEMPLATE
# -----------------------------------------------------------------------------

# Defines instance configuration for Auto Scaling Group
# Contains security hardening and monitoring settings applied to all instances
resource "aws_launch_template" "this" {
  name_prefix   = "${var.name}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  user_data     = var.user_data != null ? base64encode(var.user_data) : null

  # -------------------------------------------------------------------------
  # IAM INSTANCE PROFILE
  # -------------------------------------------------------------------------
  # Grants instances AWS service access without embedded credentials
  iam_instance_profile {
    name = var.iam_instance_profile
  }

  # -------------------------------------------------------------------------
  # NETWORK CONFIGURATION
  # -------------------------------------------------------------------------
  # Security groups control inbound/outbound traffic
  vpc_security_group_ids = var.security_group_ids

  # -------------------------------------------------------------------------
  # ROOT VOLUME CONFIGURATION
  # -------------------------------------------------------------------------
  # EBS root volume with encryption enabled for data protection
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      delete_on_termination = true
      encrypted             = true
    }
  }

  # -------------------------------------------------------------------------
  # INSTANCE METADATA SERVICE (IMDSv2)
  # -------------------------------------------------------------------------
  # Enforces IMDSv2 to prevent SSRF attacks on instance metadata
  # http_tokens = "required" blocks IMDSv1 access
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # -------------------------------------------------------------------------
  # MONITORING
  # -------------------------------------------------------------------------
  # Detailed CloudWatch monitoring enabled for better observability
  monitoring {
    enabled = true
  }

  # -------------------------------------------------------------------------
  # INSTANCE TAGGING
  # -------------------------------------------------------------------------
  # Tags applied to launched instances for identification and cost tracking
  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.tags,
      {
        Name = var.name
      }
    )
  }

  # -------------------------------------------------------------------------
  # VOLUME TAGGING
  # -------------------------------------------------------------------------
  # Tags applied to EBS volumes for tracking and compliance
  tag_specifications {
    resource_type = "volume"
    tags = merge(
      var.tags,
      {
        Name = "${var.name}-volume"
      }
    )
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# AUTO SCALING GROUP
# -----------------------------------------------------------------------------

# Manages EC2 instance lifecycle with automatic scaling and self-healing
# Integrates with load balancers via target group attachment
resource "aws_autoscaling_group" "this" {
  name                      = "${var.name}-asg"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  health_check_grace_period = var.health_check_grace_period
  health_check_type         = var.health_check_type
  vpc_zone_identifier       = var.subnet_ids
  target_group_arns         = var.target_group_arns

  # -------------------------------------------------------------------------
  # LAUNCH TEMPLATE REFERENCE
  # -------------------------------------------------------------------------
  # Uses latest version of launch template for new instances
  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  # -------------------------------------------------------------------------
  # CLOUDWATCH METRICS
  # -------------------------------------------------------------------------
  # Detailed ASG metrics for monitoring and alerting
  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMinSize",
    "GroupMaxSize",
    "GroupTotalInstances"
  ]

  # -------------------------------------------------------------------------
  # NAME TAG
  # -------------------------------------------------------------------------
  # Propagated to instances for identification
  tag {
    key                 = "Name"
    value               = var.name
    propagate_at_launch = true
  }

  # -------------------------------------------------------------------------
  # CUSTOM TAGS
  # -------------------------------------------------------------------------
  # Additional tags propagated to instances
  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}
