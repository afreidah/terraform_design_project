# -----------------------------------------------------------------------------
# EC2 AUTO SCALING POLICIES
# -----------------------------------------------------------------------------
#
# This file defines auto scaling policies for the EC2 Auto Scaling Group.
# Multiple target tracking policies work together to scale based on:
#   - CPU Utilization: Scale when average CPU exceeds threshold
#   - ALB Request Count: Scale when request rate per instance exceeds threshold
#
# Scaling Behavior:
#   - Target tracking automatically creates CloudWatch alarms
#   - Scale-out is immediate when threshold breached
#   - Scale-in is gradual to avoid thrashing (respects cooldown periods)
#   - Multiple policies = most conservative scaling wins (highest instance count)
#
# Metrics:
#   - CPU Target: 70% average CPU utilization across ASG
#   - Request Target: 1000 requests per minute per instance
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# CPU-BASED SCALING
# -----------------------------------------------------------------------------

# Scale based on average CPU utilization across all instances
# Maintains target of 70% CPU to balance performance and cost
resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${var.environment}-app-cpu-target"
  autoscaling_group_name = module.ec2_app.autoscaling_group_name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0 # Scale when average CPU exceeds 70%
  }
}

# -----------------------------------------------------------------------------
# REQUEST-BASED SCALING
# -----------------------------------------------------------------------------

# Scale based on ALB request count per target instance
# Prevents overload by maintaining consistent requests per instance
resource "aws_autoscaling_policy" "alb_request_count" {
  name                   = "${var.environment}-app-alb-requests"
  autoscaling_group_name = module.ec2_app.autoscaling_group_name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${module.alb_public.alb_arn_suffix}/${module.alb_public.target_group_arn_suffixes["ec2"]}"
    }

    target_value = 1000.0 # Scale when requests per target exceed 1000/minute
  }
}
