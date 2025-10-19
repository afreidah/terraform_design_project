# KMS Keys for encryption

# KMS key for Parameter Store
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

# KMS key for CloudWatch Logs
module "kms_cloudwatch_logs" {
  source = "../../modules/kms"

  description = "KMS key for CloudWatch Logs encryption"
  alias_name  = "${var.environment}-cloudwatch-logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
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

# KMS key for RDS
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

# KMS key for ElastiCache
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

# KMS key for OpenSearch
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

# KMS key for MSK
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

# Outputs
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
