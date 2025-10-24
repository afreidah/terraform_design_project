# -----------------------------------------------------------------------------
# SSM PARAMETER STORE MODULE TEST SUITE
# -----------------------------------------------------------------------------
#
# Plan-safe assertions validating parameter creation, type configuration,
# tier selection, KMS key assignment, and tag propagation. Tests avoid
# equality checks against computed values like ARNs and versions.
#
# Test Coverage:
# Parameter count matching input map size. Per-parameter validation of name,
# type, tier, and KMS key assignment when provided. Tag merging with automatic
# Name tag assignment. Output map structure and content verification. Default
# value behavior for optional parameters. Mixed configurations with varying
# encryption requirements.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# TEST DEFAULTS AND MOCK VALUES
# -----------------------------------------------------------------------------

variables {
  # Baseline tags applied to all parameters
  tags = {
    Env  = "test"
    Team = "platform"
  }
}

# -----------------------------------------------------------------------------
# BASELINE CONFIGURATION TEST
# -----------------------------------------------------------------------------
# Validates three parameters with different types and tiers

run "baseline_three_params" {
  command = plan

  variables {
    parameters = {
      "/app/db/password" = {
        description = "DB password"
        type        = "SecureString"
        value       = "s3cr3t!"
        tier        = "Standard"
        key_id      = "arn:aws:kms:us-east-1:123456789012:key/abcd1234-abcd-1234-abcd-1234abcd5678"
      }
      "/app/api/url" = {
        description = "API URL"
        type        = "String"
        value       = "https://api.example.test"
        tier        = "Standard"
      }
      "/app/allowed_ips" = {
        description = "Comma-separated IPs"
        type        = "StringList"
        value       = "10.0.0.1,10.0.0.2"
        tier        = "Advanced"
      }
    }
  }

  # Parameter count matches input map size
  assert {
    condition     = length(aws_ssm_parameter.this) == length(var.parameters)
    error_message = "Should create one SSM parameter per map entry"
  }

  # Parameter names equal map keys
  assert {
    condition     = aws_ssm_parameter.this["/app/db/password"].name == "/app/db/password"
    error_message = "Parameter name must equal its map key (/app/db/password)"
  }
  assert {
    condition     = aws_ssm_parameter.this["/app/api/url"].name == "/app/api/url"
    error_message = "Parameter name must equal its map key (/app/api/url)"
  }
  assert {
    condition     = aws_ssm_parameter.this["/app/allowed_ips"].name == "/app/allowed_ips"
    error_message = "Parameter name must equal its map key (/app/allowed_ips)"
  }

  # Parameter types
  assert {
    condition     = aws_ssm_parameter.this["/app/db/password"].type == "SecureString"
    error_message = "DB password should be SecureString"
  }
  assert {
    condition     = aws_ssm_parameter.this["/app/api/url"].type == "String"
    error_message = "API URL should be String"
  }
  assert {
    condition     = aws_ssm_parameter.this["/app/allowed_ips"].type == "StringList"
    error_message = "Allowed IPs should be StringList"
  }

  # Parameter tiers
  assert {
    condition     = aws_ssm_parameter.this["/app/db/password"].tier == "Standard"
    error_message = "DB password tier should be Standard"
  }
  assert {
    condition     = aws_ssm_parameter.this["/app/api/url"].tier == "Standard"
    error_message = "API URL tier should be Standard"
  }
  assert {
    condition     = aws_ssm_parameter.this["/app/allowed_ips"].tier == "Advanced"
    error_message = "Allowed IPs tier should be Advanced"
  }

  # KMS key assignment for SecureString with explicit key
  assert {
    condition     = aws_ssm_parameter.this["/app/db/password"].key_id == "arn:aws:kms:us-east-1:123456789012:key/abcd1234-abcd-1234-abcd-1234abcd5678"
    error_message = "DB password key_id should match the provided KMS key ARN"
  }

  # Tag validation
  assert {
    condition     = aws_ssm_parameter.this["/app/db/password"].tags["Name"] == "/app/db/password"
    error_message = "Name tag should equal the parameter name for /app/db/password"
  }
  assert {
    condition     = aws_ssm_parameter.this["/app/api/url"].tags["Env"] == "test" && aws_ssm_parameter.this["/app/api/url"].tags["Team"] == "platform"
    error_message = "Baseline tags should be merged on /app/api/url"
  }

  # Output structure validation
  assert {
    condition     = length(output.parameter_names) == length(var.parameters)
    error_message = "parameter_names output should include all parameters"
  }
  assert {
    condition     = output.parameter_names["/app/api/url"] == "/app/api/url"
    error_message = "parameter_names map should echo the parameter name for /app/api/url"
  }
  assert {
    condition     = output.parameter_names["/app/db/password"] == "/app/db/password"
    error_message = "parameter_names map should echo the parameter name for /app/db/password"
  }
}

# -----------------------------------------------------------------------------
# MINIMAL INPUT WITH DEFAULTS TEST
# -----------------------------------------------------------------------------
# Validates default values for optional parameters

run "minimal_input_defaults" {
  command = plan

  variables {
    parameters = {
      "/app/min/defaults" = {
        value = "whatever"
      }
    }
    tags = {}
  }

  # Default type and tier
  assert {
    condition     = aws_ssm_parameter.this["/app/min/defaults"].type == "SecureString"
    error_message = "Default type should be SecureString"
  }
  assert {
    condition     = aws_ssm_parameter.this["/app/min/defaults"].tier == "Standard"
    error_message = "Default tier should be Standard"
  }

  # Name tag automatically set
  assert {
    condition     = aws_ssm_parameter.this["/app/min/defaults"].tags["Name"] == "/app/min/defaults"
    error_message = "Name tag should be set to parameter name even when tags are empty"
  }
}

# -----------------------------------------------------------------------------
# TAG MERGE TEST
# -----------------------------------------------------------------------------
# Validates custom tags merged with automatic Name tag

run "tag_merge" {
  command = plan

  variables {
    parameters = {
      "/app/tagged" = {
        value = "v"
        type  = "String"
      }
    }
    tags = {
      Env     = "stage"
      Service = "orders"
    }
  }

  assert {
    condition     = aws_ssm_parameter.this["/app/tagged"].tags["Env"] == "stage"
    error_message = "Env tag should be present"
  }
  assert {
    condition     = aws_ssm_parameter.this["/app/tagged"].tags["Service"] == "orders"
    error_message = "Service tag should be present"
  }
  assert {
    condition     = aws_ssm_parameter.this["/app/tagged"].tags["Name"] == "/app/tagged"
    error_message = "Name tag should equal the parameter name"
  }
}

# -----------------------------------------------------------------------------
# MIXED KMS KEY CONFIGURATION TEST
# -----------------------------------------------------------------------------
# Validates parameters with and without explicit KMS keys

run "mixed_key_ids" {
  command = plan

  variables {
    parameters = {
      "/secure/with-kms" = {
        value  = "x"
        type   = "SecureString"
        key_id = "alias/my-kms"
      }
      "/secure/default-kms" = {
        value = "y"
        type  = "SecureString"
      }
      "/plain/no-kms" = {
        value = "z"
        type  = "String"
      }
    }
  }

  # Explicit KMS key assignment
  assert {
    condition     = aws_ssm_parameter.this["/secure/with-kms"].key_id == "alias/my-kms"
    error_message = "Explicit key_id should be set on /secure/with-kms"
  }

  # Type validation for parameters without explicit KMS keys
  assert {
    condition     = aws_ssm_parameter.this["/secure/default-kms"].type == "SecureString"
    error_message = "/secure/default-kms must be SecureString"
  }
  assert {
    condition     = aws_ssm_parameter.this["/plain/no-kms"].type == "String"
    error_message = "/plain/no-kms must be String"
  }
}
