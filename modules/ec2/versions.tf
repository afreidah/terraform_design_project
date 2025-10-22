# -----------------------------------------------------------------------------
# EC2 AUTO SCALING GROUP MODULE - VERSION CONSTRAINTS
# -----------------------------------------------------------------------------
#
# This file defines the required versions of Terraform and providers needed
# to use this module. Version constraints ensure compatibility and prevent
# breaking changes from affecting infrastructure deployments.
#
# Requirements:
#   - Terraform: 1.0 or higher (supports modern lifecycle rules)
#   - AWS Provider: 5.x series (latest ASG and launch template features)
#
# IMPORTANT:
#   - AWS provider ~> 5.0 provides IMDSv2 enforcement support
#   - Terraform >= 1.0 required for ignore_changes on desired_capacity
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
