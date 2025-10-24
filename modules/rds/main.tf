# -----------------------------------------------------------------------------
# RDS DATABASE MODULE
# -----------------------------------------------------------------------------
#
# This module creates an Amazon RDS database instance with a dedicated subnet
# group, configurable storage encryption, automated backups, and optional
# features including Multi-AZ deployment, Performance Insights, enhanced
# monitoring, and IAM database authentication.
#
# The instance supports multiple database engines with customizable parameter
# and option groups. CloudWatch logs can be exported for audit and error
# tracking. Automated backups are configured with definable retention periods
# and maintenance windows. Storage autoscaling prevents capacity issues by
# automatically expanding allocated storage up to a configured maximum.
#
# IMPORTANT: Master password changes are ignored in the lifecycle configuration
# to prevent unintended updates. Deletion protection is configurable but should
# remain enabled for production databases. Final snapshots are recommended
# before deletion unless explicitly skipped.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# DB SUBNET GROUP
# -----------------------------------------------------------------------------

# Subnet group for RDS instance placement across availability zones
# Automatically created and named based on the instance identifier
resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.db_subnet_group_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.identifier}-subnet-group"
    }
  )
}

# -----------------------------------------------------------------------------
# RDS DATABASE INSTANCE
# -----------------------------------------------------------------------------

# Amazon RDS database instance with automated backups and optional HA
# Provides managed relational database with automatic patching and monitoring
resource "aws_db_instance" "this" {
  identifier     = var.identifier
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  # -------------------------------------------------------------------------
  # STORAGE CONFIGURATION
  # -------------------------------------------------------------------------
  # Storage sizing, type selection, encryption, and autoscaling
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.kms_key_id

  # -------------------------------------------------------------------------
  # DATABASE CONFIGURATION
  # -------------------------------------------------------------------------
  # Database name, credentials, and connection port
  db_name  = var.db_name
  username = var.username
  password = var.password
  port     = var.port

  # -------------------------------------------------------------------------
  # NETWORK CONFIGURATION
  # -------------------------------------------------------------------------
  # VPC placement, security groups, and accessibility
  vpc_security_group_ids = var.vpc_security_group_ids
  db_subnet_group_name   = aws_db_subnet_group.this.name

  # -------------------------------------------------------------------------
  # PARAMETER AND OPTION GROUPS
  # -------------------------------------------------------------------------
  # Database engine configuration and feature options
  parameter_group_name = var.parameter_group_name
  option_group_name    = var.option_group_name

  # -------------------------------------------------------------------------
  # BACKUP CONFIGURATION
  # -------------------------------------------------------------------------
  # Automated backup retention, timing, and maintenance windows
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  # -------------------------------------------------------------------------
  # HIGH AVAILABILITY CONFIGURATION
  # -------------------------------------------------------------------------
  # Multi-AZ deployment and public access settings
  multi_az            = var.multi_az
  publicly_accessible = var.publicly_accessible

  # -------------------------------------------------------------------------
  # DELETION PROTECTION
  # -------------------------------------------------------------------------
  # Prevent accidental database deletion
  deletion_protection = var.deletion_protection

  # -------------------------------------------------------------------------
  # SNAPSHOT CONFIGURATION
  # -------------------------------------------------------------------------
  # Final snapshot behavior on instance deletion
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : var.final_snapshot_identifier

  # -------------------------------------------------------------------------
  # CLOUDWATCH LOGS CONFIGURATION
  # -------------------------------------------------------------------------
  # Export database logs to CloudWatch for monitoring
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  # -------------------------------------------------------------------------
  # PERFORMANCE INSIGHTS CONFIGURATION
  # -------------------------------------------------------------------------
  # Enhanced performance monitoring and analysis
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
  performance_insights_kms_key_id       = var.performance_insights_enabled ? var.performance_insights_kms_key_id : null

  # -------------------------------------------------------------------------
  # IAM DATABASE AUTHENTICATION
  # -------------------------------------------------------------------------
  # Enable IAM-based database access
  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  # -------------------------------------------------------------------------
  # VERSION MANAGEMENT
  # -------------------------------------------------------------------------
  # Automatic minor version upgrade behavior
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  # -------------------------------------------------------------------------
  # ENHANCED MONITORING CONFIGURATION
  # -------------------------------------------------------------------------
  # OS-level metrics collection via CloudWatch
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? var.monitoring_role_arn : null

  # -------------------------------------------------------------------------
  # SNAPSHOT TAG PROPAGATION
  # -------------------------------------------------------------------------
  # Automatically copy instance tags to automated backups
  copy_tags_to_snapshot = true

  tags = merge(
    var.tags,
    {
      Name = var.identifier
    }
  )

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [password]
  }
}
