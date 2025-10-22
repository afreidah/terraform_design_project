# -----------------------------------------------------------------------------
# KMS KEY MODULE - OUTPUT VALUES
# -----------------------------------------------------------------------------
#
# This file exposes attributes of the created KMS key and optional alias
# for use by parent modules, encryption operations, and resource policies.
#
# Output Categories:
#   - Key Attributes: KMS key identifiers for encryption operations
#   - Alias Attributes: Human-readable key reference (when created)
#
# Usage:
#   - key_id: Short-form key identifier (e.g., for AWS CLI operations)
#   - key_arn: Full ARN for IAM policies and resource encryption configs
#   - alias_name: Human-readable reference for application code
#   - alias_arn: Full alias ARN for IAM policy conditions
#
# Examples:
#   - EBS: Use key_arn in aws_ebs_volume.kms_key_id
#   - S3: Use key_arn in aws_s3_bucket_server_side_encryption_configuration
#   - RDS: Use key_arn in aws_db_instance.kms_key_id
#   - Secrets Manager: Use key_arn in aws_secretsmanager_secret.kms_key_id
#
# Note:
#   - Alias outputs are null when alias_name not provided
#   - Key ARN format: arn:aws:kms:region:account:key/key-id
#   - Alias ARN format: arn:aws:kms:region:account:alias/alias-name
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# KEY OUTPUTS
# -----------------------------------------------------------------------------

output "key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.this.id
}

output "key_arn" {
  description = "KMS key ARN"
  value       = aws_kms_key.this.arn
}

# -----------------------------------------------------------------------------
# ALIAS OUTPUTS
# -----------------------------------------------------------------------------

output "alias_arn" {
  description = "KMS alias ARN"
  value       = try(aws_kms_alias.this[0].arn, null)
}

output "alias_name" {
  description = "KMS alias name"
  value       = try(aws_kms_alias.this[0].name, null)
}
