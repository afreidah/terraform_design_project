# -----------------------------------------------------------------------------
# EC2 AUTO SCALING GROUP MODULE - OUTPUT VALUES
# -----------------------------------------------------------------------------
#
# This file exposes attributes of the created EC2 Auto Scaling Group and
# Launch Template resources for use by parent modules and external integrations.
#
# Output Categories:
#   - Launch Template: Template identifiers and version information
#   - Auto Scaling Group: ASG identifiers for monitoring and management
#
# Usage:
#   - Launch template ID for creating scaling policies
#   - ASG name for CloudWatch alarms and Auto Scaling policies
#   - ASG ARN for cross-account or service integrations
#   - Template version for blue-green deployment tracking
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# LAUNCH TEMPLATE OUTPUTS
# -----------------------------------------------------------------------------

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.this.id
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.this.latest_version
}

# -----------------------------------------------------------------------------
# AUTO SCALING GROUP OUTPUTS
# -----------------------------------------------------------------------------

output "autoscaling_group_id" {
  description = "ID of the Auto Scaling Group"
  value       = aws_autoscaling_group.this.id
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.this.name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.this.arn
}
