# -----------------------------------------------------------------------------
# SSM PARAMETER STORE - SECRETS MANAGEMENT
# -----------------------------------------------------------------------------
#
# This file manages application secrets and configuration using AWS Systems
# Manager Parameter Store for secure, centralized secrets management.
#
# Architecture:
#   - SecureString: Sensitive values (passwords, tokens) encrypted with KMS
#   - String: Non-sensitive configuration values (endpoints, usernames)
#   - Hierarchical Paths: Organized by /${environment}/ for isolation
#   - KMS Encryption: All SecureString parameters encrypted at rest
#
# Secrets Stored:
#   - Database Credentials: RDS master password, username, endpoint
#   - Redis Credentials: AUTH token for ElastiCache authentication
#   - OpenSearch Credentials: Master user password
#   - Application Configuration: Environment, region, service endpoints
#
# Security Model:
#   - Random Generation: Passwords generated cryptographically (not hardcoded)
#   - KMS Encryption: SecureString parameters encrypted with dedicated KMS key
#   - IAM Access Control: EC2 roles granted read-only access via IAM policy
#   - Parameter Hierarchy: Environment-specific paths prevent cross-env access
#   - No Git Storage: Sensitive values never committed to source control
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# RANDOM PASSWORD GENERATION
# -----------------------------------------------------------------------------

# RDS master password
# Used for PostgreSQL database authentication
resource "random_password" "db_password" {
  length  = 32   # 32 characters for strong entropy
  special = true # Include special characters (!@#$%^&*)
}

# Redis AUTH token
# Used for ElastiCache authentication
resource "random_password" "redis_auth_token" {
  length           = 32
  special          = false      # Redis has limited special char support
  override_special = "!&#$^<>-" # Explicitly allowed special chars
}

# OpenSearch master user password
# Used for fine-grained access control admin user
resource "random_password" "opensearch_master_password" {
  length  = 32
  special = true
}

# -----------------------------------------------------------------------------
# PARAMETER STORE PARAMETERS
# -----------------------------------------------------------------------------

module "parameter_store" {
  source = "../../modules/parameter-store"

  parameters = {
    # -----------------------------------------------------------------------
    # RDS DATABASE CREDENTIALS
    # -----------------------------------------------------------------------

    # Master password (SecureString - encrypted)
    "/${var.environment}/rds/password" = {
      value       = random_password.db_password.result
      description = "RDS master password"
      type        = "SecureString"
    }

    # Database endpoint (String - not sensitive)
    "/${var.environment}/rds/endpoint" = {
      value       = module.rds.endpoint
      description = "RDS endpoint"
      type        = "String"
    }

    # Master username (String - not sensitive)
    "/${var.environment}/rds/username" = {
      value       = module.rds.username
      description = "RDS master username"
      type        = "String"
    }

    # -----------------------------------------------------------------------
    # REDIS CREDENTIALS
    # -----------------------------------------------------------------------

    # AUTH token (SecureString - encrypted)
    "/${var.environment}/redis/auth_token" = {
      value       = random_password.redis_auth_token.result
      description = "Redis AUTH token"
      type        = "SecureString"
    }

    # -----------------------------------------------------------------------
    # OPENSEARCH CREDENTIALS
    # -----------------------------------------------------------------------

    # Master user password (SecureString - encrypted)
    "/${var.environment}/opensearch/master_password" = {
      value       = random_password.opensearch_master_password.result
      description = "OpenSearch master user password"
      type        = "SecureString"
    }

    # -----------------------------------------------------------------------
    # APPLICATION CONFIGURATION
    # -----------------------------------------------------------------------

    # Environment name
    "/${var.environment}/app/env" = {
      value       = var.environment
      description = "Application environment"
      type        = "String"
    }

    # AWS region
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
