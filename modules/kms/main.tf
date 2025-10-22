# -----------------------------------------------------------------------------
# KMS KEY MODULE
# -----------------------------------------------------------------------------
#
# This module creates an AWS Key Management Service (KMS) customer managed key
# with optional automatic key rotation, configurable deletion protection, and
# alias support for encryption operations across AWS services.
#
# Components Created:
#   - KMS Customer Managed Key: Encryption key for data protection
#   - KMS Alias: Optional human-readable alias for key reference
#
# Features:
#   - Automatic key rotation for enhanced security
#   - Configurable deletion window for accidental deletion protection
#   - Custom key policy support for fine-grained access control
#   - Optional alias for easier key reference in applications
#   - Multi-region key support (when configured)
#
# Common Use Cases:
#   - EBS Volume Encryption: Encrypt EC2 instance volumes
#   - S3 Bucket Encryption: Server-side encryption with KMS
#   - RDS Database Encryption: Encrypt databases at rest
#   - Secrets Manager: Encrypt secrets and credentials
#   - Parameter Store: Encrypt SecureString parameters
#   - CloudWatch Logs: Encrypt log data at rest
#   - Lambda Environment Variables: Encrypt sensitive configuration
#
# Security Model:
#   - Customer Managed Keys: Full control over key lifecycle and policies
#   - Key Rotation: Automatic annual rotation when enabled
#   - Key Policy: Controls who can use and manage the key
#   - Deletion Protection: Minimum 7-day waiting period before deletion
#   - Audit Trail: CloudTrail logs all key usage
#
# IMPORTANT:
#   - Deleted keys cannot be recovered after deletion window expires
#   - Key rotation does not affect encrypted data (transparent)
#   - Alias names must be unique within the region
#   - Default key policy grants account root full access
#   - Custom policies must allow necessary KMS operations
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# KMS CUSTOMER MANAGED KEY
# -----------------------------------------------------------------------------

# Customer managed KMS key for encryption operations
# Provides full control over key lifecycle, rotation, and access policies
resource "aws_kms_key" "this" {
  description             = var.description
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation
  policy                  = var.policy

  tags = var.tags
}

# -----------------------------------------------------------------------------
# KMS ALIAS
# -----------------------------------------------------------------------------

# Optional human-readable alias for KMS key
# Makes key easier to reference in code and IAM policies
resource "aws_kms_alias" "this" {
  count = var.alias_name != null ? 1 : 0

  name          = "alias/${var.alias_name}"
  target_key_id = aws_kms_key.this.key_id
}
