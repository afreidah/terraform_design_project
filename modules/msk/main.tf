# -----------------------------------------------------------------------------
# MSK (MANAGED STREAMING FOR APACHE KAFKA) MODULE
# -----------------------------------------------------------------------------
#
# This module creates an Amazon Managed Streaming for Apache Kafka (MSK)
# cluster with encryption, monitoring, and logging capabilities for streaming
# data pipelines and event-driven architectures.
#
# Components Created:
#   - MSK Cluster: Managed Apache Kafka cluster with broker nodes
#   - CloudWatch Log Group: Optional broker log aggregation
#
# Features:
#   - Multi-AZ deployment for high availability
#   - Encryption at rest with KMS
#   - Encryption in transit (TLS) for client and inter-broker communication
#   - Enhanced monitoring at multiple granularity levels
#   - CloudWatch Logs integration for broker logs
#   - Optional S3 logging for long-term retention
#   - Configurable broker instance types and EBS volumes
#
# Architecture:
#   - Broker nodes distributed across availability zones
#   - Number of brokers must be multiple of AZ count
#   - Each broker gets dedicated EBS volume for storage
#   - Zookeeper managed by AWS (included)
#
# Security Model:
#   - Encryption at Rest: KMS encryption for EBS volumes
#   - Encryption in Transit: TLS for client-broker and inter-broker
#   - VPC Isolation: Brokers deployed in private subnets
#   - Security Groups: Network access control for clients
#   - CloudWatch Logs: Optional encryption with KMS
#
# IMPORTANT:
#   - Number of broker nodes must be multiple of AZ count
#   - Minimum 3 brokers recommended for production (one per AZ)
#   - EBS volume size cannot be decreased after creation
#   - Kafka version upgrades are one-way operations
#   - Bootstrap broker endpoints provided after creation
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# CLOUDWATCH LOG GROUP
# -----------------------------------------------------------------------------

# CloudWatch log group for MSK broker logs
# Only created when CloudWatch logging is enabled
resource "aws_cloudwatch_log_group" "this" {
  for_each = var.cloudwatch_logs_enabled ? toset(["enabled"]) : toset([])

  name              = "/aws/msk/${var.cluster_name}"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = var.cloudwatch_kms_key_id

  tags = var.tags
}

# -----------------------------------------------------------------------------
# MSK CLUSTER
# -----------------------------------------------------------------------------

# Amazon MSK cluster for Apache Kafka streaming
# Provides managed Kafka brokers with automatic patching and maintenance
resource "aws_msk_cluster" "this" {
  cluster_name           = var.cluster_name
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.number_of_broker_nodes

  # -------------------------------------------------------------------------
  # BROKER NODE CONFIGURATION
  # -------------------------------------------------------------------------
  # Instance sizing, networking, and storage for Kafka brokers
  broker_node_group_info {
    instance_type   = var.broker_node_instance_type
    client_subnets  = var.subnet_ids
    security_groups = var.security_group_ids

    # EBS storage for broker data persistence
    storage_info {
      ebs_storage_info {
        volume_size = var.broker_node_ebs_volume_size
      }
    }
  }

  # -------------------------------------------------------------------------
  # ENCRYPTION CONFIGURATION
  # -------------------------------------------------------------------------
  # Data protection at rest and in transit
  encryption_info {
    # Encryption in transit settings
    encryption_in_transit {
      client_broker = var.encryption_in_transit_client_broker
      in_cluster    = var.encryption_in_transit_in_cluster
    }

    # Encryption at rest using KMS
    encryption_at_rest_kms_key_arn = var.encryption_at_rest_kms_key_arn
  }

  # -------------------------------------------------------------------------
  # MONITORING CONFIGURATION
  # -------------------------------------------------------------------------
  # CloudWatch metrics granularity level
  enhanced_monitoring = var.enhanced_monitoring

  # -------------------------------------------------------------------------
  # LOGGING CONFIGURATION
  # -------------------------------------------------------------------------
  # Broker log delivery to CloudWatch and/or S3
  logging_info {
    broker_logs {
      # CloudWatch Logs for real-time monitoring
      cloudwatch_logs {
        enabled   = var.cloudwatch_logs_enabled
        log_group = var.cloudwatch_logs_enabled ? one(values(aws_cloudwatch_log_group.this)[*].name) : null
      }

      # S3 for long-term log retention and analysis
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
