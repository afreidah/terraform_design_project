# -----------------------------------------------------------------------------
# ELASTICACHE REDIS MODULE - VERSION CONSTRAINTS
# -----------------------------------------------------------------------------
#
# This file defines the required versions of Terraform and providers needed
# to use this module. Version constraints ensure compatibility and prevent
# breaking changes from affecting infrastructure deployments.
#
# Requirements:
#   - Terraform: 1.0 or higher (supports lifecycle ignore_changes)
#   - AWS Provider: 5.x series (latest ElastiCache features and encryption)
#
# IMPORTANT:
#   - AWS provider ~> 5.0 provides Redis 7.x engine version support
#   - Terraform >= 1.0 required for auth_token lifecycle management
#   - Provider supports in-transit encryption and AUTH tokens
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
