# -----------------------------------------------------------------------------
# KMS ENCRYPTION KEYS
# -----------------------------------------------------------------------------
#
# This file defines KMS Customer Managed Keys (CMKs) for encrypting data at rest
# across multiple AWS services. Separate keys provide:
#   - Security isolation between services
#   - Granular access control per service
#   - Independent key rotation schedules
#   - Audit trail per service via CloudTrail
#
# Keys Defined:
#   - Parameter Store: Encrypts SecureString parameters (secrets, passwords)
#   - CloudWatch Logs: Encrypts log data (requires special policy for logs service)
#   - RDS: Encrypts database storage and automated backups
#   - ElastiCache: Encrypts Redis data at rest
#   - OpenSearch: Encrypts search indices and snapshots
#   - MSK: Encrypts Kafka data at rest
#   - EKS: Encrypts Kubernetes secrets at rest
#
# Security Features:
#   - Automatic key rotation: Enabled by default (yearly)
#   - Access control: IAM policies control key usage
#   - Audit logging: All key operations logged to CloudTrail
#   - Regional: Keys are regional and don't leave AWS region
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# PARAMETER STORE ENCRYPTION KEY
# -----------------------------------------------------------------------------

# Encrypts sensitive configuration stored in AWS Systems Manager Parameter Store
# Used for: database passwords, API keys, Redis tokens, application secrets
module "kms_parameter_store" {
  source = "../../modules/kms"

  description = "KMS key for SSM Parameter Store encryption"
  alias_name  = "${var.environment}-parameter-store"

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.environment}-parameter-store-key"
      Purpose = "parameter-store"
    }
  )
}

# -----------------------------------------------------------------------------
# CLOUDWATCH LOGS ENCRYPTION KEY
# -----------------------------------------------------------------------------

# Encrypts CloudWatch Logs from EKS, VPC Flow Logs, and other services
# IMPORTANT: Requires custom policy to allow CloudWatch Logs service access
module "kms_cloudwatch_logs" {
  source = "../../modules/kms"

  description = "KMS key for CloudWatch Logs encryption"
  alias_name  = "${var.environment}-cloudwatch-logs"

  # -------------------------------------------------------------------------
  # CUSTOM KEY POLICY
  # -------------------------------------------------------------------------
  # CloudWatch Logs requires explicit permission to use KMS keys
  # Standard key policy (root account access) + CloudWatch Logs service access
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Root account full access (required for key management)
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      # CloudWatch Logs service access
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
        # Condition restricts to logs in this account/region only
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.environment}-cloudwatch-logs-key"
      Purpose = "cloudwatch-logs"
    }
  )
}

# -----------------------------------------------------------------------------
# DATA TIER ENCRYPTION KEYS
# -----------------------------------------------------------------------------

# RDS Database Encryption Key
# Encrypts: DB storage, automated backups, read replicas, snapshots
module "kms_rds" {
  source = "../../modules/kms"

  description = "KMS key for RDS encryption"
  alias_name  = "${var.environment}-rds"

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.environment}-rds-key"
      Purpose = "rds"
    }
  )
}

# ElastiCache Redis Encryption Key
# Encrypts: Redis data at rest, backups
module "kms_elasticache" {
  source = "../../modules/kms"

  description = "KMS key for ElastiCache encryption"
  alias_name  = "${var.environment}-elasticache"

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.environment}-elasticache-key"
      Purpose = "elasticache"
    }
  )
}

# OpenSearch Encryption Key
# Encrypts: Indices, snapshots, automated backups
module "kms_opensearch" {
  source = "../../modules/kms"

  description = "KMS key for OpenSearch encryption"
  alias_name  = "${var.environment}-opensearch"

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.environment}-opensearch-key"
      Purpose = "opensearch"
    }
  )
}

# MSK Kafka Encryption Key
# Encrypts: Kafka data at rest, log segments
module "kms_msk" {
  source = "../../modules/kms"

  description = "KMS key for MSK encryption"
  alias_name  = "${var.environment}-msk"

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.environment}-msk-key"
      Purpose = "msk"
    }
  )
}

# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------

output "kms_parameter_store_key_id" {
  description = "KMS key ID for Parameter Store"
  value       = module.kms_parameter_store.key_id
}

output "kms_parameter_store_key_arn" {
  description = "KMS key ARN for Parameter Store"
  value       = module.kms_parameter_store.key_arn
}

output "kms_cloudwatch_logs_key_id" {
  description = "KMS key ID for CloudWatch Logs"
  value       = module.kms_cloudwatch_logs.key_id
}

output "kms_cloudwatch_logs_key_arn" {
  description = "KMS key ARN for CloudWatch Logs"
  value       = module.kms_cloudwatch_logs.key_arn
}

output "kms_rds_key_arn" {
  description = "KMS key ARN for RDS"
  value       = module.kms_rds.key_arn
}

output "kms_elasticache_key_arn" {
  description = "KMS key ARN for ElastiCache"
  value       = module.kms_elasticache.key_arn
}

output "kms_opensearch_key_arn" {
  description = "KMS key ARN for OpenSearch"
  value       = module.kms_opensearch.key_arn
}

output "kms_msk_key_arn" {
  description = "KMS key ARN for MSK"
  value       = module.kms_msk.key_arn
}
