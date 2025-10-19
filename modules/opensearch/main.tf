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

    zone_awareness_config {
      availability_zone_count = var.availability_zone_count
    }
  }

  ebs_options {
    ebs_enabled = var.ebs_enabled
    volume_type = var.ebs_volume_type
    volume_size = var.ebs_volume_size
  }

  vpc_options {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  encrypt_at_rest {
    enabled    = var.encrypt_at_rest_enabled
    kms_key_id = var.kms_key_id
  }

  node_to_node_encryption {
    enabled = var.node_to_node_encryption_enabled
  }

  domain_endpoint_options {
    enforce_https       = var.enforce_https
    tls_security_policy = var.tls_security_policy
  }

  advanced_security_options {
    enabled                        = var.advanced_security_options_enabled
    internal_user_database_enabled = var.internal_user_database_enabled

    master_user_options {
      master_user_name     = var.master_user_name
      master_user_password = var.master_user_password
    }
  }

  snapshot_options {
    automated_snapshot_start_hour = var.automated_snapshot_start_hour
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.index_slow_logs.arn
    log_type                 = "INDEX_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.search_slow_logs.arn
    log_type                 = "SEARCH_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.es_application_logs.arn
    log_type                 = "ES_APPLICATION_LOGS"
  }

  tags = merge(
    var.tags,
    {
      Name = var.domain_name
    }
  )

  lifecycle {
    ignore_changes = [
      advanced_security_options[0].master_user_options[0].master_user_password
    ]
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "index_slow_logs" {
  name              = "/aws/opensearch/${var.domain_name}/index-slow-logs"
  retention_in_days = 7

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "search_slow_logs" {
  name              = "/aws/opensearch/${var.domain_name}/search-slow-logs"
  retention_in_days = 7

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "es_application_logs" {
  name              = "/aws/opensearch/${var.domain_name}/application-logs"
  retention_in_days = 7

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
