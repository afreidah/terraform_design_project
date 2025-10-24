# -----------------------------------------------------------------------------
# KMS KEY MODULE - INPUT VARIABLES
# -----------------------------------------------------------------------------
#
# This file defines all configurable parameters for the KMS key module,
# including key metadata, security settings, access policies, and alias
# configuration.
#
# Variable Categories:
#   - Core Configuration: Description and key metadata
#   - Security Configuration: Rotation and deletion protection
#   - Access Control: Key policy for permissions
#   - Alias Configuration: Optional human-readable key reference
#   - Tagging: Resource tags for organization
#
# Key Policy Notes:
#   - If not provided, AWS applies default key policy
#   - Default policy grants account root full access to key
#   - Custom policies must include kms:* permissions for key administrators
#   - Policies should follow least privilege principles
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# CORE CONFIGURATION
# -----------------------------------------------------------------------------

variable "description" {
  description = "Description of the KMS key"
  type        = string
}

# -----------------------------------------------------------------------------
# SECURITY CONFIGURATION
# -----------------------------------------------------------------------------

variable "deletion_window_in_days" {
  description = "Duration in days before key deletion"
  type        = number
  default     = 30
}

variable "enable_key_rotation" {
  description = "Enable automatic key rotation"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# ACCESS CONTROL
# -----------------------------------------------------------------------------

variable "policy" {
  description = "KMS key policy (JSON)"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# ALIAS CONFIGURATION
# -----------------------------------------------------------------------------

variable "alias_name" {
  description = "KMS key alias name (without 'alias/' prefix)"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# TAGGING
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags for the KMS key"
  type        = map(string)
  default     = {}
}
