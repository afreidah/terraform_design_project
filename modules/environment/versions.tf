# -----------------------------------------------------------------------------
# TERRAFORM & PROVIDER VERSION CONSTRAINTS
# -----------------------------------------------------------------------------
#
# This file defines version constraints for Terraform and required providers.
#
# Version Strategy:
#   - Terraform: >= 1.5.0 for latest features and stability
#   - Providers: ~> major.0 to allow minor/patch updates while preventing breaking changes
#
# Providers:
#   - aws: AWS provider for resource management
#   - tls: TLS provider for certificate generation (EKS)
#   - random: Random provider for password/token generation
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
