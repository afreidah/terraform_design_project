# -----------------------------------------------------------------------------
# RDS MODULE TEST SUITE
# -----------------------------------------------------------------------------
#
# Plan-safe assertions validating subnet group configuration, instance
# settings, storage encryption, backup configuration, and optional features.
# Tests avoid equality checks against computed values like endpoints, ARNs,
# and availability zones.
#
# Test Coverage:
# Subnet group creation and naming. Instance engine, class, and storage
# configuration. Encryption settings with optional KMS keys. Network
# placement with security groups and public accessibility. Backup retention,
# maintenance windows, and snapshot behavior. Multi-AZ deployment options.
# Performance Insights and enhanced monitoring conditionals. CloudWatch log
# exports. IAM database authentication. Tag propagation to all resources.
# Output values known at plan time.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# TEST DEFAULTS AND MOCK VALUES
# -----------------------------------------------------------------------------

variables {
  identifier     = "test-rds"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = null

  db_name  = "appdb"
  username = "appuser"
  password = "super-secret"

  port = 5432

  vpc_security_group_ids     = ["sg-12345678"]
  db_subnet_group_subnet_ids = ["subnet-11111111", "subnet-22222222"]

  parameter_group_name = null
  option_group_name    = null

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  multi_az            = false
  publicly_accessible = false

  deletion_protection = true

  skip_final_snapshot       = false
  final_snapshot_identifier = "test-rds-final"

  enabled_cloudwatch_logs_exports = ["postgresql"]

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  performance_insights_kms_key_id       = null

  iam_database_authentication_enabled = true
  auto_minor_version_upgrade          = false

  monitoring_interval = 0
  monitoring_role_arn = null

  tags = {
    Env  = "test"
    Team = "data"
  }
}

# -----------------------------------------------------------------------------
# BASELINE CONFIGURATION TEST
# -----------------------------------------------------------------------------
# Validates default configuration with standard features enabled

run "baseline" {
  command = plan

  variables {
    # Use defaults above
  }

  # Subnet group configuration
  assert {
    condition     = aws_db_subnet_group.this.name == "${var.identifier}-subnet-group"
    error_message = "DB subnet group name should be <identifier>-subnet-group"
  }
  assert {
    condition     = length(aws_db_subnet_group.this.subnet_ids) == length(var.db_subnet_group_subnet_ids)
    error_message = "DB subnet group should include all provided subnets"
  }
  assert {
    condition     = aws_db_subnet_group.this.tags["Name"] == "${var.identifier}-subnet-group"
    error_message = "Subnet group Name tag should match"
  }

  # Instance basic configuration
  assert {
    condition     = aws_db_instance.this.identifier == var.identifier
    error_message = "Instance identifier should match input"
  }
  assert {
    condition     = aws_db_instance.this.engine == var.engine && aws_db_instance.this.engine_version == var.engine_version
    error_message = "Engine and version should match inputs"
  }
  assert {
    condition     = aws_db_instance.this.instance_class == var.instance_class
    error_message = "Instance class should match input"
  }

  # Storage configuration
  assert {
    condition     = aws_db_instance.this.allocated_storage == var.allocated_storage
    error_message = "Allocated storage should match input"
  }
  assert {
    condition     = aws_db_instance.this.max_allocated_storage == var.max_allocated_storage
    error_message = "Max allocated storage should match input"
  }
  assert {
    condition     = aws_db_instance.this.storage_type == var.storage_type
    error_message = "Storage type should match input"
  }
  assert {
    condition     = aws_db_instance.this.storage_encrypted == var.storage_encrypted
    error_message = "Storage encryption flag should match input"
  }

  # Database and authentication
  assert {
    condition     = aws_db_instance.this.db_name == var.db_name && aws_db_instance.this.username == var.username
    error_message = "DB name and username should match inputs"
  }
  assert {
    condition     = aws_db_instance.this.port == var.port
    error_message = "Port should match input"
  }
  assert {
    condition     = aws_db_instance.this.iam_database_authentication_enabled == var.iam_database_authentication_enabled
    error_message = "IAM DB auth flag should match input"
  }

  # Network configuration
  assert {
    condition     = length(aws_db_instance.this.vpc_security_group_ids) == length(var.vpc_security_group_ids)
    error_message = "RDS should attach all provided security groups"
  }
  assert {
    condition     = aws_db_instance.this.db_subnet_group_name == aws_db_subnet_group.this.name
    error_message = "Instance must reference created subnet group"
  }
  assert {
    condition     = aws_db_instance.this.publicly_accessible == var.publicly_accessible
    error_message = "Public accessibility flag should match input"
  }
  assert {
    condition     = aws_db_instance.this.multi_az == var.multi_az
    error_message = "multi_az flag should match input"
  }

  # Backup and maintenance
  assert {
    condition     = aws_db_instance.this.backup_retention_period == var.backup_retention_period
    error_message = "Backup retention should match input"
  }
  assert {
    condition     = aws_db_instance.this.backup_window == var.backup_window
    error_message = "Backup window should match input"
  }
  assert {
    condition     = aws_db_instance.this.maintenance_window == var.maintenance_window
    error_message = "Maintenance window should match input"
  }

  # Deletion protection and snapshots
  assert {
    condition     = aws_db_instance.this.deletion_protection == true
    error_message = "Deletion protection should default to true"
  }
  assert {
    condition     = aws_db_instance.this.skip_final_snapshot == false
    error_message = "skip_final_snapshot should be false in baseline"
  }
  assert {
    condition     = aws_db_instance.this.final_snapshot_identifier == var.final_snapshot_identifier
    error_message = "final_snapshot_identifier should match when skip_final_snapshot=false"
  }

  # CloudWatch logs and version upgrades
  assert {
    condition     = length(setsubtract(toset(aws_db_instance.this.enabled_cloudwatch_logs_exports), toset(var.enabled_cloudwatch_logs_exports))) == 0 && length(setsubtract(toset(var.enabled_cloudwatch_logs_exports), toset(aws_db_instance.this.enabled_cloudwatch_logs_exports))) == 0
    error_message = "Enabled CloudWatch logs exports should match input"
  }
  assert {
    condition     = aws_db_instance.this.auto_minor_version_upgrade == var.auto_minor_version_upgrade
    error_message = "Auto minor version upgrade flag should match input"
  }

  # Performance Insights
  assert {
    condition     = aws_db_instance.this.performance_insights_enabled == true
    error_message = "Performance Insights should be enabled by default in baseline"
  }
  assert {
    condition     = aws_db_instance.this.performance_insights_retention_period == var.performance_insights_retention_period
    error_message = "PI retention period should match input"
  }

  # Enhanced monitoring disabled in baseline
  assert {
    condition     = aws_db_instance.this.monitoring_interval == 0
    error_message = "Monitoring interval should be 0 (disabled) in baseline"
  }

  # Tag validation
  assert {
    condition     = aws_db_instance.this.tags["Name"] == var.identifier
    error_message = "Instance Name tag should equal identifier"
  }
  assert {
    condition     = aws_db_instance.this.tags["Env"] == "test" && aws_db_instance.this.tags["Team"] == "data"
    error_message = "Instance should carry Env and Team tags"
  }

  # Plan-known outputs
  assert {
    condition     = output.port == var.port
    error_message = "Output port should match input"
  }
  assert {
    condition     = output.db_subnet_group_name == "${var.identifier}-subnet-group"
    error_message = "Output db_subnet_group_name should match created subnet group"
  }
}

# -----------------------------------------------------------------------------
# SKIP FINAL SNAPSHOT TEST
# -----------------------------------------------------------------------------
# Validates snapshot behavior when skipping final snapshot

run "skip_final_snapshot_true" {
  command = plan

  variables {
    skip_final_snapshot       = true
    final_snapshot_identifier = "ignored-if-skip"
  }

  assert {
    condition     = aws_db_instance.this.skip_final_snapshot == true
    error_message = "skip_final_snapshot should be true"
  }
  assert {
    condition     = aws_db_instance.this.final_snapshot_identifier == null
    error_message = "final_snapshot_identifier must be null when skipping final snapshot"
  }
}

# -----------------------------------------------------------------------------
# PERFORMANCE INSIGHTS DISABLED TEST
# -----------------------------------------------------------------------------
# Validates Performance Insights can be disabled

run "performance_insights_disabled" {
  command = plan

  variables {
    performance_insights_enabled          = false
    performance_insights_retention_period = 7
    performance_insights_kms_key_id       = "arn:aws:kms:us-east-1:123456789012:key/pi-abc"
  }

  assert {
    condition     = aws_db_instance.this.performance_insights_enabled == false
    error_message = "PI should be disabled"
  }
}

# -----------------------------------------------------------------------------
# PERFORMANCE INSIGHTS WITH KMS TEST
# -----------------------------------------------------------------------------
# Validates Performance Insights with custom KMS key

run "performance_insights_with_kms" {
  command = plan

  variables {
    performance_insights_enabled          = true
    performance_insights_retention_period = 731
    performance_insights_kms_key_id       = "arn:aws:kms:us-east-1:123456789012:key/pi-abc"
  }

  assert {
    condition     = aws_db_instance.this.performance_insights_enabled == true
    error_message = "PI should be enabled"
  }
  assert {
    condition     = aws_db_instance.this.performance_insights_retention_period == 731
    error_message = "PI retention period should be 731 days when configured"
  }
  assert {
    condition     = aws_db_instance.this.performance_insights_kms_key_id == "arn:aws:kms:us-east-1:123456789012:key/pi-abc"
    error_message = "PI KMS key should match input"
  }
}

# -----------------------------------------------------------------------------
# ENHANCED MONITORING ENABLED TEST
# -----------------------------------------------------------------------------
# Validates enhanced monitoring with IAM role

run "enhanced_monitoring_enabled" {
  command = plan

  variables {
    monitoring_interval = 60
    monitoring_role_arn = "arn:aws:iam::123456789012:role/rds-monitoring"
  }

  assert {
    condition     = aws_db_instance.this.monitoring_interval == 60
    error_message = "Monitoring interval should be 60 seconds"
  }
  assert {
    condition     = aws_db_instance.this.monitoring_role_arn == "arn:aws:iam::123456789012:role/rds-monitoring"
    error_message = "Monitoring role ARN should match input when monitoring is enabled"
  }
}

# -----------------------------------------------------------------------------
# MULTI-AZ AND KMS ENCRYPTION TEST
# -----------------------------------------------------------------------------
# Validates high availability and custom KMS encryption

run "ha_and_kms" {
  command = plan

  variables {
    multi_az   = true
    kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/rds-enc"
  }

  assert {
    condition     = aws_db_instance.this.multi_az == true
    error_message = "multi_az should be true when configured"
  }
  assert {
    condition     = aws_db_instance.this.storage_encrypted == true
    error_message = "storage_encrypted should remain true"
  }
  assert {
    condition     = aws_db_instance.this.kms_key_id == "arn:aws:kms:us-east-1:123456789012:key/rds-enc"
    error_message = "KMS key id should match input"
  }
}

# -----------------------------------------------------------------------------
# PUBLIC ACCESSIBILITY TEST
# -----------------------------------------------------------------------------
# Validates publicly accessible configuration

run "publicly_accessible_variant" {
  command = plan

  variables {
    publicly_accessible = true
  }

  assert {
    condition     = aws_db_instance.this.publicly_accessible == true
    error_message = "Instance should be publicly accessible when configured"
  }
}

# -----------------------------------------------------------------------------
# PARAMETER AND OPTION GROUPS TEST
# -----------------------------------------------------------------------------
# Validates custom parameter and option group assignment

run "param_and_option_groups" {
  command = plan

  variables {
    parameter_group_name = "custom-pg"
    option_group_name    = "custom-og"
  }

  assert {
    condition     = aws_db_instance.this.parameter_group_name == "custom-pg"
    error_message = "Parameter group name should match input"
  }
  assert {
    condition     = aws_db_instance.this.option_group_name == "custom-og"
    error_message = "Option group name should match input"
  }
}
