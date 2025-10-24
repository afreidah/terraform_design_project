# -----------------------------------------------------------------------------
# EKS CLUSTER MODULE - VERSION CONSTRAINTS
# -----------------------------------------------------------------------------
#
# This file defines the required versions of Terraform and providers needed
# to use this module. Version constraints ensure compatibility and prevent
# breaking changes from affecting infrastructure deployments.
#
# Requirements:
#   - Terraform: 1.5.0 or higher (supports advanced EKS features)
#   - AWS Provider: 5.x series (latest EKS cluster and add-on features)
#   - TLS Provider: 4.x series (for OIDC certificate retrieval)
#   - Kubernetes Provider: 2.23+ (for aws-auth ConfigMap management)
#
# IMPORTANT:
#   - AWS provider ~> 5.0 required for EKS add-on IRSA support
#   - Kubernetes provider needed only if manage_aws_auth_configmap = true
#   - TLS provider required for OIDC provider certificate thumbprint
#   - Terraform >= 1.5.0 required for optional object attributes
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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}
