# -----------------------------------------------------------------------------
# DATA SOURCES
# -----------------------------------------------------------------------------
#
# This file defines data sources for retrieving information about:
#   - Current AWS account identity
#   - Parameter Store values (secrets and configuration)
#
# Data sources are read-only and don't create resources.
# They're used to:
#   - Get dynamic values that can't be hard-coded (account ID, region)
#   - Retrieve secrets stored in Parameter Store for use in resources
#   - Ensure dependencies are met before reading sensitive data
#
# IMPORTANT:
#   - Parameter Store data sources use with_decryption = true for SecureString
#   - depends_on ensures parameters exist before attempting to read them
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# AWS ACCOUNT INFORMATION
# -----------------------------------------------------------------------------

# Current AWS account ID and ARN
# Used for constructing IAM policies and resource ARNs
data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# PARAMETER STORE - SECRETS RETRIEVAL
# -----------------------------------------------------------------------------
#
# Retrieves encrypted secrets from AWS Systems Manager Parameter Store
# These parameters are created by parameter_store.tf and encrypted with KMS
#
# SECURITY NOTE:
#   - with_decryption = true: Decrypts SecureString parameters using KMS
#   - depends_on: Ensures parameters exist before attempting to read
#   - These values should NEVER be logged or exposed in outputs
# -----------------------------------------------------------------------------

# Redis authentication token for ElastiCache
data "aws_ssm_parameter" "redis_auth_token" {
  name            = "/${var.environment}/redis/auth_token"
  with_decryption = true

  depends_on = [module.parameter_store]
}

# OpenSearch master user password
data "aws_ssm_parameter" "opensearch_master_password" {
  name            = "/${var.environment}/opensearch/master_password"
  with_decryption = true

  depends_on = [module.parameter_store]
}
