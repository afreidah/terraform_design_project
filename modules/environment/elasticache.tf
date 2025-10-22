# -----------------------------------------------------------------------------
# ELASTICACHE (Redis) CLUSTER
# -----------------------------------------------------------------------------
#
# This file defines an ElastiCache Redis cluster for caching and session storage.
#
# Architecture:
#   - Engine: Redis 7.0 with cluster mode disabled (replication group)
#   - Topology: 3 nodes (1 primary + 2 replicas) across 3 AZs
#   - Node Type: cache.t3.medium (2 vCPU, 3.09 GiB memory)
#   - Network: Private data subnets (no direct internet access)
#
# High Availability:
#   - Automatic failover enabled: Primary fails over to replica automatically
#   - Multi-AZ: Replicas distributed across availability zones
#   - Replication: Asynchronous replication from primary to replicas
#
# Security:
#   - Encryption at rest: KMS encryption for data on disk
#   - Encryption in transit: TLS for client and node connections
#   - Authentication: AUTH token required for connections
#   - Network: Security group restricts access to VPC only (port 6379)
#
# Backup & Maintenance:
#   - Automatic snapshots: Daily backups retained for 7 days
#   - Snapshot window: 03:00-05:00 UTC (off-peak hours)
#   - Maintenance window: Sunday 05:00-07:00 UTC
#
# IMPORTANT:
#   - AUTH token stored in Parameter Store and retrieved via data source
#   - Applications MUST use AUTH token for authentication
#   - Use reader endpoint for read operations to distribute load
# -----------------------------------------------------------------------------

module "elasticache" {
  source = "../../modules/elasticache"

  # -------------------------------------------------------------------------
  # CLUSTER IDENTIFICATION
  # -------------------------------------------------------------------------
  cluster_id             = "${var.environment}-redis"
  engine                 = "redis"
  engine_version         = "7.0"
  parameter_group_family = "redis7"

  # -------------------------------------------------------------------------
  # COMPUTE CONFIGURATION
  # -------------------------------------------------------------------------
  node_type       = "cache.t3.medium" # 2 vCPU, 3.09 GiB memory
  num_cache_nodes = 3                 # 1 primary + 2 replicas (one per AZ)

  # -------------------------------------------------------------------------
  # NETWORK CONFIGURATION
  # -------------------------------------------------------------------------
  subnet_ids         = module.networking.private_data_subnet_ids
  security_group_ids = [module.security_groups["elasticache"].security_group_id]

  # -------------------------------------------------------------------------
  # HIGH AVAILABILITY
  # -------------------------------------------------------------------------
  automatic_failover_enabled = true # Auto-promote replica to primary on failure
  multi_az_enabled           = true # Distribute replicas across AZs

  # -------------------------------------------------------------------------
  # ENCRYPTION & SECURITY
  # -------------------------------------------------------------------------
  at_rest_encryption_enabled = true                                          # Encrypt data on disk
  transit_encryption_enabled = true                                          # Encrypt data in transit (TLS)
  auth_token_enabled         = true                                          # Require AUTH token
  auth_token                 = data.aws_ssm_parameter.redis_auth_token.value # From Parameter Store
  kms_key_id                 = var.kms_key_id                                # KMS key for at-rest encryption

  # -------------------------------------------------------------------------
  # BACKUP & MAINTENANCE
  # -------------------------------------------------------------------------
  snapshot_retention_limit = 7                     # Retain daily snapshots for 7 days
  snapshot_window          = "03:00-05:00"         # Daily backup window (UTC, off-peak)
  maintenance_window       = "sun:05:00-sun:07:00" # Weekly maintenance window (UTC)

  tags = {
    Environment = var.environment
  }
}
