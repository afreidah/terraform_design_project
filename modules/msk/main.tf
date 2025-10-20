# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "this" {
  for_each = var.cloudwatch_logs_enabled ? toset(["enabled"]) : toset([])

  name              = "/aws/msk/${var.cluster_name}"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = var.cloudwatch_kms_key_id

  tags = var.tags
}

# MSK Cluster
resource "aws_msk_cluster" "this" {
  cluster_name           = var.cluster_name
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.number_of_broker_nodes

  broker_node_group_info {
    instance_type   = var.broker_node_instance_type
    client_subnets  = var.subnet_ids
    security_groups = var.security_group_ids

    storage_info {
      ebs_storage_info {
        volume_size = var.broker_node_ebs_volume_size
      }
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = var.encryption_in_transit_client_broker
      in_cluster    = var.encryption_in_transit_in_cluster
    }

    encryption_at_rest_kms_key_arn = var.encryption_at_rest_kms_key_arn
  }

  enhanced_monitoring = var.enhanced_monitoring

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = var.cloudwatch_logs_enabled
        log_group = var.cloudwatch_logs_enabled ? one(values(aws_cloudwatch_log_group.this)[*].name) : null
      }

      s3 {
        enabled = var.s3_logs_enabled
        bucket  = var.s3_logs_bucket
        prefix  = var.s3_logs_prefix
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.cluster_name
    }
  )
}
