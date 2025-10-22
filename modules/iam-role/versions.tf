# -----------------------------------------------------------------------------
# IAM ROLE MODULE - VERSION CONSTRAINTS
# -----------------------------------------------------------------------------
#
# This file defines the required versions of Terraform and providers needed
# to use this module. Version constraints ensure compatibility and prevent
# breaking changes from affecting infrastructure deployments.
#
# Requirements:
#   - Terraform: 1.0 or higher (supports count and conditional expressions)
#   - AWS Provider: 5.x series (latest IAM features and policies)
#
# IMPORTANT:
#   - AWS provider ~> 5.0 provides enhanced IAM policy validation
#   - Terraform >= 1.0 required for conditional instance profile creation
#   - Module uses jsonencode for trust policy formatting
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
