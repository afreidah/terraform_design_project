# -----------------------------------------------------------------------------
# LOCAL VALUES
# -----------------------------------------------------------------------------
#
# This file defines local values (constants) used across multiple resources.
# Locals prevent repetition and ensure consistency.
#
# Common Tags:
#   - Applied to all resources via `merge(local.common_tags, {...})`
#   - Enables cost tracking, resource organization, and compliance
#   - Ensures consistent tagging across the environment
# -----------------------------------------------------------------------------

locals {
  # Common tags for all resources
  # Applied using: tags = merge(local.common_tags, { AdditionalTag = "value" })
  common_tags = {
    Environment = var.environment
    Project     = "infrastructure-exercise"
    ManagedBy   = "Terraform"
  }
}
