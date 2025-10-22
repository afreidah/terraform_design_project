# -----------------------------------------------------------------------------
# OPENSEARCH CLUSTER
# -----------------------------------------------------------------------------
#
# This file defines an Amazon OpenSearch Service cluster for search and analytics.
#
# Architecture:
#   - Engine: OpenSearch 2.11 (successor to Elasticsearch)
#   - Data Nodes: 3 x t3.medium.search across 3 AZs
#   - Master Nodes: 3 x t3.small.search (dedicated) for cluster management
#   - Storage: 100 GB EBS (gp3) per data node
#   - Network: Private data subnets (no direct internet access)
#
# High Availability:
#   - Multi-AZ: Nodes distributed across 3 availability zones
#   - Dedicated Masters: Separate master nodes for cluster stability
#   - Zone Awareness: Data replicated across AZs
#   - Automated Snapshots: Daily backups to S3
#
# Security:
#   - Encryption at Rest: KMS encryption for indices and snapshots
#   - Encryption in Transit: Node-to-node TLS for cluster communication
#   - HTTPS Enforcement: All client connections require HTTPS/TLS 1.2+
#   - Fine-Grained Access Control: Username/password authentication
#   - Network: Security group restricts access to VPC only (port 443)
#
# Access Control:
#   - Internal User Database: Enabled with master username/password
#   - Master User: Admin user with full cluster access
#   - Password: Stored in Parameter Store (retrieved via data source)
#
# Monitoring & Backup:
#   - CloudWatch Logs: All OpenSearch logs (audit, application, search)
#   - Audit Logging: Track access and changes for compliance
#   - Automated Snapshots: Daily at 03:00 UTC
#   - Log Retention: 365 days for audit trail
# -----------------------------------------------------------------------------

module "opensearch" {
  source = "../../modules/opensearch"

  # -------------------------------------------------------------------------
  # CLUSTER IDENTIFICATION
  # -------------------------------------------------------------------------
  domain_name    = "${var.environment}-search"
  engine_version = "OpenSearch_2.11"

  # -------------------------------------------------------------------------
  # DATA NODES CONFIGURATION
  # -------------------------------------------------------------------------
  instance_type  = "t3.medium.search" # 2 vCPU, 4 GiB RAM
  instance_count = 3                  # One per AZ

  # -------------------------------------------------------------------------
  # DEDICATED MASTER NODES
  # -------------------------------------------------------------------------
  # Separate master nodes improve cluster stability and performance
  dedicated_master_enabled = true
  dedicated_master_type    = "t3.small.search" # 2 vCPU, 2 GiB RAM
  dedicated_master_count   = 3                 # Quorum requires 3 nodes

  # -------------------------------------------------------------------------
  # MULTI-AZ CONFIGURATION
  # -------------------------------------------------------------------------
  zone_awareness_enabled  = true # Distribute nodes across AZs
  availability_zone_count = 3    # Use all 3 availability zones

  # -------------------------------------------------------------------------
  # STORAGE CONFIGURATION
  # -------------------------------------------------------------------------
  ebs_enabled = true
  volume_type = "gp3" # General Purpose SSD v3
  volume_size = 100   # GB per data node

  # -------------------------------------------------------------------------
  # ENCRYPTION AT REST
  # -------------------------------------------------------------------------
  encrypt_at_rest_enabled = true
  kms_key_id              = module.kms_opensearch.key_arn

  # -------------------------------------------------------------------------
  # ENCRYPTION IN TRANSIT
  # -------------------------------------------------------------------------
  node_to_node_encryption_enabled = true # TLS for cluster communication

  # -------------------------------------------------------------------------
  # ENDPOINT CONFIGURATION
  # -------------------------------------------------------------------------
  domain_endpoint_options = {
    enforce_https       = true                         # Require HTTPS for all connections
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07" # TLS 1.2 minimum
  }

  # -------------------------------------------------------------------------
  # FINE-GRAINED ACCESS CONTROL
  # -------------------------------------------------------------------------
  # Username/password authentication with internal user database
  # IMPORTANT: Cannot be disabled once enabled
  advanced_security_options = {
    enabled                        = true
    internal_user_database_enabled = true
    master_user_name               = "admin"
    master_user_password           = data.aws_ssm_parameter.opensearch_master_password.value
  }

  # -------------------------------------------------------------------------
  # NETWORK CONFIGURATION
  # -------------------------------------------------------------------------
  subnet_ids         = module.networking.private_data_subnet_ids
  security_group_ids = [module.security_groups["elasticsearch"].security_group_id]

  # -------------------------------------------------------------------------
  # BACKUP CONFIGURATION
  # -------------------------------------------------------------------------
  automated_snapshot_start_hour = 3 # Daily snapshots at 03:00 UTC (off-peak)

  # -------------------------------------------------------------------------
  # CLOUDWATCH LOGGING
  # -------------------------------------------------------------------------
  cloudwatch_kms_key_id     = module.kms_cloudwatch_logs.key_arn
  cloudwatch_retention_days = 365  # 1 year retention for audit trail
  enable_audit_logs         = true # Track access for compliance

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-search"
    }
  )
}
