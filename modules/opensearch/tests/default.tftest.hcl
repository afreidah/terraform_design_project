# -----------------------------------------------------------------------------
# OPENSEARCH MODULE TEST SUITE
# -----------------------------------------------------------------------------
#
# Plan-safe assertions validating domain configuration, encryption settings,
# VPC options, logging setup, and conditional resource creation. Tests avoid
# equality checks against computed values like ARNs, endpoints, or IDs.
#
# Test Coverage:
# Domain core configuration including name, version, cluster sizing, and EBS
# storage settings. Encryption validation for both at-rest and node-to-node
# encryption. HTTPS enforcement and TLS policy verification. VPC subnet and
# security group attachment. CloudWatch log group creation and naming. Zone
# awareness configuration when enabled. Advanced security options for fine-
# grained access control. Tag propagation to all resources. Output values that
# are known at plan time.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# TEST DEFAULTS AND MOCK VALUES
# -----------------------------------------------------------------------------

variables {
  domain_name    = "test-opensearch"
  engine_version = "OpenSearch_2.11"

  # Cluster configuration
  instance_type  = "t3.medium.search"
  instance_count = 3

  dedicated_master_enabled = true
  dedicated_master_type    = "t3.small.search"
  dedicated_master_count   = 3

  zone_awareness_enabled  = true
  availability_zone_count = 3

  # EBS storage with gp3 performance settings
  ebs_enabled = true
  volume_type = "gp3"
  volume_size = 100
  iops        = 3000
  throughput  = 125

  # Encryption settings
  encrypt_at_rest_enabled         = true
  kms_key_id                      = null
  node_to_node_encryption_enabled = true

  # Domain endpoint security
  domain_endpoint_options = {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  # Advanced security disabled by default
  advanced_security_options = {
    enabled                        = false
    internal_user_database_enabled = false
    master_user_name               = ""
    master_user_password           = ""
  }

  # Network configuration
  subnet_ids         = ["subnet-12345678", "subnet-23456789", "subnet-34567890"]
  security_group_ids = ["sg-12345678"]

  # Snapshot timing
  automated_snapshot_start_hour = 3

  # Logging configuration
  enable_audit_logs           = true
  cloudwatch_retention_days   = 7
  cloudwatch_kms_key_id       = null

  # Resource tagging
  tags = {
    Env  = "test"
    Team = "search"
  }
}

# Mock providers for testing
mock_provider "aws" {}

# -----------------------------------------------------------------------------
# BASELINE CONFIGURATION TEST
# -----------------------------------------------------------------------------
# Validates default configuration with all standard features enabled

run "baseline_config" {
  command = plan

  # Domain basic attributes
  assert {
    condition     = aws_opensearch_domain.this.domain_name == var.domain_name
    error_message = "Domain name should match input"
  }
  assert {
    condition     = aws_opensearch_domain.this.engine_version == var.engine_version
    error_message = "Engine version should match input"
  }

  # Cluster configuration
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
    error_message = "Dedicated master should be enabled"
  }
  assert {
    condition     = aws_opensearch_domain.this.cluster_config[0].dedicated_master_type == var.dedicated_master_type
    error_message = "Master type should match input"
  }
  assert {
    condition     = aws_opensearch_domain.this.cluster_config[0].dedicated_master_count == var.dedicated_master_count
    error_message = "Master count should match input"
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

  # EBS options for gp3 volumes
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

  # VPC options count validation
  assert {
    condition     = length(aws_opensearch_domain.this.vpc_options[0].subnet_ids) == length(var.subnet_ids)
    error_message = "Subnet IDs count should match input"
  }
  assert {
    condition     = length(aws_opensearch_domain.this.vpc_options[0].security_group_ids) == length(var.security_group_ids)
    error_message = "Security group IDs count should match input"
  }

  # CloudWatch log groups always created for three standard log types
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

  # Audit logs created when enabled
  assert {
    condition     = length(aws_cloudwatch_log_group.audit_logs) == 1
    error_message = "Audit logs group should be created when enable_audit_logs=true"
  }
  assert {
    condition     = aws_cloudwatch_log_group.audit_logs["enabled"].name == "/aws/opensearch/${var.domain_name}/audit-logs"
    error_message = "Audit logs group name should match expected format"
  }

  # Tag propagation to domain
  assert {
    condition     = aws_opensearch_domain.this.tags["Env"] == "test" && aws_opensearch_domain.this.tags["Team"] == "search"
    error_message = "Domain should carry Env and Team tags"
  }

  # Plan-known output validation
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

# -----------------------------------------------------------------------------
# AUDIT LOGS DISABLED TEST
# -----------------------------------------------------------------------------
# Validates conditional audit log group creation

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

# -----------------------------------------------------------------------------
# NON-GP3 VOLUME TYPE TEST
# -----------------------------------------------------------------------------
# Validates EBS configuration with gp2 volume type

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

# -----------------------------------------------------------------------------
# ADVANCED SECURITY ENABLED TEST
# -----------------------------------------------------------------------------
# Validates fine-grained access control with internal user database

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
}

# -----------------------------------------------------------------------------
# ENDPOINT OPTIONS VARIANT TEST
# -----------------------------------------------------------------------------
# Validates HTTPS and TLS policy configuration

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

# -----------------------------------------------------------------------------
# ZONE AWARENESS DISABLED TEST
# -----------------------------------------------------------------------------
# Validates single-AZ deployment configuration

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
}

# -----------------------------------------------------------------------------
# LOG GROUP TAGS TEST
# -----------------------------------------------------------------------------
# Validates tag propagation to CloudWatch log groups

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
