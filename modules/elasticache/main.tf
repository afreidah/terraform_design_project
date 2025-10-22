# -----------------------------------------------------------------------------
# ELASTICACHE REDIS MODULE
# -----------------------------------------------------------------------------
#
# This module creates an Amazon ElastiCache Redis replication group with
# high availability, encryption, and automated backup capabilities for
# caching and session management workloads.
#
# Components Created:
#   - Replication Group: Redis cluster with automatic failover
#   - Subnet Group: Network placement for cache nodes
#   - Parameter Group: Redis configuration settings
#
# Features:
#   - Multi-AZ deployment for high availability
#   - Automatic failover for self-healing
#   - Encryption at rest and in transit
#   - Redis AUTH token support for authentication
#   - Automated daily snapshots with retention
#   - SNS notifications for cluster events
#   - Auto minor version upgrades
#
# Security Model:
#   - Encryption at Rest: KMS encryption for data protection
#   - Encryption in Transit: TLS encryption for client connections
#   - AUTH Token: Password-based authentication for Redis
#   - VPC Isolation: Deployed in private subnets with security groups
#   - Network Access Control: Security groups restrict client access
#
# IMPORTANT:
#   - AUTH token required when transit encryption enabled
#   - Automatic failover requires at least 2 cache nodes
#   - Multi-AZ requires automatic failover to be enabled
#   - Snapshot window and maintenance window must not overlap
#   - Auth token changes ignored in lifecycle to prevent forced updates
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# ELASTICACHE SUBNET GROUP
# -----------------------------------------------------------------------------

# Subnet group for cache node placement
# Defines which subnets cache nodes can be launched in
resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.cluster_id}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_id}-subnet-group"
    }
  )
}

# -----------------------------------------------------------------------------
# ELASTICACHE PARAMETER GROUP
# -----------------------------------------------------------------------------

# Parameter group for Redis configuration
# Controls Redis engine parameters and behavior
resource "aws_elasticache_parameter_group" "this" {
  name   = "${var.cluster_id}-params"
  family = var.parameter_group_family

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_id}-params"
    }
  )
}

# -----------------------------------------------------------------------------
# ELASTICACHE REPLICATION GROUP (REDIS)
# -----------------------------------------------------------------------------

# Redis replication group with automatic failover and high availability
# Provides in-memory caching with data persistence and replication
resource "aws_elasticache_replication_group" "this" {
  replication_group_id = var.cluster_id
  description          = "Redis replication group for ${var.cluster_id}"

  # -------------------------------------------------------------------------
  # ENGINE CONFIGURATION
  # -------------------------------------------------------------------------
  # Redis engine settings and node sizing
  engine               = var.engine
  engine_version       = var.engine_version
  node_type            = var.node_type
  num_cache_clusters   = var.num_cache_nodes
  parameter_group_name = aws_elasticache_parameter_group.this.name
  port                 = var.port

  # -------------------------------------------------------------------------
  # NETWORK CONFIGURATION
  # -------------------------------------------------------------------------
  # VPC placement and security group access control
  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = var.security_group_ids

  # -------------------------------------------------------------------------
  # HIGH AVAILABILITY CONFIGURATION
  # -------------------------------------------------------------------------
  # Multi-AZ deployment with automatic failover for resilience
  automatic_failover_enabled = var.automatic_failover_enabled
  multi_az_enabled           = var.multi_az_enabled

  # -------------------------------------------------------------------------
  # ENCRYPTION CONFIGURATION
  # -------------------------------------------------------------------------
  # Data protection at rest and in transit
  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  auth_token                 = var.auth_token_enabled ? var.auth_token : null
  kms_key_id                 = var.kms_key_id

  # -------------------------------------------------------------------------
  # BACKUP CONFIGURATION
  # -------------------------------------------------------------------------
  # Automated snapshots for disaster recovery
  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window          = var.snapshot_window
  maintenance_window       = var.maintenance_window

  # -------------------------------------------------------------------------
  # NOTIFICATION CONFIGURATION
  # -------------------------------------------------------------------------
  # SNS topic for cluster event notifications
  notification_topic_arn = var.notification_topic_arn

  # -------------------------------------------------------------------------
  # UPDATE CONFIGURATION
  # -------------------------------------------------------------------------
  # Control update behavior and timing
  apply_immediately          = false
  auto_minor_version_upgrade = true

  tags = merge(
    var.tags,
    {
      Name = var.cluster_id
    }
  )

  lifecycle {
    ignore_changes = [auth_token]
  }
}
