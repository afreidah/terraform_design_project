# -----------------------------------------------------------------------------
# IAM ROLE MODULE - TEST SUITE
# -----------------------------------------------------------------------------
#
# This test suite validates the IAM role module functionality across various
# configuration scenarios. Tests use Terraform's native testing framework to
# verify resource creation, trust policy configuration, policy attachments,
# and conditional instance profile creation without requiring actual AWS
# infrastructure deployment.
#
# Test Categories:
#   - Basic Role: EC2 trust policy with no attachments
#   - Managed Policies: Multiple policy attachment verification
#   - Instance Profile: Conditional EC2 instance profile creation
#   - Trust Policy Variants: Different service principals (EC2, Lambda)
#   - Tagging: Tag merge and Name tag validation
#   - Outputs: Output shape validation with and without instance profile
#
# Testing Approach:
#   - Uses terraform plan to validate resource configuration
#   - Mock trust policies and policy ARNs
#   - Assertions verify expected behavior without AWS API calls
#   - Tests conditional resource creation patterns
#
# IMPORTANT:
#   - Tests run in plan mode only (no actual infrastructure created)
#   - Trust policies validated via regex pattern matching
#   - Instance profile outputs are null when not created
#   - Policy ARN validation occurs at plan time
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# SHARED TEST DEFAULTS / MOCKS
# -----------------------------------------------------------------------------

# Mock IAM role configuration for testing
# These values simulate production role creation without requiring real AWS resources
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

# -----------------------------------------------------------------------------
# BASIC EC2 ROLE
# -----------------------------------------------------------------------------

# Validates basic IAM role creation with EC2 trust policy
# Expected Behavior:
#   - Role created with correct name
#   - Trust policy contains sts:AssumeRole and EC2 principal
#   - No managed policy attachments
#   - No instance profile created
#   - Instance profile outputs are null
run "basic_ec2_role" {
  command = plan

  variables {
    name                    = "role-basic-ec2"
    create_instance_profile = false
    policy_arns             = []
    # assume_role_policy inherited from defaults (EC2 principal)
  }

  # -------------------------------------------------------------------------
  # ROLE CORE ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify role name matches input
  assert {
    condition     = aws_iam_role.this.name == "role-basic-ec2"
    error_message = "Role name should match input"
  }

  # -------------------------------------------------------------------------
  # TRUST POLICY ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify trust policy contains sts:AssumeRole action
  assert {
    condition     = length(regexall("sts:AssumeRole", aws_iam_role.this.assume_role_policy)) > 0
    error_message = "Trust policy must include sts:AssumeRole"
  }

  # Verify trust policy contains EC2 service principal
  assert {
    condition     = length(regexall("ec2\\.amazonaws\\.com", aws_iam_role.this.assume_role_policy)) > 0
    error_message = "Trust policy must include ec2.amazonaws.com service principal"
  }

  # -------------------------------------------------------------------------
  # TAG ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify custom tags are present
  assert {
    condition     = aws_iam_role.this.tags["Env"] == "test" && aws_iam_role.this.tags["Team"] == "platform"
    error_message = "Role should carry Env and Team tags"
  }

  # Verify Name tag matches role name
  assert {
    condition     = aws_iam_role.this.tags["Name"] == "role-basic-ec2"
    error_message = "Role Name tag should equal role name"
  }

  # -------------------------------------------------------------------------
  # POLICY ATTACHMENT ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify no managed policy attachments
  assert {
    condition     = length(aws_iam_role_policy_attachment.this) == 0
    error_message = "No managed policy attachments expected"
  }

  # -------------------------------------------------------------------------
  # INSTANCE PROFILE ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify instance profile not created
  assert {
    condition     = length(aws_iam_instance_profile.this) == 0
    error_message = "Instance profile should not be created when create_instance_profile=false"
  }

  # -------------------------------------------------------------------------
  # OUTPUT ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify role name output
  assert {
    condition     = output.role_name == "role-basic-ec2"
    error_message = "role_name output should match input"
  }

  # Verify instance profile outputs are null when not created
  assert {
    condition     = output.instance_profile_name == null
    error_message = "instance_profile_name should be null when create_instance_profile=false"
  }

  assert {
    condition     = output.instance_profile_arn == null
    error_message = "instance_profile_arn should be null when create_instance_profile=false"
  }
}

# -----------------------------------------------------------------------------
# ROLE WITH MANAGED POLICIES
# -----------------------------------------------------------------------------

# Validates IAM role with multiple managed policy attachments
# Expected Behavior:
#   - Role created successfully
#   - Attachment count matches input policy ARN count
run "with_managed_policies" {
  command = plan

  variables {
    name = "role-with-managed"
    policy_arns = [
      "arn:aws:iam::aws:policy/ReadOnlyAccess",
      "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
    ]
  }

  # -------------------------------------------------------------------------
  # ROLE ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify role name matches input
  assert {
    condition     = aws_iam_role.this.name == "role-with-managed"
    error_message = "Role name should match input"
  }

  # -------------------------------------------------------------------------
  # POLICY ATTACHMENT ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify managed policy attachment count
  assert {
    condition     = length(aws_iam_role_policy_attachment.this) == length(var.policy_arns)
    error_message = "Managed policy attachment count should match input length"
  }
}

# -----------------------------------------------------------------------------
# ROLE WITH INSTANCE PROFILE
# -----------------------------------------------------------------------------

# Validates conditional instance profile creation
# Expected Behavior:
#   - Instance profile created when flag is true
#   - Instance profile name mirrors role name
#   - Instance profile carries same tags as role
run "with_instance_profile" {
  command = plan

  variables {
    name                    = "role-with-ip"
    create_instance_profile = true
  }

  # -------------------------------------------------------------------------
  # INSTANCE PROFILE CREATION ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify instance profile is created
  assert {
    condition     = length(aws_iam_instance_profile.this) == 1
    error_message = "Instance profile should be created when create_instance_profile=true"
  }

  # -------------------------------------------------------------------------
  # INSTANCE PROFILE CONFIGURATION ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify instance profile name mirrors role name
  assert {
    condition     = aws_iam_instance_profile.this[0].name == "role-with-ip"
    error_message = "Instance profile name should mirror role name"
  }

  # Verify instance profile Name tag mirrors role name
  assert {
    condition     = aws_iam_instance_profile.this[0].tags["Name"] == "role-with-ip"
    error_message = "Instance profile Name tag should mirror role name"
  }

  # Verify instance profile carries custom tags
  assert {
    condition     = aws_iam_instance_profile.this[0].tags["Env"] == "test" && aws_iam_instance_profile.this[0].tags["Team"] == "platform"
    error_message = "Instance profile should carry Env and Team tags"
  }
}

# -----------------------------------------------------------------------------
# LAMBDA TRUST VARIANT
# -----------------------------------------------------------------------------

# Validates IAM role with Lambda service principal
# Expected Behavior:
#   - Role created with Lambda trust policy
#   - Trust policy contains lambda.amazonaws.com principal
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

  # -------------------------------------------------------------------------
  # ROLE ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify role name matches input
  assert {
    condition     = aws_iam_role.this.name == "role-lambda"
    error_message = "Role name should match input"
  }

  # -------------------------------------------------------------------------
  # TRUST POLICY ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify trust policy contains Lambda service principal
  assert {
    condition     = length(regexall("lambda\\.amazonaws\\.com", aws_iam_role.this.assume_role_policy)) > 0
    error_message = "Trust policy must include lambda.amazonaws.com"
  }
}

# -----------------------------------------------------------------------------
# TAG MERGE VERIFICATION
# -----------------------------------------------------------------------------

# Validates tag merging and Name tag assignment
# Expected Behavior:
#   - All custom tags present on role
#   - Name tag automatically set to role name
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

  # -------------------------------------------------------------------------
  # TAG ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify Env tag present
  assert {
    condition     = aws_iam_role.this.tags["Env"] == "test"
    error_message = "Env tag should be present"
  }

  # Verify Team tag present
  assert {
    condition     = aws_iam_role.this.tags["Team"] == "platform"
    error_message = "Team tag should be present"
  }

  # Verify custom Purpose tag present
  assert {
    condition     = aws_iam_role.this.tags["Purpose"] == "iam-tests"
    error_message = "Purpose tag should be present"
  }

  # Verify Name tag equals role name
  assert {
    condition     = aws_iam_role.this.tags["Name"] == "role-tags"
    error_message = "Name tag should equal role name"
  }
}

# -----------------------------------------------------------------------------
# OUTPUTS SHAPE (DISABLED INSTANCE PROFILE)
# -----------------------------------------------------------------------------

# Validates output behavior when instance profile is not created
# Expected Behavior:
#   - role_name output matches input
#   - Instance profile outputs are null
run "outputs_shape_disabled_ip" {
  command = plan

  variables {
    name                    = "role-out"
    create_instance_profile = false
  }

  # -------------------------------------------------------------------------
  # OUTPUT ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify role name output
  assert {
    condition     = output.role_name == "role-out"
    error_message = "role_name output should match input"
  }

  # Verify instance profile name output is null
  assert {
    condition     = output.instance_profile_name == null
    error_message = "instance_profile_name should be null when not created"
  }

  # Verify instance profile ARN output is null
  assert {
    condition     = output.instance_profile_arn == null
    error_message = "instance_profile_arn should be null when not created"
  }
}
