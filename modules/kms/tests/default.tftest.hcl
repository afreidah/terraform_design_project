# -----------------------------------------------------------------------------
# KMS KEY MODULE - TEST SUITE
# -----------------------------------------------------------------------------
#
# This test suite validates the KMS key module functionality across various
# configuration scenarios. Tests use Terraform's native testing framework to
# verify key creation, rotation settings, deletion protection, policy
# configuration, and conditional alias creation without requiring actual AWS
# infrastructure deployment.
#
# Test Categories:
#   - Basic Key: Key creation without alias
#   - Key with Alias: Conditional alias creation and naming
#   - Rotation Settings: Key rotation enabled/disabled
#   - Deletion Protection: Custom deletion window configuration
#   - Key Policy: Explicit policy validation
#   - Tagging: Tag merge validation
#   - Outputs: Output shape validation with and without alias
#
# Testing Approach:
#   - Uses terraform plan to validate resource configuration
#   - Mock descriptions, policies, and alias names
#   - Assertions verify expected behavior without AWS API calls
#   - Tests conditional resource creation (alias)
#
# IMPORTANT:
#   - Tests run in plan mode only (no actual infrastructure created)
#   - Key policies validated via regex pattern matching
#   - Alias outputs are null when alias_name not provided
#   - Deletion window must be between 7 and 30 days
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# TEST DEFAULTS / MOCKS
# -----------------------------------------------------------------------------

# Mock KMS key configuration for testing
# These values simulate production key creation without requiring real AWS resources
variables {
  # Common description
  description = "Test KMS key"

  # Defaults align to module defaults
  deletion_window_in_days = 30
  enable_key_rotation     = true

  # No alias by default; specific runs set a value
  alias_name = null

  # Baseline tags
  tags = {
    Env  = "test"
    Team = "security"
  }
}

# -----------------------------------------------------------------------------
# BASIC KEY WITHOUT ALIAS
# -----------------------------------------------------------------------------

# Validates basic KMS key creation without alias
# Expected Behavior:
#   - Key created with description, rotation, deletion window
#   - Tags applied correctly
#   - No alias resource created
#   - Alias outputs are null
run "basic_key_no_alias" {
  command = plan

  variables {
    description             = "Test KMS key (no alias)"
    alias_name              = null
    enable_key_rotation     = true
    deletion_window_in_days = 30
    policy                  = null
    tags = {
      Env  = "test"
      Team = "security"
    }
  }

  # -------------------------------------------------------------------------
  # KEY CORE ATTRIBUTES ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify key description matches input
  assert {
    condition     = aws_kms_key.this.description == "Test KMS key (no alias)"
    error_message = "KMS key description should match input"
  }

  # Verify key rotation is enabled
  assert {
    condition     = aws_kms_key.this.enable_key_rotation == true
    error_message = "Key rotation should be enabled by default"
  }

  # Verify deletion window is 30 days
  assert {
    condition     = aws_kms_key.this.deletion_window_in_days == 30
    error_message = "Deletion window should be 30 days by default"
  }

  # -------------------------------------------------------------------------
  # TAG ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify tags are applied correctly
  assert {
    condition     = aws_kms_key.this.tags["Env"] == "test" && aws_kms_key.this.tags["Team"] == "security"
    error_message = "KMS key should carry Env and Team tags"
  }

  # -------------------------------------------------------------------------
  # ALIAS ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify no alias resources created
  assert {
    condition     = length(aws_kms_alias.this) == 0
    error_message = "Alias should not be created when alias_name is null"
  }

  # -------------------------------------------------------------------------
  # OUTPUT ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify alias name output is null
  assert {
    condition     = output.alias_name == null
    error_message = "alias_name output should be null when alias is not created"
  }

  # Verify alias ARN output is null
  assert {
    condition     = output.alias_arn == null
    error_message = "alias_arn output should be null when alias is not created"
  }
}

# -----------------------------------------------------------------------------
# KEY WITH ALIAS
# -----------------------------------------------------------------------------

# Validates KMS key creation with alias
# Expected Behavior:
#   - Key created successfully
#   - Alias resource created with correct name format
#   - Alias name output matches created alias
run "key_with_alias" {
  command = plan

  variables {
    description             = "Key with alias"
    alias_name              = "app/config"
    enable_key_rotation     = true
    deletion_window_in_days = 30
    policy                  = null
  }

  # -------------------------------------------------------------------------
  # ALIAS CREATION ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify exactly one alias is created
  assert {
    condition     = length(aws_kms_alias.this) == 1
    error_message = "Exactly one alias should be created when alias_name is set"
  }

  # -------------------------------------------------------------------------
  # ALIAS NAME FORMAT ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify alias name has correct prefix
  assert {
    condition     = aws_kms_alias.this[0].name == "alias/app/config"
    error_message = "Alias name should be prefixed with 'alias/'"
  }

  # -------------------------------------------------------------------------
  # OUTPUT ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify output mirrors alias name
  assert {
    condition     = output.alias_name == "alias/app/config"
    error_message = "alias_name output should equal created alias name"
  }
}

# -----------------------------------------------------------------------------
# ROTATION DISABLED
# -----------------------------------------------------------------------------

# Validates key rotation can be disabled
# Expected Behavior:
#   - Key created with rotation disabled
run "rotation_disabled" {
  command = plan

  variables {
    description         = "Rotation disabled"
    enable_key_rotation = false
    policy              = null
  }

  # -------------------------------------------------------------------------
  # ROTATION ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify rotation is disabled
  assert {
    condition     = aws_kms_key.this.enable_key_rotation == false
    error_message = "Key rotation should be disabled when configured"
  }
}

# -----------------------------------------------------------------------------
# CUSTOM DELETION WINDOW
# -----------------------------------------------------------------------------

# Validates custom deletion window configuration
# Expected Behavior:
#   - Key created with custom deletion window
run "custom_deletion_window" {
  command = plan

  variables {
    description             = "Custom deletion window"
    deletion_window_in_days = 7
    policy                  = null
  }

  # -------------------------------------------------------------------------
  # DELETION WINDOW ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify deletion window matches input
  assert {
    condition     = aws_kms_key.this.deletion_window_in_days == 7
    error_message = "Deletion window should match configured value"
  }
}

# -----------------------------------------------------------------------------
# EXPLICIT KEY POLICY
# -----------------------------------------------------------------------------

# Validates custom key policy configuration
# Expected Behavior:
#   - Key created with explicit policy
#   - Policy contains expected KMS actions
run "explicit_policy" {
  command = plan

  variables {
    description = "Key with explicit policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid       = "AllowBasic"
          Effect    = "Allow"
          Principal = { AWS = "*" }
          Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:DescribeKey"
          ]
          Resource = "*"
        }
      ]
    })
  }

  # -------------------------------------------------------------------------
  # POLICY CONTENT ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify policy contains kms:Encrypt action
  assert {
    condition     = length(regexall("kms:Encrypt", aws_kms_key.this.policy)) > 0
    error_message = "Policy should include kms:Encrypt"
  }

  # Verify policy contains kms:Decrypt action
  assert {
    condition     = length(regexall("kms:Decrypt", aws_kms_key.this.policy)) > 0
    error_message = "Policy should include kms:Decrypt"
  }
}

# -----------------------------------------------------------------------------
# TAGS VERIFICATION
# -----------------------------------------------------------------------------

# Validates tag application to KMS key
# Expected Behavior:
#   - All custom tags present on key
run "tags_verification" {
  command = plan

  variables {
    description = "Tagged key"
    tags = {
      Env     = "test"
      Team    = "security"
      Purpose = "kms-tests"
    }
    policy = null
  }

  # -------------------------------------------------------------------------
  # TAG ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify Env tag present
  assert {
    condition     = aws_kms_key.this.tags["Env"] == "test"
    error_message = "Env tag should be present"
  }

  # Verify Team tag present
  assert {
    condition     = aws_kms_key.this.tags["Team"] == "security"
    error_message = "Team tag should be present"
  }

  # Verify custom Purpose tag present
  assert {
    condition     = aws_kms_key.this.tags["Purpose"] == "kms-tests"
    error_message = "Purpose tag should be present"
  }
}

# -----------------------------------------------------------------------------
# OUTPUTS SHAPE (NO ALIAS)
# -----------------------------------------------------------------------------

# Validates output behavior when alias is not created
# Expected Behavior:
#   - Alias outputs are null
run "outputs_shape_no_alias" {
  command = plan

  variables {
    description = "Outputs shape (no alias)"
    alias_name  = null
    policy      = null
  }

  # -------------------------------------------------------------------------
  # OUTPUT ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify alias name output is null
  assert {
    condition     = output.alias_name == null
    error_message = "alias_name output should be null when alias not created"
  }

  # Verify alias ARN output is null
  assert {
    condition     = output.alias_arn == null
    error_message = "alias_arn output should be null when alias not created"
  }
}

# -----------------------------------------------------------------------------
# OUTPUTS SHAPE (WITH ALIAS)
# -----------------------------------------------------------------------------

# Validates output behavior when alias is created
# Expected Behavior:
#   - Alias name output matches created alias
run "outputs_shape_with_alias" {
  command = plan

  variables {
    description = "Outputs shape (with alias)"
    alias_name  = "service/key"
    policy      = null
  }

  # -------------------------------------------------------------------------
  # OUTPUT ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify alias name output matches expected format
  assert {
    condition     = output.alias_name == "alias/service/key"
    error_message = "alias_name output should equal 'alias/<alias_name>'"
  }

  # Note: alias_arn is provider-computed and cannot be asserted at plan time
}
