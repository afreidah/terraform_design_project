# ----------------------------------------------------------------
# MSK Module Test Suite
#
# Module under test:
#   - aws_msk_cluster.this
#   - aws_cloudwatch_log_group.this (conditional)
#
# Plan-safe assertions only (no equality against computed ARNs,
# bootstrap strings, or Zookeeper endpoints).
# Focus:
#   - Cluster shape: name, version, brokers, instance/storage, subnets/SGs
#   - Encryption (in-transit / at-rest)
#   - Logging (CloudWatch conditional, S3 optional)
#   - Enhanced monitoring
#   - Tags (merged Name)
#   - Output shapes that are plan-known (cluster_name)
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# Test Defaults / Mocks
# ----------------------------------------------------------------
variables {
  cluster_name           = "test-msk"
  kafka_version          = "3.5.1"
  number_of_broker_nodes = 3

  broker_node_instance_type   = "kafka.t3.small"
  broker_node_ebs_volume_size = 100

  # Mock networking
  subnet_ids         = ["subnet-11111111", "subnet-22222222", "subnet-33333333"]
  security_group_ids = ["sg-12345678"]

  # Encryption defaults
  encryption_in_transit_client_broker = "TLS"
  encryption_in_transit_in_cluster    = true
  encryption_at_rest_kms_key_arn      = null

  # Monitoring default
  enhanced_monitoring = "PER_BROKER"

  # Logging defaults
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

# ----------------------------------------------------------------
# Baseline: CloudWatch enabled, S3 disabled
# Expected: CW log group created and wired; S3 logging disabled;
#           core cluster shape matches inputs.
# ----------------------------------------------------------------
run "baseline_cloudwatch_enabled" {
  command = plan

  variables {
    # use defaults
  }

  # ----- CloudWatch Log Group (conditional resource) -----
  assert {
    condition     = length(aws_cloudwatch_log_group.this) == 1
    error_message = "CloudWatch log group should be created when cloudwatch_logs_enabled=true"
  }
  assert {
    condition     = aws_cloudwatch_log_group.this["enabled"].name == "/aws/msk/${var.cluster_name}"
    error_message = "CloudWatch log group name should be /aws/msk/<cluster_name>"
  }
  assert {
    condition     = aws_cloudwatch_log_group.this["enabled"].retention_in_days == var.cloudwatch_retention_days
    error_message = "CloudWatch log retention should match input"
  }
  assert {
    condition     = aws_cloudwatch_log_group.this["enabled"].kms_key_id == var.cloudwatch_kms_key_id
    error_message = "CloudWatch KMS key id should match input (can be null)"
  }

  # ----- MSK Cluster: core shape -----
  assert {
    condition     = aws_msk_cluster.this.cluster_name == var.cluster_name
    error_message = "Cluster name should match input"
  }
  assert {
    condition     = aws_msk_cluster.this.kafka_version == var.kafka_version
    error_message = "Kafka version should match input"
  }
  assert {
    condition     = aws_msk_cluster.this.number_of_broker_nodes == var.number_of_broker_nodes
    error_message = "Number of broker nodes should match input"
  }

  # Broker node group info
  assert {
    condition     = aws_msk_cluster.this.broker_node_group_info[0].instance_type == var.broker_node_instance_type
    error_message = "Broker instance type should match input"
  }
  assert {
    condition     = aws_msk_cluster.this.broker_node_group_info[0].storage_info[0].ebs_storage_info[0].volume_size == var.broker_node_ebs_volume_size
    error_message = "Broker EBS volume size should match input"
  }
  assert {
    condition     = length(aws_msk_cluster.this.broker_node_group_info[0].client_subnets) == length(var.subnet_ids)
    error_message = "Broker client_subnets count should match input"
  }
  assert {
    condition     = length(aws_msk_cluster.this.broker_node_group_info[0].security_groups) == length(var.security_group_ids)
    error_message = "Broker security_groups count should match input"
  }

  # Encryption in transit
  assert {
    condition     = aws_msk_cluster.this.encryption_info[0].encryption_in_transit[0].client_broker == var.encryption_in_transit_client_broker
    error_message = "client_broker encryption should match input"
  }
  assert {
    condition     = aws_msk_cluster.this.encryption_info[0].encryption_in_transit[0].in_cluster == var.encryption_in_transit_in_cluster
    error_message = "in_cluster encryption should match input"
  }
  # NOTE: Do NOT assert encryption_at_rest_kms_key_arn here when null; it may be unknown at plan.

  # Enhanced monitoring
  assert {
    condition     = aws_msk_cluster.this.enhanced_monitoring == var.enhanced_monitoring
    error_message = "Enhanced monitoring level should match input"
  }

  # Logging: CloudWatch enabled, S3 disabled
  assert {
    condition     = aws_msk_cluster.this.logging_info[0].broker_logs[0].cloudwatch_logs[0].enabled == true
    error_message = "CloudWatch logging should be enabled"
  }
  assert {
    condition     = aws_msk_cluster.this.logging_info[0].broker_logs[0].cloudwatch_logs[0].log_group == "/aws/msk/${var.cluster_name}"
    error_message = "CloudWatch log group should be wired to the cluster"
  }
  assert {
    condition     = aws_msk_cluster.this.logging_info[0].broker_logs[0].s3[0].enabled == false
    error_message = "S3 logging should be disabled by default"
  }

  # Tags: merged Name tag
  assert {
    condition     = aws_msk_cluster.this.tags["Name"] == var.cluster_name
    error_message = "Cluster Name tag should equal cluster_name"
  }
  assert {
    condition     = aws_msk_cluster.this.tags["Env"] == "test" && aws_msk_cluster.this.tags["Team"] == "data"
    error_message = "Cluster should carry Env and Team tags"
  }

  # Output: cluster_name is plan-known (argument passthrough)
  assert {
    condition     = output.cluster_name == var.cluster_name
    error_message = "cluster_name output should match input"
  }
}

# ----------------------------------------------------------------
# CloudWatch disabled
# Expected: No log group resource; cluster has CW disabled & null log_group
# ----------------------------------------------------------------
run "cloudwatch_disabled" {
  command = plan

  variables {
    cloudwatch_logs_enabled   = false
    cloudwatch_retention_days = 14
    cloudwatch_kms_key_id     = null
  }

  # No CW log group resource
  assert {
    condition     = length(aws_cloudwatch_log_group.this) == 0
    error_message = "CloudWatch log group should not be created when disabled"
  }

  # Cluster logging reflects disabled CW
  assert {
    condition     = aws_msk_cluster.this.logging_info[0].broker_logs[0].cloudwatch_logs[0].enabled == false
    error_message = "CloudWatch logging should be disabled on the cluster"
  }
  assert {
    condition     = aws_msk_cluster.this.logging_info[0].broker_logs[0].cloudwatch_logs[0].log_group == null
    error_message = "CloudWatch log group should be null when disabled"
  }
}

# ----------------------------------------------------------------
# S3 logging enabled
# Expected: S3 logging block enabled with bucket/prefix; CW still enabled by default
# ----------------------------------------------------------------
run "s3_logging_enabled" {
  command = plan

  variables {
    s3_logs_enabled = true
    s3_logs_bucket  = "my-msk-logs"
    s3_logs_prefix  = "broker/"
  }

  assert {
    condition     = aws_msk_cluster.this.logging_info[0].broker_logs[0].s3[0].enabled == true
    error_message = "S3 logging should be enabled"
  }
  assert {
    condition     = aws_msk_cluster.this.logging_info[0].broker_logs[0].s3[0].bucket == "my-msk-logs"
    error_message = "S3 logs bucket should match input"
  }
  assert {
    condition     = aws_msk_cluster.this.logging_info[0].broker_logs[0].s3[0].prefix == "broker/"
    error_message = "S3 logs prefix should match input"
  }
}

# ----------------------------------------------------------------
# Encryption variants
# Expected: in-transit and at-rest fields reflect inputs
# ----------------------------------------------------------------
run "encryption_variants" {
  command = plan

  variables {
    encryption_in_transit_client_broker = "TLS_PLAINTEXT"
    encryption_in_transit_in_cluster    = true
    encryption_at_rest_kms_key_arn      = "arn:aws:kms:us-east-1:123456789012:key/abcd1234-abcd-1234-abcd-1234abcd5678"
  }

  assert {
    condition     = aws_msk_cluster.this.encryption_info[0].encryption_in_transit[0].client_broker == "TLS_PLAINTEXT"
    error_message = "client_broker should reflect TLS_PLAINTEXT"
  }
  assert {
    condition     = aws_msk_cluster.this.encryption_info[0].encryption_in_transit[0].in_cluster == true
    error_message = "in_cluster should reflect configured value"
  }
  # With explicit KMS ARN (non-null), value is plan-known
  assert {
    condition     = aws_msk_cluster.this.encryption_info[0].encryption_at_rest_kms_key_arn == "arn:aws:kms:us-east-1:123456789012:key/abcd1234-abcd-1234-abcd-1234abcd5678"
    error_message = "encryption_at_rest KMS ARN should match input"
  }
}

# ----------------------------------------------------------------
# Monitoring level variants
# Expected: enhanced_monitoring reflects input
# ----------------------------------------------------------------
run "monitoring_level_variants" {
  command = plan

  variables {
    enhanced_monitoring = "PER_TOPIC_PER_PARTITION"
  }

  assert {
    condition     = aws_msk_cluster.this.enhanced_monitoring == "PER_TOPIC_PER_PARTITION"
    error_message = "Enhanced monitoring level should be PER_TOPIC_PER_PARTITION"
  }
}

# ----------------------------------------------------------------
# Tags verification
# Expected: custom tags merged and Name tag equals cluster_name
# ----------------------------------------------------------------
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

  assert {
    condition     = aws_msk_cluster.this.tags["Name"] == "msk-tags"
    error_message = "Name tag should equal cluster_name"
  }
  assert {
    condition     = aws_msk_cluster.this.tags["Purpose"] == "msk-tests"
    error_message = "Purpose tag should be present"
  }
}
