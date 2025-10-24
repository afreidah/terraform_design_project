# -----------------------------------------------------------------------------
# VPC / GENERAL NETWORKING MODULE - VERSION CONSTRAINTS
# -----------------------------------------------------------------------------
#
# This file defines the required versions of Terraform and providers needed
# to use this module. Version constraints ensure compatibility and prevent
# breaking changes from affecting infrastructure deployments.
#
# Requirements:
#   - Terraform: 1.0 or higher (supports modern networking features)
#   - AWS Provider: 5.x series (latest VPC and NAT Gateway capabilities)
#
# IMPORTANT:
#   - AWS provider ~> 5.0 provides enhanced VPC feature support
#   - Terraform >= 1.0 required for count and for_each improvements
#   - Module uses depends_on for proper resource ordering
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
