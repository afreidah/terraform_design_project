# -----------------------------------------------------------------------------
# MSK MODULE - TEST SUITE
# -----------------------------------------------------------------------------
#
# This test suite validates the Amazon MSK cluster module functionality across
# various configuration scenarios. Tests use Terraform's native testing
# framework to verify cluster creation, broker configuration, encryption
# settings, monitoring levels, and logging options without requiring actual
# AWS infrastructure deployment.
#
# Test Categories:
#   - Baseline Configuration: CloudWatch enabled, S3 disabled
#   - CloudWatch Disabled: No log group creation
#   - S3 Logging: S3 log delivery configuration
#   - Encryption Variants: Different encryption modes and KMS keys
#   - Monitoring Levels: Enhanced monitoring granularity options
#   - Tagging: Tag merge and Name tag validation
#
# Testing Approach:
#   - Uses terraform plan to validate resource configuration
#   - Mock networking resources (subnets, security groups)
#   - Assertions verify expected behavior without AWS API calls
#   - Tests conditional CloudWatch log group creation
#
# IMPORTANT:
#   - Tests run in plan mode only (no actual infrastructure created)
#   - Mock subnet and security group IDs must be valid formats
#   - Broker count must be multiple of AZ count (3 subnets = 3 brokers)
#   - Bootstrap endpoints and Zookeeper strings are computed at apply time
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# TEST DEFAULTS / MOCKS
# -----------------------------------------------------------------------------

# Mock MSK cluster configuration for testing
# These values simulate production cluster creation without requiring real AWS resources
variables {
  cluster_name           = "test-msk"
  kafka_version          = "3.5.1"
  number_of_broker_nodes = 3

  broker_node_instance_type   = "kafka.t3.small"
  broker_node_ebs_volume_size = 100

  # Mock networking (3 AZs for HA)
  subnet_ids         = ["subnet-11111111", "subnet-22222222", "subnet-33333333"]
  security_group_ids = ["sg-12345678"]

  # Encryption defaults (secure by default)
  encryption_in_transit_client_broker = "TLS"
  encryption_in_transit_in_cluster    = true
  encryption_at_rest_kms_key_arn      = null

  # Monitoring default
  enhanced_monitoring = "PER_BROKER"

  # Logging defaults (CloudWatch enabled)
  cloudwatch_logs_enabled   = true
  cloudwatch_retention_days = 365
  cloudwatch_kms_key_id     = null

  s3_logs_enabled = false
  s3_logs_bucket  = null
  s3_logs_prefix  = null

  # Base tags
  tags = {
    Env  = "test"
    Team = "data"
  }
}

# -----------------------------------------------------------------------------
# BASELINE: CLOUDWATCH ENABLED, S3 DISABLED
# -----------------------------------------------------------------------------

# Validates complete MSK cluster creation with CloudWatch logging
# Expected Behavior:
#   - CloudWatch log group created and wired to cluster
#   - S3 logging disabled
#   - Cluster core configuration matches inputs
#   - Encryption and monitoring configured correctly
run "baseline_cloudwatch_enabled" {
  command = plan

  variables {
    # use defaults
  }

  # -------------------------------------------------------------------------
  # CLOUDWATCH LOG GROUP ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify log group is created when enabled
  assert {
    condition     = length(aws_cloudwatch_log_group.this) == 1
    error_message = "CloudWatch log group should be created when cloudwatch_logs_enabled=true"
  }

  # Verify log group name format
  assert {
    condition     = aws_cloudwatch_log_group.this["enabled"].name == "/aws/msk/${var.cluster_name}"
    error_message = "CloudWatch log group name should be /aws/msk/<cluster_name>"
  }

  # Verify log retention period
  assert {
    condition     = aws_cloudwatch_log_group.this["enabled"].retention_in_days == var.cloudwatch_retention_days
    error_message = "CloudWatch log retention should match input"
  }

  # Verify KMS key configuration
  assert {
    condition     = aws_cloudwatch_log_group.this["enabled"].kms_key_id == var.cloudwatch_kms_key_id
    error_message = "CloudWatch KMS key id should match input (can be null)"
  }

  # -------------------------------------------------------------------------
  # CLUSTER CORE CONFIGURATION ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify cluster name
  assert {
    condition     = aws_msk_cluster.this.cluster_name == var.cluster_name
    error_message = "Cluster name should match input"
  }

  # Verify Kafka version
  assert {
    condition     = aws_msk_cluster.this.kafka_version == var.kafka_version
    error_message = "Kafka version should match input"
  }

  # Verify broker count
  assert {
    condition     = aws_msk_cluster.this.number_of_broker_nodes == var.number_of_broker_nodes
    error_message = "Number of broker nodes should match input"
  }

  # -------------------------------------------------------------------------
  # BROKER NODE GROUP ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify broker instance type
  assert {
    condition     = aws_msk_cluster.this.broker_node_group_info[0].instance_type == var.broker_node_instance_type
    error_message = "Broker instance type should match input"
  }

  # Verify EBS volume size
  assert {
    condition     = aws_msk_cluster.this.broker_node_group_info[0].storage_info[0].ebs_storage_info[0].volume_size == var.broker_node_ebs_volume_size
    error_message = "Broker EBS volume size should match input"
  }

  # Verify subnet count
  assert {
    condition     = length(aws_msk_cluster.this.broker_node_group_info[0].client_subnets) == length(var.subnet_ids)
    error_message = "Broker client_subnets count should match input"
  }

  # Verify security group count
  assert {
    condition     = length(aws_msk_cluster.this.broker_node_group_info[0].security_groups) == length(var.security_group_ids)
    error_message = "Broker security_groups count should match input"
  }

  # -------------------------------------------------------------------------
  # ENCRYPTION ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify client-broker encryption
  assert {
    condition     = aws_msk_cluster.this.encryption_info[0].encryption_in_transit[0].client_broker == var.encryption_in_transit_client_broker
    error_message = "client_broker encryption should match input"
  }

  # Verify in-cluster encryption
  assert {
    condition     = aws_msk_cluster.this.encryption_info[0].encryption_in_transit[0].in_cluster == var.encryption_in_transit_in_cluster
    error_message = "in_cluster encryption should match input"
  }

  # Note: Do not assert encryption_at_rest_kms_key_arn when null; may be unknown at plan

  # -------------------------------------------------------------------------
  # MONITORING ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify enhanced monitoring level
  assert {
    condition     = aws_msk_cluster.this.enhanced_monitoring == var.enhanced_monitoring
    error_message = "Enhanced monitoring level should match input"
  }

  # -------------------------------------------------------------------------
  # LOGGING ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify CloudWatch logging enabled
  assert {
    condition     = aws_msk_cluster.this.logging_info[0].broker_logs[0].cloudwatch_logs[0].enabled == true
    error_message = "CloudWatch logging should be enabled"
  }

  # Verify CloudWatch log group wired correctly
  assert {
    condition     = aws_msk_cluster.this.logging_info[0].broker_logs[0].cloudwatch_logs[0].log_group == "/aws/msk/${var.cluster_name}"
    error_message = "CloudWatch log group should be wired to the cluster"
  }

  # Verify S3 logging disabled by default
  assert {
    condition     = aws_msk_cluster.this.logging_info[0].broker_logs[0].s3[0].enabled == false
    error_message = "S3 logging should be disabled by default"
  }

  # -------------------------------------------------------------------------
  # TAG ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify Name tag
  assert {
    condition     = aws_msk_cluster.this.tags["Name"] == var.cluster_name
    error_message = "Cluster Name tag should equal cluster_name"
  }

  # Verify custom tags
  assert {
    condition     = aws_msk_cluster.this.tags["Env"] == "test" && aws_msk_cluster.this.tags["Team"] == "data"
    error_message = "Cluster should carry Env and Team tags"
  }

  # -------------------------------------------------------------------------
  # OUTPUT ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify cluster_name output
  assert {
    condition     = output.cluster_name == var.cluster_name
    error_message = "cluster_name output should match input"
  }
}

# -----------------------------------------------------------------------------
# CLOUDWATCH DISABLED
# -----------------------------------------------------------------------------

# Validates cluster creation with CloudWatch logging disabled
# Expected Behavior:
#   - No CloudWatch log group resource created
#   - Cluster has CloudWatch logging disabled
#   - Log group reference is null
run "cloudwatch_disabled" {
  command = plan

  variables {
    cloudwatch_logs_enabled   = false
    cloudwatch_retention_days = 14
    cloudwatch_kms_key_id     = null
  }

  # -------------------------------------------------------------------------
  # LOG GROUP ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify no log group resource created
  assert {
    condition     = length(aws_cloudwatch_log_group.this) == 0
    error_message = "CloudWatch log group should not be created when disabled"
  }

  # -------------------------------------------------------------------------
  # CLUSTER LOGGING ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify CloudWatch logging disabled on cluster
  assert {
    condition     = aws_msk_cluster.this.logging_info[0].broker_logs[0].cloudwatch_logs[0].enabled == false
    error_message = "CloudWatch logging should be disabled on the cluster"
  }

  # Verify log group reference is null
  assert {
    condition     = aws_msk_cluster.this.logging_info[0].broker_logs[0].cloudwatch_logs[0].log_group == null
    error_message = "CloudWatch log group should be null when disabled"
  }
}

# -----------------------------------------------------------------------------
# S3 LOGGING ENABLED
# -----------------------------------------------------------------------------

# Validates cluster creation with S3 logging enabled
# Expected Behavior:
#   - S3 logging configured with bucket and prefix
#   - CloudWatch still enabled by default
run "s3_logging_enabled" {
  command = plan

  variables {
    s3_logs_enabled = true
    s3_logs_bucket  = "my-msk-logs"
    s3_logs_prefix  = "broker/"
  }

  # -------------------------------------------------------------------------
  # S3 LOGGING ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify S3 logging enabled
  assert {
    condition     = aws_msk_cluster.this.logging_info[0].broker_logs[0].s3[0].enabled == true
    error_message = "S3 logging should be enabled"
  }

  # Verify S3 bucket configured
  assert {
    condition     = aws_msk_cluster.this.logging_info[0].broker_logs[0].s3[0].bucket == "my-msk-logs"
    error_message = "S3 logs bucket should match input"
  }

  # Verify S3 prefix configured
  assert {
    condition     = aws_msk_cluster.this.logging_info[0].broker_logs[0].s3[0].prefix == "broker/"
    error_message = "S3 logs prefix should match input"
  }
}

# -----------------------------------------------------------------------------
# ENCRYPTION VARIANTS
# -----------------------------------------------------------------------------

# Validates different encryption configuration options
# Expected Behavior:
#   - Client-broker encryption mode configurable
#   - In-cluster encryption configurable
#   - KMS key for at-rest encryption configurable
run "encryption_variants" {
  command = plan

  variables {
    encryption_in_transit_client_broker = "TLS_PLAINTEXT"
    encryption_in_transit_in_cluster    = true
    encryption_at_rest_kms_key_arn      = "arn:aws:kms:us-east-1:123456789012:key/abcd1234-abcd-1234-abcd-1234abcd5678"
  }

  # -------------------------------------------------------------------------
  # ENCRYPTION ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify TLS_PLAINTEXT mode
  assert {
    condition     = aws_msk_cluster.this.encryption_info[0].encryption_in_transit[0].client_broker == "TLS_PLAINTEXT"
    error_message = "client_broker should reflect TLS_PLAINTEXT"
  }

  # Verify in-cluster encryption
  assert {
    condition     = aws_msk_cluster.this.encryption_info[0].encryption_in_transit[0].in_cluster == true
    error_message = "in_cluster should reflect configured value"
  }

  # Verify at-rest KMS key (plan-known when explicitly set)
  assert {
    condition     = aws_msk_cluster.this.encryption_info[0].encryption_at_rest_kms_key_arn == "arn:aws:kms:us-east-1:123456789012:key/abcd1234-abcd-1234-abcd-1234abcd5678"
    error_message = "encryption_at_rest KMS ARN should match input"
  }
}

# -----------------------------------------------------------------------------
# MONITORING LEVEL VARIANTS
# -----------------------------------------------------------------------------

# Validates different enhanced monitoring levels
# Expected Behavior:
#   - Enhanced monitoring level configurable
run "monitoring_level_variants" {
  command = plan

  variables {
    enhanced_monitoring = "PER_TOPIC_PER_PARTITION"
  }

  # -------------------------------------------------------------------------
  # MONITORING ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify monitoring level
  assert {
    condition     = aws_msk_cluster.this.enhanced_monitoring == "PER_TOPIC_PER_PARTITION"
    error_message = "Enhanced monitoring level should be PER_TOPIC_PER_PARTITION"
  }
}

# -----------------------------------------------------------------------------
# TAGS VERIFICATION
# -----------------------------------------------------------------------------

# Validates tag application and merge behavior
# Expected Behavior:
#   - Custom tags merged with Name tag
#   - Name tag equals cluster_name
run "tags_verification" {
  command = plan

  variables {
    cluster_name = "msk-tags"
    tags = {
      Env     = "test"
      Team    = "data"
      Purpose = "msk-tests"
    }
  }

  # -------------------------------------------------------------------------
  # TAG ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify Name tag
  assert {
    condition     = aws_msk_cluster.this.tags["Name"] == "msk-tags"
    error_message = "Name tag should equal cluster_name"
  }

  # Verify custom Purpose tag
  assert {
    condition     = aws_msk_cluster.this.tags["Purpose"] == "msk-tests"
    error_message = "Purpose tag should be present"
  }
}
