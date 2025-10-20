# ----------------------------------------------------------------
# OpenSearch Module Test Suite
#
# Module under test:
#   - aws_opensearch_domain.this
#   - aws_cloudwatch_log_group.index_slow_logs
#   - aws_cloudwatch_log_group.search_slow_logs
#   - aws_cloudwatch_log_group.es_application_logs
#   - aws_cloudwatch_log_group.audit_logs (conditional)
#   - aws_cloudwatch_log_resource_policy.this
#
# Plan-safe assertions only (no equality against computed ARNs/IDs,
# endpoints, or dashboard URLs).
# Focus:
#   - Domain core shape (name, version, cluster config, EBS)
#   - Encryption (at-rest / node-to-node)
#   - Endpoint options (HTTPS, TLS policy)
#   - VPC options (subnets/SGs counts)
#   - Logging (CloudWatch groups created & named; audit optional)
#   - Zone awareness config (when enabled)
#   - Advanced security options (enabled/disabled)
#   - Tags
#   - Output values that are plan-known (domain_name and CWG names)
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# Test Defaults / Mocks
# ----------------------------------------------------------------
variables {
  domain_name    = "test-opensearch"
  engine_version = "OpenSearch_2.11"

  # Cluster config
  instance_type  = "t3.medium.search"
  instance_count = 3

  dedicated_master_enabled = true
  dedicated_master_type    = "t3.small.search"
  dedicated_master_count   = 3

  zone_awareness_enabled   = true
  availability_zone_count  = 3

  # EBS (gp3 -> iops/throughput are used)
  ebs_enabled  = true
  volume_type  = "gp3"
  volume_size  = 100
  iops         = 3000
  throughput   = 125

  # Encryption
  encrypt_at_rest_enabled         = true
  kms_key_id                      = null
  node_to_node_encryption_enabled = true

  # Endpoint options
  domain_endpoint_options = {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  # Advanced security (disabled by default in baseline; object is required)
  advanced_security_options = {
    enabled                        = false
    internal_user_database_enabled = false
    master_user_name               = "unused"
    master_user_password           = "unused"
  }

  # Networking
  subnet_ids         = ["subnet-11111111", "subnet-22222222", "subnet-33333333"]
  security_group_ids = ["sg-12345678"]

  # Snapshots
  automated_snapshot_start_hour = 3

  # CloudWatch logging
  cloudwatch_kms_key_id     = null
  cloudwatch_retention_days = 365
  enable_audit_logs         = true

  # Tags
  tags = {
    Env  = "test"
    Team = "search"
  }
}

# ----------------------------------------------------------------
# Baseline: zone awareness enabled, gp3 EBS, HTTPS enforced, audit logs enabled
# ----------------------------------------------------------------
run "baseline_defaults" {
  command = plan

  variables {
    # use defaults
  }

  # ----- Domain: core shape -----
  assert {
    condition     = aws_opensearch_domain.this.domain_name == var.domain_name
    error_message = "Domain name should match input"
  }
  assert {
    condition     = aws_opensearch_domain.this.engine_version == var.engine_version
    error_message = "Engine version should match input"
  }

  # Cluster config
  assert {
    condition     = aws_opensearch_domain.this.cluster_config[0].instance_type == var.instance_type
    error_message = "Instance type should match input"
  }
  assert {
    condition     = aws_opensearch_domain.this.cluster_config[0].instance_count == var.instance_count
    error_message = "Instance count should match input"
  }
  assert {
    condition     = aws_opensearch_domain.this.cluster_config[0].dedicated_master_enabled == var.dedicated_master_enabled
    error_message = "Dedicated master should reflect input"
  }
  assert {
    condition     = aws_opensearch_domain.this.cluster_config[0].dedicated_master_type == var.dedicated_master_type
    error_message = "Dedicated master type should match input"
  }
  assert {
    condition     = aws_opensearch_domain.this.cluster_config[0].dedicated_master_count == var.dedicated_master_count
    error_message = "Dedicated master count should match input"
  }

  # Zone awareness
  assert {
    condition     = aws_opensearch_domain.this.cluster_config[0].zone_awareness_enabled == true
    error_message = "Zone awareness should be enabled"
  }
  assert {
    condition     = aws_opensearch_domain.this.cluster_config[0].zone_awareness_config[0].availability_zone_count == var.availability_zone_count
    error_message = "AZ count should match input"
  }

  # EBS options (gp3)
  assert {
    condition     = aws_opensearch_domain.this.ebs_options[0].ebs_enabled == var.ebs_enabled
    error_message = "EBS should reflect input"
  }
  assert {
    condition     = aws_opensearch_domain.this.ebs_options[0].volume_type == "gp3"
    error_message = "Volume type should be gp3"
  }
  assert {
    condition     = aws_opensearch_domain.this.ebs_options[0].volume_size == var.volume_size
    error_message = "Volume size should match input"
  }
  assert {
    condition     = aws_opensearch_domain.this.ebs_options[0].iops == var.iops
    error_message = "IOPS should match input for gp3"
  }
  assert {
    condition     = aws_opensearch_domain.this.ebs_options[0].throughput == var.throughput
    error_message = "Throughput should match input for gp3"
  }

  # Encryption
  assert {
    condition     = aws_opensearch_domain.this.encrypt_at_rest[0].enabled == var.encrypt_at_rest_enabled
    error_message = "Encrypt at rest should reflect input"
  }
  assert {
    condition     = aws_opensearch_domain.this.node_to_node_encryption[0].enabled == var.node_to_node_encryption_enabled
    error_message = "Node-to-node encryption should reflect input"
  }

  # Endpoint options
  assert {
    condition     = aws_opensearch_domain.this.domain_endpoint_options[0].enforce_https == true
    error_message = "enforce_https should be true"
  }
  assert {
    condition     = aws_opensearch_domain.this.domain_endpoint_options[0].tls_security_policy == "Policy-Min-TLS-1-2-2019-07"
    error_message = "TLS security policy should match input"
  }

  # VPC options (counts only)
  assert {
    condition     = length(aws_opensearch_domain.this.vpc_options[0].subnet_ids) == length(var.subnet_ids)
    error_message = "Subnet IDs count should match input"
  }
  assert {
    condition     = length(aws_opensearch_domain.this.vpc_options[0].security_group_ids) == length(var.security_group_ids)
    error_message = "Security group IDs count should match input"
  }

  # CloudWatch log groups (always created for 3 types)
  assert {
    condition     = aws_cloudwatch_log_group.index_slow_logs.name == "/aws/opensearch/${var.domain_name}/index-slow-logs"
    error_message = "Index slow logs group name should match expected format"
  }
  assert {
    condition     = aws_cloudwatch_log_group.search_slow_logs.name == "/aws/opensearch/${var.domain_name}/search-slow-logs"
    error_message = "Search slow logs group name should match expected format"
  }
  assert {
    condition     = aws_cloudwatch_log_group.es_application_logs.name == "/aws/opensearch/${var.domain_name}/application-logs"
    error_message = "Application logs group name should match expected format"
  }

  # Audit logs enabled -> audit log group exists
  assert {
    condition     = length(aws_cloudwatch_log_group.audit_logs) == 1
    error_message = "Audit logs group should be created when enable_audit_logs=true"
  }
  assert {
    condition     = aws_cloudwatch_log_group.audit_logs["enabled"].name == "/aws/opensearch/${var.domain_name}/audit-logs"
    error_message = "Audit logs group name should match expected format"
  }

  # Tags on domain
  assert {
    condition     = aws_opensearch_domain.this.tags["Env"] == "test" && aws_opensearch_domain.this.tags["Team"] == "search"
    error_message = "Domain should carry Env and Team tags"
  }

  # Outputs (plan-known only)
  assert {
    condition     = output.domain_name == var.domain_name
    error_message = "domain_name output should match input"
  }
  assert {
    condition     = output.index_slow_logs_log_group_name == "/aws/opensearch/${var.domain_name}/index-slow-logs"
    error_message = "index_slow_logs_log_group_name should match"
  }
  assert {
    condition     = output.search_slow_logs_log_group_name == "/aws/opensearch/${var.domain_name}/search-slow-logs"
    error_message = "search_slow_logs_log_group_name should match"
  }
  assert {
    condition     = output.application_logs_log_group_name == "/aws/opensearch/${var.domain_name}/application-logs"
    error_message = "application_logs_log_group_name should match"
  }
  assert {
    condition     = output.audit_logs_log_group_name == "/aws/opensearch/${var.domain_name}/audit-logs"
    error_message = "audit_logs_log_group_name should match when enabled"
  }
}

# ----------------------------------------------------------------
# Audit logs disabled
# Expected: no audit log group; output null
# ----------------------------------------------------------------
run "audit_logs_disabled" {
  command = plan

  variables {
    enable_audit_logs = false
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.audit_logs) == 0
    error_message = "Audit logs group should not be created when disabled"
  }
  assert {
    condition     = output.audit_logs_log_group_name == null
    error_message = "audit_logs_log_group_name output should be null when disabled"
  }
}

# ----------------------------------------------------------------
# Non-gp3 volumes (e.g., gp2)
# Plan-safe: assert volume_type only; provider may set iops/throughput at plan.
# ----------------------------------------------------------------
run "non_gp3_volume" {
  command = plan

  variables {
    volume_type = "gp2"
  }

  assert {
    condition     = aws_opensearch_domain.this.ebs_options[0].volume_type == "gp2"
    error_message = "Volume type should be gp2"
  }
}

# ----------------------------------------------------------------
# Advanced security enabled (internal user DB)
# ----------------------------------------------------------------
run "advanced_security_enabled" {
  command = plan

  variables {
    advanced_security_options = {
      enabled                        = true
      internal_user_database_enabled = true
      master_user_name               = "adminuser"
      master_user_password           = "S3cureP@ssw0rd!"
    }
  }

  assert {
    condition     = aws_opensearch_domain.this.advanced_security_options[0].enabled == true
    error_message = "Advanced security should be enabled"
  }
  assert {
    condition     = aws_opensearch_domain.this.advanced_security_options[0].internal_user_database_enabled == true
    error_message = "Internal user database should be enabled"
  }
  # Do not assert on master_user_* values (sensitive)
}

# ----------------------------------------------------------------
# Endpoint options variant
# ----------------------------------------------------------------
run "endpoint_options_variant" {
  command = plan

  variables {
    domain_endpoint_options = {
      enforce_https       = true
      tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
    }
  }

  assert {
    condition     = aws_opensearch_domain.this.domain_endpoint_options[0].enforce_https == true
    error_message = "enforce_https should be true"
  }
  assert {
    condition     = aws_opensearch_domain.this.domain_endpoint_options[0].tls_security_policy == "Policy-Min-TLS-1-2-2019-07"
    error_message = "TLS policy should match"
  }
}

# ----------------------------------------------------------------
# Zone awareness disabled (no zone_awareness_config block)
# ----------------------------------------------------------------
run "zone_awareness_disabled" {
  command = plan

  variables {
    zone_awareness_enabled  = false
    availability_zone_count = 2
  }

  assert {
    condition     = aws_opensearch_domain.this.cluster_config[0].zone_awareness_enabled == false
    error_message = "Zone awareness should be disabled"
  }
  # When disabled, there is no zone_awareness_config block — avoid indexing it
}

# ----------------------------------------------------------------
# Tags verification on log groups
# ----------------------------------------------------------------
run "log_group_tags" {
  command = plan

  variables {
    tags = {
      Env     = "test"
      Team    = "search"
      Purpose = "os-tests"
    }
  }

  assert {
    condition     = aws_cloudwatch_log_group.index_slow_logs.tags["Purpose"] == "os-tests"
    error_message = "Index slow logs CWG should carry Purpose tag"
  }
  assert {
    condition     = aws_cloudwatch_log_group.search_slow_logs.tags["Purpose"] == "os-tests"
    error_message = "Search slow logs CWG should carry Purpose tag"
  }
  assert {
    condition     = aws_cloudwatch_log_group.es_application_logs.tags["Purpose"] == "os-tests"
    error_message = "Application logs CWG should carry Purpose tag"
  }
}
