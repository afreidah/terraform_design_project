# SSM Parameter Store
# Secure storage for application secrets and configuration

# Random password for RDS
resource "random_password" "db_password" {
  length  = 32
  special = true
}

module "parameter_store" {
  source = "../../modules/parameter-store"

  parameters = {
    # Database credentials
    "/${var.environment}/rds/password" = {
      value       = random_password.db_password.result
      description = "RDS master password"
      type        = "SecureString"
    }
    "/${var.environment}/rds/endpoint" = {
      value       = module.rds.endpoint
      description = "RDS endpoint"
      type        = "String"
    }
    "/${var.environment}/rds/username" = {
      value       = module.rds.username
      description = "RDS master username"
      type        = "String"
    }

    # Application configuration
    "/${var.environment}/app/env" = {
      value       = var.environment
      description = "Application environment"
      type        = "String"
    }
    "/${var.environment}/app/region" = {
      value       = var.region
      description = "AWS region"
      type        = "String"
    }
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
