# -----------------------------------------------------------------------------
# IAM ROLE MODULE - OUTPUT VALUES
# -----------------------------------------------------------------------------
#
# This file exposes attributes of the created IAM role and optional instance
# profile for use by parent modules, EC2 instances, and other AWS resources.
#
# Output Categories:
#   - Role Attributes: Identifiers for the IAM role
#   - Instance Profile: EC2 attachment identifiers (when created)
#
# Usage:
#   - role_arn: Reference in trust policies, resource policies, and IAM policies
#   - role_name: Use in policy attachments and aws-auth ConfigMaps
#   - role_id: Unique identifier for CloudTrail and audit logs
#   - instance_profile_name: Attach to EC2 launch templates or instances
#   - instance_profile_arn: Reference in Auto Scaling Groups and launch configs
#
# Note:
#   - Instance profile outputs are null when create_instance_profile = false
#   - Role ARN format: arn:aws:iam::account-id:role/role-name
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# ROLE OUTPUTS
# -----------------------------------------------------------------------------

output "role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.this.name
}

output "role_id" {
  description = "ID of the IAM role"
  value       = aws_iam_role.this.id
}

# -----------------------------------------------------------------------------
# INSTANCE PROFILE OUTPUTS
# -----------------------------------------------------------------------------

output "instance_profile_name" {
  description = "Name of the instance profile (if created)"
  value       = var.create_instance_profile ? aws_iam_instance_profile.this[0].name : null
}

output "instance_profile_arn" {
  description = "ARN of the instance profile (if created)"
  value       = var.create_instance_profile ? aws_iam_instance_profile.this[0].arn : null
}
