# -----------------------------------------------------------------------------
# EC2 AUTO SCALING POLICIES
# -----------------------------------------------------------------------------

# Target Tracking Scaling Policy - CPU
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

# Target Tracking Scaling Policy - ALB Request Count
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
