# -----------------------------------------------------------------------------
# SSM PARAMETER STORE MODULE OUTPUTS
# -----------------------------------------------------------------------------

output "parameter_names" {
  description = "Map of parameter names"
  value       = { for k, v in aws_ssm_parameter.this : k => v.name }
}

output "parameter_arns" {
  description = "Map of parameter ARNs"
  value       = { for k, v in aws_ssm_parameter.this : k => v.arn }
}

output "parameter_versions" {
  description = "Map of parameter versions"
  value       = { for k, v in aws_ssm_parameter.this : k => v.version }
}
