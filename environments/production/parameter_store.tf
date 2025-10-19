# =============================================================================
# PARAMETER STORE (Secrets Management)
# =============================================================================

module "parameter_store" {
  source = "../../modules/parameter-store"

  parameters = {
    "/${var.environment}/database/master_username" = {
      description = "RDS master username"
      type        = "SecureString"
      value       = "dbadmin"
    }
    "/${var.environment}/database/master_password" = {
      description = "RDS master password"
      type        = "SecureString"
      value       = "ChangeMe123!"
    }
    "/${var.environment}/redis/auth_token" = {
      description = "Redis AUTH token"
      type        = "SecureString"
      value       = "MyRedisAuthToken1234567890!" # Must be 16-128 alphanumeric
    }
    "/${var.environment}/opensearch/master_password" = {
      description = "OpenSearch master password"
      type        = "SecureString"
      value       = "OpenSearch123!" # Must meet complexity requirements
    }
    "/${var.environment}/app/api_key" = {
      description = "Application API key"
      type        = "SecureString"
      value       = "your-api-key-here"
    }
    "/${var.environment}/app/encryption_key" = {
      description = "Application encryption key"
      type        = "SecureString"
      value       = "your-encryption-key-here"
    }
  }

  tags = {
    Environment = var.environment
  }
}
