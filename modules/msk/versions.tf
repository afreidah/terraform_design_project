# -----------------------------------------------------------------------------
# MSK MODULE - VERSION CONSTRAINTS
# -----------------------------------------------------------------------------
#
# This file defines the required versions of Terraform and providers needed
# to use this module. Version constraints ensure compatibility and prevent
# breaking changes from affecting infrastructure deployments.
#
# Requirements:
#   - Terraform: 1.0 or higher (supports for_each with conditional expressions)
#   - AWS Provider: 5.x series (latest MSK features and Kafka versions)
#
# IMPORTANT:
#   - AWS provider ~> 5.0 provides Kafka 3.x version support
#   - Terraform >= 1.0 required for conditional CloudWatch log group creation
#   - Module uses one() function for log group name reference
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
