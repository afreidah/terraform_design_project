# -----------------------------------------------------------------------------
# RDS DATABASE INSTANCE
# -----------------------------------------------------------------------------
#
# This file defines a PostgreSQL database using Amazon RDS for application
# data persistence.
#
# Architecture:
#   - Engine: PostgreSQL 15.4 (LTS release)
#   - Instance Class: db.t3.micro (2 vCPU, 1 GiB RAM)
#   - Storage: 20 GB initial, auto-scaling to 100 GB maximum
#   - Network: Private data subnets (no direct internet access)
#   - Multi-AZ: Synchronous standby in different AZ for HA
#
# High Availability:
#   - Multi-AZ Deployment: Automatic failover to standby instance
#   - Synchronous Replication: Zero data loss during failover
#   - Automatic Backups: Daily snapshots retained for 7 days
#   - Point-in-Time Recovery: Restore to any second within backup window
#
# Security:
#   - Encryption at Rest: Storage and backups encrypted with KMS
#   - Encryption in Transit: SSL/TLS connections enforced
#   - Network Isolation: Security group allows VPC access only (port 5432)
#   - IAM Authentication: Enabled for IAM user/role database access
#   - Deletion Protection: Prevents accidental database deletion
#
# Backup Strategy:
#   - Automated Backups: Daily full backups + transaction log archival
#   - Retention Period: 7 days (meets RPO requirements)
#   - Backup Window: 03:00-04:00 UTC (off-peak hours)
#   - Final Snapshot: Created before deletion for disaster recovery
#
# Maintenance:
#   - Maintenance Window: Sunday 04:00-05:00 UTC (after backups)
#   - Auto Minor Version Upgrades: Disabled (manual control preferred)
#   - Patching: Applied during maintenance window
#
# Monitoring:
#   - CloudWatch Logs: PostgreSQL logs and upgrade logs
#   - Performance Insights: 7-day retention for query analysis
#   - Enhanced Monitoring: OS-level metrics (optional, not enabled)
# -----------------------------------------------------------------------------

module "rds" {
  source = "../../modules/rds"

  # -------------------------------------------------------------------------
  # INSTANCE IDENTIFICATION
  # -------------------------------------------------------------------------
  identifier     = "${var.environment}-postgres-db"
  engine         = "postgres"
  engine_version = "15.4"        # PostgreSQL LTS version
  instance_class = "db.t3.micro" # 2 vCPU, 1 GiB RAM

  # -------------------------------------------------------------------------
  # STORAGE CONFIGURATION
  # -------------------------------------------------------------------------
  allocated_storage     = 20   # Initial storage in GB
  max_allocated_storage = 100  # Auto-scale up to 100 GB
  storage_encrypted     = true # Encrypt storage with KMS

  # -------------------------------------------------------------------------
  # DATABASE CREDENTIALS
  # -------------------------------------------------------------------------
  # Password generated randomly in parameter_store.tf
  db_name  = "appdb"
  username = "dbadmin"
  password = random_password.db_password.result

  # -------------------------------------------------------------------------
  # NETWORK CONFIGURATION
  # -------------------------------------------------------------------------
  vpc_security_group_ids     = [module.security_groups["rds"].security_group_id]
  db_subnet_group_subnet_ids = module.networking.private_data_subnet_ids

  # -------------------------------------------------------------------------
  # BACKUP CONFIGURATION
  # -------------------------------------------------------------------------
  backup_retention_period = 7                     # Days to retain automated backups
  backup_window           = "03:00-04:00"         # Daily backup window (UTC, off-peak)
  maintenance_window      = "sun:04:00-sun:05:00" # Weekly maintenance window (UTC)

  # -------------------------------------------------------------------------
  # HIGH AVAILABILITY
  # -------------------------------------------------------------------------
  multi_az            = true  # Deploy standby in different AZ
  publicly_accessible = false # No public internet access

  # -------------------------------------------------------------------------
  # DELETION PROTECTION
  # -------------------------------------------------------------------------
  deletion_protection = true # Prevent accidental deletion

  # -------------------------------------------------------------------------
  # FINAL SNAPSHOT
  # -------------------------------------------------------------------------
  # Create snapshot before deletion for disaster recovery
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.environment}-postgres-final-snapshot"

  # -------------------------------------------------------------------------
  # CLOUDWATCH LOGS
  # -------------------------------------------------------------------------
  # Export PostgreSQL and upgrade logs to CloudWatch
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # -------------------------------------------------------------------------
  # PERFORMANCE INSIGHTS
  # -------------------------------------------------------------------------
  # Query performance analysis tool
  performance_insights_enabled          = true
  performance_insights_retention_period = 7 # Days to retain performance data

  # -------------------------------------------------------------------------
  # IAM AUTHENTICATION
  # -------------------------------------------------------------------------
  # Allow IAM users/roles to authenticate to database
  iam_database_authentication_enabled = true

  tags = {
    Environment = var.environment
    Service     = "database"
    ManagedBy   = "terraform"
  }
}
