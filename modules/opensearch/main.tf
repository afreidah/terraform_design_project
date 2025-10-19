# OpenSearch Domain
resource "aws_opensearch_domain" "this" {
  domain_name    = var.domain_name
  engine_version = var.engine_version

  cluster_config {
    instance_type  = var.instance_type
    instance_count = var.instance_count

    dedicated_master_enabled = var.dedicated_master_enabled
    dedicated_master_type    = var.dedicated_master_type
    dedicated_master_count   = var.dedicated_master_count

    zone_awareness_enabled = var.zone_awareness_enabled

    dynamic "zone_awareness_config" {
      for_each = var.zone_awareness_enabled ? [1] : []
      content {
        availability_zone_count = var.availability_zone_count
      }
    }
  }

  ebs_options {
    ebs_enabled = var.ebs_enabled
    volume_type = var.volume_type
    volume_size = var.volume_size
    iops        = var.volume_type == "gp3" ? var.iops : null
    throughput  = var.volume_type == "gp3" ? var.throughput : null
  }

  encrypt_at_rest {
    enabled    = var.encrypt_at_rest_enabled
    kms_key_id = var.kms_key_id
  }

  node_to_node_encryption {
    enabled = var.node_to_node_encryption_enabled
  }

  domain_endpoint_options {
    enforce_https       = var.domain_endpoint_options.enforce_https
    tls_security_policy = var.domain_endpoint_options.tls_security_policy
  }

  # Only add advanced_security_options if enabled
  dynamic "advanced_security_options" {
    for_each = var.advanced_security_options.enabled ? [1] : []
    content {
      enabled                        = true
      internal_user_database_enabled = var.advanced_security_options.internal_user_database_enabled

      master_user_options {
        master_user_name     = var.advanced_security_options.master_user_name
        master_user_password = var.advanced_security_options.master_user_password
      }
    }
  }

  vpc_options {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  snapshot_options {
    automated_snapshot_start_hour = var.automated_snapshot_start_hour
  }

  # Index slow logs
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.index_slow_logs.arn
    log_type                 = "INDEX_SLOW_LOGS"
    enabled                  = true
  }

  # Search slow logs
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.search_slow_logs.arn
    log_type                 = "SEARCH_SLOW_LOGS"
    enabled                  = true
  }

  # Application logs
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.es_application_logs.arn
    log_type                 = "ES_APPLICATION_LOGS"
    enabled                  = true
  }

  # Audit logs
  dynamic "log_publishing_options" {
    for_each = var.enable_audit_logs ? [1] : []
    content {
      cloudwatch_log_group_arn = aws_cloudwatch_log_group.audit_logs[0].arn
      log_type                 = "AUDIT_LOGS"
      enabled                  = true
    }
  }

  tags = var.tags

  depends_on = [
    aws_cloudwatch_log_group.index_slow_logs,
    aws_cloudwatch_log_group.search_slow_logs,
    aws_cloudwatch_log_group.es_application_logs,
    aws_cloudwatch_log_resource_policy.this
  ]
}

# CloudWatch Log Group - Index Slow Logs
resource "aws_cloudwatch_log_group" "index_slow_logs" {
  name              = "/aws/opensearch/${var.domain_name}/index-slow-logs"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = var.cloudwatch_kms_key_id

  tags = var.tags
}

# CloudWatch Log Group - Search Slow Logs
resource "aws_cloudwatch_log_group" "search_slow_logs" {
  name              = "/aws/opensearch/${var.domain_name}/search-slow-logs"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = var.cloudwatch_kms_key_id

  tags = var.tags
}

# CloudWatch Log Group - Application Logs
resource "aws_cloudwatch_log_group" "es_application_logs" {
  name              = "/aws/opensearch/${var.domain_name}/application-logs"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = var.cloudwatch_kms_key_id

  tags = var.tags
}

# CloudWatch Log Group - Audit Logs
resource "aws_cloudwatch_log_group" "audit_logs" {
  count = var.enable_audit_logs ? 1 : 0

  name              = "/aws/opensearch/${var.domain_name}/audit-logs"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = var.cloudwatch_kms_key_id

  tags = var.tags
}

# CloudWatch Log Resource Policy
resource "aws_cloudwatch_log_resource_policy" "this" {
  policy_name = "${var.domain_name}-opensearch-logs"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "es.amazonaws.com"
        }
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogStream"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/opensearch/${var.domain_name}/*"
      }
    ]
  })
}
