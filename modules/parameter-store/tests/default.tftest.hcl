# ----------------------------------------------------------------
# SSM Parameter Store Module Test Suite
#
# Module under test:
#   - aws_ssm_parameter.this (for_each over var.parameters)
#
# Plan-safe assertions only (avoid computed ARNs/versions).
# Focus:
#   - Resource count matches input map size
#   - Per-parameter shape: name, type, tier, key_id (when provided)
#   - Tags merged and Name tag equals parameter name
#   - Outputs: parameter_names map shape and contents
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# Test Defaults / Mocks
# ----------------------------------------------------------------
variables {
  # Baseline tags applied to all params (can be overridden per run)
  tags = {
    Env  = "test"
    Team = "platform"
  }
}

# ----------------------------------------------------------------
# Baseline: three parameters (SecureString with key_id, String, StringList Advanced)
# ----------------------------------------------------------------
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
    # tags inherited from defaults
  }

  # Count matches
  assert {
    condition     = length(aws_ssm_parameter.this) == length(var.parameters)
    error_message = "Should create one SSM parameter per map entry"
  }

  # Names equal keys
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

  # Types
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

  # Tiers
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

  # key_id only for the SecureString with explicit KMS
  assert {
    condition     = aws_ssm_parameter.this["/app/db/password"].key_id == "arn:aws:kms:us-east-1:123456789012:key/abcd1234-abcd-1234-abcd-1234abcd5678"
    error_message = "DB password key_id should match the provided KMS key ARN"
  }

  # Tags present and Name tag equals key
  assert {
    condition     = aws_ssm_parameter.this["/app/db/password"].tags["Name"] == "/app/db/password"
    error_message = "Name tag should equal the parameter name for /app/db/password"
  }
  assert {
    condition     = aws_ssm_parameter.this["/app/api/url"].tags["Env"] == "test" && aws_ssm_parameter.this["/app/api/url"].tags["Team"] == "platform"
    error_message = "Baseline tags should be merged on /app/api/url"
  }

  # Outputs: parameter_names shape and sample entries
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

# ----------------------------------------------------------------
# Minimal input: rely on defaults (type SecureString, tier Standard), no tags
# ----------------------------------------------------------------
run "minimal_input_defaults" {
  command = plan

  variables {
    parameters = {
      "/app/min/defaults" = {
        value = "whatever"
      }
    }
    tags = {} # override to empty to ensure only Name is present
  }

  # Type and tier default
  assert {
    condition     = aws_ssm_parameter.this["/app/min/defaults"].type == "SecureString"
    error_message = "Default type should be SecureString"
  }
  assert {
    condition     = aws_ssm_parameter.this["/app/min/defaults"].tier == "Standard"
    error_message = "Default tier should be Standard"
  }

  # Name tag still set via merge with Name
  assert {
    condition     = aws_ssm_parameter.this["/app/min/defaults"].tags["Name"] == "/app/min/defaults"
    error_message = "Name tag should be set to parameter name even when tags are empty"
  }
}

# ----------------------------------------------------------------
# Tag merge: custom tags appear alongside Name
# ----------------------------------------------------------------
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

# ----------------------------------------------------------------
# Mixed: some with key_id, some without (ensure only equality where provided)
# ----------------------------------------------------------------
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

  # Provided key_id is respected
  assert {
    condition     = aws_ssm_parameter.this["/secure/with-kms"].key_id == "alias/my-kms"
    error_message = "Explicit key_id should be set on /secure/with-kms"
  }

  # Do not assert key_id for others (defaulting behavior differs by provider); instead, assert types
  assert {
    condition     = aws_ssm_parameter.this["/secure/default-kms"].type == "SecureString"
    error_message = "/secure/default-kms must be SecureString"
  }
  assert {
    condition     = aws_ssm_parameter.this["/plain/no-kms"].type == "String"
    error_message = "/plain/no-kms must be String"
  }
}
