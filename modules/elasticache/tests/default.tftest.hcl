# ----------------------------------------------------------------
# Elasticache (Redis) Module Test Suite
#
# Tests the Elasticache module for security defaults (encryption,
# auth token), multi-AZ configuration, backup settings, conditional
# logic, and high availability features.
# ----------------------------------------------------------------

# Global variables - defaults for all tests
variables {
  # Required module variables
  cluster_id         = "test-redis"
  subnet_ids         = ["subnet-11111111", "subnet-22222222", "subnet-33333333"]
  security_group_ids = ["sg-redis12345"]

  # Test helper variables
  test_kms_key_id    = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  test_sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:redis-notifications"
}

# ----------------------------------------------------------------
# Security defaults are enforced
# Expected: Encryption at rest, in transit, and auth token enabled
# ----------------------------------------------------------------
run "security_defaults" {
  command = plan

  # Assert encryption at rest is enabled by default
  assert {
    condition     = tobool(aws_elasticache_replication_group.this.at_rest_encryption_enabled) == true
    error_message = "Encryption at rest must be enabled by default"
  }

  # Assert encryption in transit is enabled by default
  assert {
    condition     = aws_elasticache_replication_group.this.transit_encryption_enabled == true
    error_message = "Encryption in transit must be enabled by default"
  }

  # Assert automatic failover is enabled by default
  assert {
    condition     = aws_elasticache_replication_group.this.automatic_failover_enabled == true
    error_message = "Automatic failover should be enabled by default"
  }

  # Assert Multi-AZ is enabled by default
  assert {
    condition     = aws_elasticache_replication_group.this.multi_az_enabled == true
    error_message = "Multi-AZ should be enabled by default for high availability"
  }
}

# ----------------------------------------------------------------
# Auth token configuration
# Expected: Auth token used when enabled, null when disabled
# ----------------------------------------------------------------
run "auth_token_enabled" {
  command = plan

  variables {
    auth_token_enabled = true
    auth_token         = "my-super-secret-auth-token-min-16-chars"
  }

  # Assert auth token is set when enabled
  assert {
    condition     = aws_elasticache_replication_group.this.auth_token != null
    error_message = "Auth token should be set when auth_token_enabled is true"
  }
}

run "auth_token_disabled" {
  command = plan

  variables {
    auth_token_enabled = false
    auth_token         = null
  }

  # Assert auth token is null when disabled
  assert {
    condition     = aws_elasticache_replication_group.this.auth_token == null
    error_message = "Auth token should be null when auth_token_enabled is false"
  }
}

# ----------------------------------------------------------------
# KMS encryption configuration
# Expected: Custom KMS key used when provided
# ----------------------------------------------------------------
run "custom_kms_encryption" {
  command = plan

  variables {
    kms_key_id = var.test_kms_key_id
  }

  # Assert custom KMS key is used
  assert {
    condition     = aws_elasticache_replication_group.this.kms_key_id == var.test_kms_key_id
    error_message = "Should use provided KMS key for encryption at rest"
  }
}

# ----------------------------------------------------------------
# Subnet group configuration
# Expected: Subnet group created with all provided subnets
# ----------------------------------------------------------------
run "subnet_group_creation" {
  command = plan

  # Assert subnet group is created
  assert {
    condition     = aws_elasticache_subnet_group.this.name == "test-redis-subnet-group"
    error_message = "Subnet group should follow naming convention"
  }

  # Assert all subnets are included
  assert {
    condition     = length(aws_elasticache_subnet_group.this.subnet_ids) == 3
    error_message = "Subnet group should include all provided subnets"
  }
}

# ----------------------------------------------------------------
# Parameter group configuration
# Expected: Parameter group created with correct family
# ----------------------------------------------------------------
run "parameter_group_creation" {
  command = plan

  variables {
    parameter_group_family = "redis7"
  }

  # Assert parameter group is created
  assert {
    condition     = aws_elasticache_parameter_group.this.name == "test-redis-params"
    error_message = "Parameter group should follow naming convention"
  }

  # Assert correct family is used
  assert {
    condition     = aws_elasticache_parameter_group.this.family == "redis7"
    error_message = "Parameter group should use specified family"
  }
}

# ----------------------------------------------------------------
# Multi-AZ configuration
# Expected: Redis deployed across multiple availability zones
# ----------------------------------------------------------------
run "multi_az_deployment" {
  command = plan

  variables {
    num_cache_nodes  = 3
    multi_az_enabled = true
  }

  # Assert Multi-AZ is enabled
  assert {
    condition     = aws_elasticache_replication_group.this.multi_az_enabled == true
    error_message = "Multi-AZ should be enabled"
  }

  # Assert correct number of nodes
  assert {
    condition     = aws_elasticache_replication_group.this.num_cache_clusters == 3
    error_message = "Should create 3 cache nodes for high availability"
  }

  # Assert automatic failover is enabled (required for Multi-AZ)
  assert {
    condition     = aws_elasticache_replication_group.this.automatic_failover_enabled == true
    error_message = "Automatic failover required for Multi-AZ deployment"
  }
}

# ----------------------------------------------------------------
# Backup and snapshot configuration
# Expected: Automated backups configured correctly
# ----------------------------------------------------------------
run "backup_configuration" {
  command = plan

  variables {
    snapshot_retention_limit = 14
    snapshot_window          = "02:00-04:00"
  }

  # Assert snapshot retention is set
  assert {
    condition     = aws_elasticache_replication_group.this.snapshot_retention_limit == 14
    error_message = "Snapshot retention should be configurable"
  }

  # Assert snapshot window is set
  assert {
    condition     = aws_elasticache_replication_group.this.snapshot_window == "02:00-04:00"
    error_message = "Snapshot window should be configurable"
  }
}

# ----------------------------------------------------------------
# Maintenance window configuration
# Expected: Maintenance window set correctly
# ----------------------------------------------------------------
run "maintenance_window" {
  command = plan

  variables {
    maintenance_window = "mon:03:00-mon:05:00"
  }

  # Assert maintenance window is set
  assert {
    condition     = aws_elasticache_replication_group.this.maintenance_window == "mon:03:00-mon:05:00"
    error_message = "Maintenance window should be configurable"
  }
}

# ----------------------------------------------------------------
# Engine version configuration
# Expected: Correct Redis engine version used
# ----------------------------------------------------------------
run "redis_version" {
  command = plan

  variables {
    engine         = "redis"
    engine_version = "7.0"
  }

  # Assert engine is Redis
  assert {
    condition     = aws_elasticache_replication_group.this.engine == "redis"
    error_message = "Engine should be Redis"
  }

  # Assert correct version is used
  assert {
    condition     = aws_elasticache_replication_group.this.engine_version == "7.0"
    error_message = "Should use specified Redis version"
  }
}

# ----------------------------------------------------------------
# Node type configuration
# Expected: Instance type is configurable
# ----------------------------------------------------------------
run "node_type_configuration" {
  command = plan

  variables {
    node_type = "cache.r6g.large"
  }

  # Assert correct node type is used
  assert {
    condition     = aws_elasticache_replication_group.this.node_type == "cache.r6g.large"
    error_message = "Node type should be configurable"
  }
}

# ----------------------------------------------------------------
# Port configuration
# Expected: Custom port can be specified
# ----------------------------------------------------------------
run "custom_port" {
  command = plan

  variables {
    port = 6380
  }

  # Assert custom port is used
  assert {
    condition     = aws_elasticache_replication_group.this.port == 6380
    error_message = "Port should be configurable"
  }
}

# ----------------------------------------------------------------
# SNS notification configuration
# Expected: SNS topic ARN set when provided
# ----------------------------------------------------------------
run "sns_notifications" {
  command = plan

  variables {
    notification_topic_arn = var.test_sns_topic_arn
  }

  # Assert SNS topic is configured
  assert {
    condition     = aws_elasticache_replication_group.this.notification_topic_arn == var.test_sns_topic_arn
    error_message = "SNS notification topic should be configurable"
  }
}

# ----------------------------------------------------------------
# Auto minor version upgrade
# Expected: Auto upgrade enabled by default
# ----------------------------------------------------------------
run "auto_minor_version_upgrade" {
  command = plan

  # Assert auto minor version upgrade is enabled
  assert {
    condition     = tobool(aws_elasticache_replication_group.this.auto_minor_version_upgrade) == true
    error_message = "Auto minor version upgrade should be enabled by default"
  }
}

# ----------------------------------------------------------------
# Replication group ID and naming
# Expected: Resources follow predictable naming pattern
# ----------------------------------------------------------------
run "naming_conventions" {
  command = plan

  variables {
    cluster_id = "prod-cache"
  }

  # Assert replication group ID matches cluster_id
  assert {
    condition     = aws_elasticache_replication_group.this.replication_group_id == "prod-cache"
    error_message = "Replication group ID should match cluster_id"
  }

  # Assert subnet group naming
  assert {
    condition     = aws_elasticache_subnet_group.this.name == "prod-cache-subnet-group"
    error_message = "Subnet group should follow {cluster_id}-subnet-group pattern"
  }

  # Assert parameter group naming
  assert {
    condition     = aws_elasticache_parameter_group.this.name == "prod-cache-params"
    error_message = "Parameter group should follow {cluster_id}-params pattern"
  }
}

# ----------------------------------------------------------------
# Minimum nodes for automatic failover
# Expected: Automatic failover requires at least 2 nodes
# ----------------------------------------------------------------
run "failover_requires_multiple_nodes" {
  command = plan

  variables {
    num_cache_nodes            = 2
    automatic_failover_enabled = true
  }

  # Assert at least 2 nodes for failover
  assert {
    condition     = aws_elasticache_replication_group.this.num_cache_clusters >= 2
    error_message = "Automatic failover requires at least 2 cache nodes"
  }

  # Assert failover is enabled
  assert {
    condition     = aws_elasticache_replication_group.this.automatic_failover_enabled == true
    error_message = "Automatic failover should be enabled"
  }
}

# ----------------------------------------------------------------
# Apply immediately configuration
# Expected: Apply immediately is false by default (safer for production)
# ----------------------------------------------------------------
run "apply_immediately_default" {
  command = plan

  # Assert apply immediately is false (changes during maintenance window)
  assert {
    condition     = aws_elasticache_replication_group.this.apply_immediately == false
    error_message = "apply_immediately should be false to avoid production disruptions"
  }
}

# ----------------------------------------------------------------
# Security group association
# Expected: Replication group uses provided security groups
# ----------------------------------------------------------------
run "security_group_association" {
  command = plan

  variables {
    security_group_ids = ["sg-redis12345", "sg-additional123"]
  }

  # Assert security groups are associated
  assert {
    condition     = length(aws_elasticache_replication_group.this.security_group_ids) == 2
    error_message = "Should associate all provided security groups"
  }

  # Assert specific security group is included
  assert {
    condition     = contains(aws_elasticache_replication_group.this.security_group_ids, "sg-redis12345")
    error_message = "Should include primary security group"
  }
}
