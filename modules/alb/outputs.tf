# -----------------------------------------------------------------------------
# ALB MODULE - OUTPUT VALUES
# -----------------------------------------------------------------------------
#
# This file exposes attributes of the created ALB resources for use by
# parent modules and external integrations. Outputs include ALB endpoints,
# target group references, and listener ARNs.
#
# Output Categories:
#   - ALB Attributes: Core ALB identifiers and DNS endpoints
#   - Target Groups: References for attaching instances/IPs
#   - Listeners: ARNs for adding rules or additional configuration
#   - Monitoring: ARN suffixes for CloudWatch metrics
#
# Usage:
#   - DNS name for Route53 alias records
#   - Target group ARNs for EC2/ECS/Lambda attachment
#   - ARN suffixes for CloudWatch alarms and dashboards
#   - Listener ARNs for adding custom routing rules
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# ALB CORE ATTRIBUTES
# -----------------------------------------------------------------------------

output "alb_id" {
  description = "ID of the ALB"
  value       = aws_lb.this.id
}

output "alb_arn" {
  description = "ARN of the ALB"
  value       = aws_lb.this.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the ALB (for use with CloudWatch metrics)"
  value       = aws_lb.this.arn_suffix
}

# -----------------------------------------------------------------------------
# ALB NETWORKING
# -----------------------------------------------------------------------------

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the ALB"
  value       = aws_lb.this.zone_id
}

# -----------------------------------------------------------------------------
# TARGET GROUPS
# -----------------------------------------------------------------------------

output "target_group_arns" {
  description = "Map of target group ARNs"
  value       = { for k, v in aws_lb_target_group.this : k => v.arn }
}

output "target_group_arn_suffixes" {
  description = "Map of target group ARN suffixes (for use with CloudWatch metrics)"
  value       = { for k, v in aws_lb_target_group.this : k => v.arn_suffix }
}

output "target_group_names" {
  description = "Map of target group names"
  value       = { for k, v in aws_lb_target_group.this : k => v.name }
}

# -----------------------------------------------------------------------------
# LISTENERS
# -----------------------------------------------------------------------------

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener (if created)"
  value       = var.certificate_arn != null ? aws_lb_listener.https[0].arn : null
}
