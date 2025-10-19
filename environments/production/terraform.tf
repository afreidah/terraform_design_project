terraform {
  # Minimum Terraform version required
  required_version = ">= 1.5.0"

  # Required provider versions
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

  # Backend configuration for remote state
  # Commented out for initial development - uncomment after creating S3 backend
  # See bootstrap/ directory for backend infrastructure setup

  # backend "s3" {
  #   bucket         = "8am-project-terraform-state"
  #   key            = "production/infrastructure.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-locks"
  #   
  #   # Optional: Use KMS for state encryption
  #   # kms_key_id = "arn:aws:kms:us-east-1:ACCOUNT_ID:key/KEY_ID"
  # }
}
