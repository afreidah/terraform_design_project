# ----------------------------------------------------------------
# KMS Module Test Suite
#
# Module under test:
#   - aws_kms_key.this
#   - aws_kms_alias.this
#
# Plan-safe assertions only (no equality against computed ARNs/IDs).
# Focus:
#   - Key description, rotation, deletion window, tags
#   - Optional alias creation and alias name shape
#   - Policy presence when provided
#   - Output shapes for alias values
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# Test Defaults / Mocks
# ----------------------------------------------------------------
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

# ----------------------------------------------------------------
# Basic key, no alias
# Expected: description/tags/rotation/deletion window match inputs
# ----------------------------------------------------------------
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

  # Assert core attributes
  assert {
    condition     = aws_kms_key.this.description == "Test KMS key (no alias)"
    error_message = "KMS key description should match input"
  }
  assert {
    condition     = aws_kms_key.this.enable_key_rotation == true
    error_message = "Key rotation should be enabled by default"
  }
  assert {
    condition     = aws_kms_key.this.deletion_window_in_days == 30
    error_message = "Deletion window should be 30 days by default"
  }

  # Tags applied
  assert {
    condition     = aws_kms_key.this.tags["Env"] == "test" && aws_kms_key.this.tags["Team"] == "security"
    error_message = "KMS key should carry Env and Team tags"
  }

  # No alias resources created
  assert {
    condition     = length(aws_kms_alias.this) == 0
    error_message = "Alias should not be created when alias_name is null"
  }

  # Outputs: alias outputs should be null when no alias
  assert {
    condition     = output.alias_name == null
    error_message = "alias_name output should be null when alias is not created"
  }
  assert {
    condition     = output.alias_arn == null
    error_message = "alias_arn output should be null when alias is not created"
  }
}

# ----------------------------------------------------------------
# Key with alias
# Expected: alias resource exists with expected name; outputs reflect name
# ----------------------------------------------------------------
run "key_with_alias" {
  command = plan

  variables {
    description             = "Key with alias"
    alias_name              = "app/config"
    enable_key_rotation     = true
    deletion_window_in_days = 30
    policy                  = null
  }

  # Exactly one alias
  assert {
    condition     = length(aws_kms_alias.this) == 1
    error_message = "Exactly one alias should be created when alias_name is set"
  }

  # Alias name shape is plan-known
  assert {
    condition     = aws_kms_alias.this[0].name == "alias/app/config"
    error_message = "Alias name should be prefixed with 'alias/'"
  }

  # Output mirrors alias name (plan-known)
  assert {
    condition     = output.alias_name == "alias/app/config"
    error_message = "alias_name output should equal created alias name"
  }
}

# ----------------------------------------------------------------
# Rotation disabled
# Expected: enable_key_rotation=false reflected on resource
# ----------------------------------------------------------------
run "rotation_disabled" {
  command = plan

  variables {
    description         = "Rotation disabled"
    enable_key_rotation = false
    policy              = null
  }

  assert {
    condition     = aws_kms_key.this.enable_key_rotation == false
    error_message = "Key rotation should be disabled when configured"
  }
}

# ----------------------------------------------------------------
# Custom deletion window
# Expected: deletion_window_in_days matches input
# ----------------------------------------------------------------
run "custom_deletion_window" {
  command = plan

  variables {
    description             = "Custom deletion window"
    deletion_window_in_days = 7
    policy                  = null
  }

  assert {
    condition     = aws_kms_key.this.deletion_window_in_days == 7
    error_message = "Deletion window should match configured value"
  }
}

# ----------------------------------------------------------------
# Explicit policy provided
# Expected: policy string is present and includes expected actions
# ----------------------------------------------------------------
run "explicit_policy" {
  command = plan

  variables {
    description = "Key with explicit policy"
    policy = jsonencode({
      Version   = "2012-10-17"
      Statement = [
        {
          Sid      = "AllowBasic"
          Effect   = "Allow"
          Principal = { AWS = "*" }
          Action   = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:DescribeKey"
          ]
          Resource = "*"
        }
      ]
    })
  }

  # Policy contains kms:Encrypt and kms:Decrypt (string check)
  assert {
    condition     = length(regexall("kms:Encrypt", aws_kms_key.this.policy)) > 0
    error_message = "Policy should include kms:Encrypt"
  }
  assert {
    condition     = length(regexall("kms:Decrypt", aws_kms_key.this.policy)) > 0
    error_message = "Policy should include kms:Decrypt"
  }
}

# ----------------------------------------------------------------
# Tags verification
# Expected: custom tags present
# ----------------------------------------------------------------
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

  assert {
    condition     = aws_kms_key.this.tags["Env"] == "test"
    error_message = "Env tag should be present"
  }
  assert {
    condition     = aws_kms_key.this.tags["Team"] == "security"
    error_message = "Team tag should be present"
  }
  assert {
    condition     = aws_kms_key.this.tags["Purpose"] == "kms-tests"
    error_message = "Purpose tag should be present"
  }
}

# ----------------------------------------------------------------
# Outputs shape checks (alias present vs absent)
# Expected: alias_name null when no alias; equals alias/NAME when set
# ----------------------------------------------------------------
run "outputs_shape_no_alias" {
  command = plan

  variables {
    description = "Outputs shape (no alias)"
    alias_name  = null
    policy      = null
  }

  assert {
    condition     = output.alias_name == null
    error_message = "alias_name output should be null when alias not created"
  }
  assert {
    condition     = output.alias_arn == null
    error_message = "alias_arn output should be null when alias not created"
  }
}

run "outputs_shape_with_alias" {
  command = plan

  variables {
    description = "Outputs shape (with alias)"
    alias_name  = "service/key"
    policy      = null
  }

  assert {
    condition     = output.alias_name == "alias/service/key"
    error_message = "alias_name output should equal 'alias/<alias_name>'"
  }
  # alias_arn is provider-computed; do not assert non-null at plan
}
