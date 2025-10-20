# ----------------------------------------------------------------
# IAM Role Module Test Suite
#
# Module under test:
#   - aws_iam_role.this
#   - aws_iam_role_policy_attachment.this
#   - aws_iam_instance_profile.this
#
# Asserts plan-safe invariants only (no equality against ARNs/IDs).
# Focus areas:
#   - Role name/tags and trust policy contents
#   - Managed policy attachment count
#   - Conditional instance profile creation
#   - Output shapes where plan-known (e.g., null when not created)
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# Shared Test Defaults / Mocks
# ----------------------------------------------------------------
variables {
  # Base role name for tests (overridden per run)
  name = "test-iam-role"

  # Minimal EC2 trust policy (string JSON)
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })

  # No managed policies by default
  policy_arns = []

  # Do not create instance profile by default
  create_instance_profile = false

  # Baseline tags
  tags = {
    Env  = "test"
    Team = "platform"
  }
}

# ----------------------------------------------------------------
# Basic role with EC2 trust; no attachments; no instance profile
# Expected: name/tags, trust policy contains sts:AssumeRole + EC2,
#           zero attachments, no instance profile, outputs (nulls where applicable)
# ----------------------------------------------------------------
run "basic_ec2_role" {
  command = plan

  variables {
    name                  = "role-basic-ec2"
    create_instance_profile = false
    policy_arns           = []
    # assume_role_policy inherited from defaults (EC2 principal)
  }

  # ----- Role core shape -----
  assert {
    condition     = aws_iam_role.this.name == "role-basic-ec2"
    error_message = "Role name should match input"
  }

  # ----- Trust policy contents (string JSON) -----
  assert {
    condition     = length(regexall("sts:AssumeRole", aws_iam_role.this.assume_role_policy)) > 0
    error_message = "Trust policy must include sts:AssumeRole"
  }
  assert {
    condition     = length(regexall("ec2\\.amazonaws\\.com", aws_iam_role.this.assume_role_policy)) > 0
    error_message = "Trust policy must include ec2.amazonaws.com service principal"
  }

  # ----- Tags (merged with Name) -----
  assert {
    condition     = aws_iam_role.this.tags["Env"] == "test" && aws_iam_role.this.tags["Team"] == "platform"
    error_message = "Role should carry Env and Team tags"
  }
  assert {
    condition     = aws_iam_role.this.tags["Name"] == "role-basic-ec2"
    error_message = "Role Name tag should equal role name"
  }

  # ----- Managed policy attachments -----
  assert {
    condition     = length(aws_iam_role_policy_attachment.this) == 0
    error_message = "No managed policy attachments expected"
  }

  # ----- Instance profile not created -----
  assert {
    condition     = length(aws_iam_instance_profile.this) == 0
    error_message = "Instance profile should not be created when create_instance_profile=false"
  }

  # ----- Outputs (plan-known only) -----
  assert {
    condition     = output.role_name == "role-basic-ec2"
    error_message = "role_name output should match input"
  }
  # When instance profile not created, outputs must be null
  assert {
    condition     = output.instance_profile_name == null
    error_message = "instance_profile_name should be null when create_instance_profile=false"
  }
  assert {
    condition     = output.instance_profile_arn == null
    error_message = "instance_profile_arn should be null when create_instance_profile=false"
  }
}

# ----------------------------------------------------------------
# Role with multiple managed policies
# Expected: attachment count equals provided ARNs length
# ----------------------------------------------------------------
run "with_managed_policies" {
  command = plan

  variables {
    name = "role-with-managed"
    policy_arns = [
      "arn:aws:iam::aws:policy/ReadOnlyAccess",
      "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
    ]
  }

  assert {
    condition     = aws_iam_role.this.name == "role-with-managed"
    error_message = "Role name should match input"
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.this) == length(var.policy_arns)
    error_message = "Managed policy attachment count should match input length"
  }
}

# ----------------------------------------------------------------
# Role with instance profile creation
# Expected: instance profile resource count == 1; tags/name copied
# NOTE: Do not assert outputs for ARN/Name non-null here; they are
#       unknown during plan. We only assert resource count/tags.
# ----------------------------------------------------------------
run "with_instance_profile" {
  command = plan

  variables {
    name                    = "role-with-ip"
    create_instance_profile = true
  }

  # Instance profile created
  assert {
    condition     = length(aws_iam_instance_profile.this) == 1
    error_message = "Instance profile should be created when create_instance_profile=true"
  }

  # Instance profile name/tag mirrors role name (plan-known)
  assert {
    condition     = aws_iam_instance_profile.this[0].name == "role-with-ip"
    error_message = "Instance profile name should mirror role name"
  }
  assert {
    condition     = aws_iam_instance_profile.this[0].tags["Name"] == "role-with-ip"
    error_message = "Instance profile Name tag should mirror role name"
  }
  assert {
    condition     = aws_iam_instance_profile.this[0].tags["Env"] == "test" && aws_iam_instance_profile.this[0].tags["Team"] == "platform"
    error_message = "Instance profile should carry Env and Team tags"
  }
}

# ----------------------------------------------------------------
# Lambda trust variant
# Expected: trust policy contains lambda.amazonaws.com principal
# ----------------------------------------------------------------
run "lambda_trust" {
  command = plan

  variables {
    name = "role-lambda"
    assume_role_policy = jsonencode({
      Version   = "2012-10-17"
      Statement = [
        {
          Effect    = "Allow"
          Action    = "sts:AssumeRole"
          Principal = { Service = "lambda.amazonaws.com" }
        }
      ]
    })
  }

  assert {
    condition     = aws_iam_role.this.name == "role-lambda"
    error_message = "Role name should match input"
  }
  assert {
    condition     = length(regexall("lambda\\.amazonaws\\.com", aws_iam_role.this.assume_role_policy)) > 0
    error_message = "Trust policy must include lambda.amazonaws.com"
  }
}

# ----------------------------------------------------------------
# Tag merge verification
# Expected: custom tags present and Name tag equals name
# ----------------------------------------------------------------
run "tag_merge" {
  command = plan

  variables {
    name = "role-tags"
    tags = {
      Env     = "test"
      Team    = "platform"
      Purpose = "iam-tests"
    }
  }

  assert {
    condition     = aws_iam_role.this.tags["Env"] == "test"
    error_message = "Env tag should be present"
  }
  assert {
    condition     = aws_iam_role.this.tags["Team"] == "platform"
    error_message = "Team tag should be present"
  }
  assert {
    condition     = aws_iam_role.this.tags["Purpose"] == "iam-tests"
    error_message = "Purpose tag should be present"
  }
  assert {
    condition     = aws_iam_role.this.tags["Name"] == "role-tags"
    error_message = "Name tag should equal role name"
  }
}

# ----------------------------------------------------------------
# Outputs shape (plan-safe)
# Expected: role_name equals input; when instance profile disabled,
#           instance profile outputs are null.
# ----------------------------------------------------------------
run "outputs_shape_disabled_ip" {
  command = plan

  variables {
    name                    = "role-out"
    create_instance_profile = false
  }

  assert {
    condition     = output.role_name == "role-out"
    error_message = "role_name output should match input"
  }
  assert {
    condition     = output.instance_profile_name == null
    error_message = "instance_profile_name should be null when not created"
  }
  assert {
    condition     = output.instance_profile_arn == null
    error_message = "instance_profile_arn should be null when not created"
  }
}
