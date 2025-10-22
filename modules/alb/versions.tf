# -----------------------------------------------------------------------------
# ALB MODULE - VERSION CONSTRAINTS
# -----------------------------------------------------------------------------
#
# This file defines the required versions of Terraform and providers needed
# to use this module. Version constraints ensure compatibility and prevent
# breaking changes from affecting infrastructure deployments.
#
# Requirements:
#   - Terraform: 1.0 or higher (supports optional attributes in variables)
#   - AWS Provider: 5.x series (latest ALB features and security policies)
#
# IMPORTANT:
#   - AWS provider ~> 5.0 provides access to latest ALB configurations
#   - Terraform >= 1.0 required for optional() function support in variables
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
