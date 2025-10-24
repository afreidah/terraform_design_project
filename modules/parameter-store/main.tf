# -----------------------------------------------------------------------------
# SSM PARAMETER STORE MODULE
# -----------------------------------------------------------------------------
#
# This module creates AWS Systems Manager Parameter Store parameters with
# support for multiple parameter types including String, StringList, and
# SecureString. Parameters can optionally use customer-managed KMS keys for
# encryption and support both Standard and Advanced parameter tiers.
#
# IMPORTANT: SecureString parameters are encrypted by default using the AWS
# managed key unless a custom KMS key is specified. Parameter values cannot
# be updated to use a different KMS key without recreating the parameter.
# Advanced tier parameters support larger values and higher throughput but
# incur additional costs.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# SSM PARAMETERS
# -----------------------------------------------------------------------------

# AWS Systems Manager parameters for application configuration and secrets
# Creates one parameter per map entry with configurable type and encryption
resource "aws_ssm_parameter" "this" {
  for_each = var.parameters

  name        = each.key
  description = each.value.description
  type        = each.value.type
  value       = each.value.value
  tier        = each.value.tier
  key_id      = each.value.key_id

  tags = merge(
    var.tags,
    {
      Name = each.key
    }
  )
}
