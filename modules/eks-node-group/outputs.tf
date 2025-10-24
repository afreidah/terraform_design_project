# -----------------------------------------------------------------------------
# EKS NODE GROUP MODULE OUTPUTS
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# NODE GROUP OUTPUTS
# -----------------------------------------------------------------------------

output "node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.this.id
}

output "node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Node Group"
  value       = aws_eks_node_group.this.arn
}

output "node_group_status" {
  description = "Status of the EKS node group"
  value       = aws_eks_node_group.this.status
}

output "node_group_resources" {
  description = "Resources associated with the node group"
  value       = aws_eks_node_group.this.resources
}

# -----------------------------------------------------------------------------
# IAM OUTPUTS
# -----------------------------------------------------------------------------

output "iam_role_arn" {
  description = "ARN of the IAM role for nodes"
  value       = aws_iam_role.node.arn
}

output "iam_role_name" {
  description = "Name of the IAM role for nodes"
  value       = aws_iam_role.node.name
}

output "iam_instance_profile_arn" {
  description = "ARN of the IAM instance profile"
  value       = aws_iam_instance_profile.node.arn
}

output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = aws_iam_instance_profile.node.name
}

# -----------------------------------------------------------------------------
# SECURITY GROUP OUTPUTS
# -----------------------------------------------------------------------------

output "security_group_id" {
  description = "Security group ID for the node group"
  value       = aws_security_group.node.id
}

output "security_group_arn" {
  description = "ARN of the security group for the node group"
  value       = aws_security_group.node.arn
}

# -----------------------------------------------------------------------------
# LAUNCH TEMPLATE OUTPUTS
# -----------------------------------------------------------------------------

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.node.id
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.node.latest_version
}
