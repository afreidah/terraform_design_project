# -----------------------------------------------------------------------------
# EKS NODE GROUP MODULE - VERSION CONSTRAINTS
# -----------------------------------------------------------------------------
#
# This file defines the required versions of Terraform and providers needed
# to use this module. Version constraints ensure compatibility and prevent
# breaking changes from affecting infrastructure deployments.
#
# Requirements:
#   - Terraform: 1.5.0 or higher (supports EKS managed node groups)
#   - AWS Provider: 5.x series (latest EKS node group features)
#
# IMPORTANT:
#   - AWS provider ~> 5.0 required for launch template integration
#   - Terraform >= 1.5.0 required for optional object attributes
#   - Module uses templatefile() which requires Terraform >= 0.12
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
