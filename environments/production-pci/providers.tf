# AWS Provider - Primary region
provider "aws" {
  region = var.region

  # Default tags applied to all resources
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "infrastructure-exercise"
    }
  }

  # Assume role if using cross-account access
  # assume_role {
  #   role_arn     = "arn:aws:iam::ACCOUNT_ID:role/TerraformRole"
  #   session_name = "terraform-${var.environment}"
  # }
}

# TLS Provider - For self-signed certificates
provider "tls" {}

# Random Provider - For generating secure passwords/tokens
provider "random" {}

# Additional AWS provider for multi-region resources
#
# provider "aws" {
#   alias  = "us-west-2"
#   region = "us-west-2"
#
#   default_tags {
#     tags = {
#       Environment = var.environment
#       ManagedBy   = "Terraform"
#       Project     = "infrastructure-exercise"
#     }
#   }
# }
