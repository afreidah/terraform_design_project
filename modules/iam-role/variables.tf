# -----------------------------------------------------------------------------
# IAM ROLE MODULE - INPUT VARIABLES
# -----------------------------------------------------------------------------
#
# This file defines all configurable parameters for the IAM role module,
# including role identity, trust policy, permission attachments, and
# instance profile options.
#
# Variable Categories:
#   - Core Configuration: Role name and trust policy
#   - Permissions: Managed policy attachments
#   - Instance Profile: Optional EC2 instance profile creation
#   - Tagging: Resource tags for organization
#
# Trust Policy Examples:
#   - EC2: { Principal = { Service = "ec2.amazonaws.com" } }
#   - Lambda: { Principal = { Service = "lambda.amazonaws.com" } }
#   - ECS Tasks: { Principal = { Service = "ecs-tasks.amazonaws.com" } }
#   - Cross-Account: { Principal = { AWS = "arn:aws:iam::123456789012:root" } }
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# CORE CONFIGURATION
# -----------------------------------------------------------------------------

variable "name" {
  description = "Name of the IAM role"
  type        = string
}

variable "assume_role_policy" {
  description = "IAM policy document for assume role"
  type        = string
}

# -----------------------------------------------------------------------------
# PERMISSIONS CONFIGURATION
# -----------------------------------------------------------------------------

variable "policy_arns" {
  description = "List of IAM policy ARNs to attach to role"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# INSTANCE PROFILE CONFIGURATION
# -----------------------------------------------------------------------------

variable "create_instance_profile" {
  description = "Whether to create an instance profile for EC2"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# TAGGING
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to IAM role"
  type        = map(string)
  default     = {}
}
