# -----------------------------------------------------------------------------
# KMS KEY MODULE - VERSION CONSTRAINTS
# -----------------------------------------------------------------------------
#
# This file defines the required versions of Terraform and providers needed
# to use this module. Version constraints ensure compatibility and prevent
# breaking changes from affecting infrastructure deployments.
#
# Requirements:
#   - Terraform: 1.0 or higher (supports try() function for conditional outputs)
#   - AWS Provider: 5.x series (latest KMS features and key rotation support)
#
# IMPORTANT:
#   - AWS provider ~> 5.0 provides enhanced KMS policy validation
#   - Terraform >= 1.0 required for try() function in outputs
#   - Module uses count for conditional alias creation
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
