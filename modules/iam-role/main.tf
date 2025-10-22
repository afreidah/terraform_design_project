# -----------------------------------------------------------------------------
# IAM ROLE MODULE
# -----------------------------------------------------------------------------
#
# This module creates an AWS IAM role with configurable trust policy, managed
# policy attachments, and optional EC2 instance profile. It provides a
# reusable pattern for creating service roles with proper permissions and
# trust relationships.
#
# Components Created:
#   - IAM Role: Identity with trust policy for AWS services or users
#   - Policy Attachments: AWS managed or custom policies for permissions
#   - Instance Profile: Optional EC2 instance profile for role attachment
#
# Features:
#   - Flexible trust policy via assume_role_policy parameter
#   - Multiple managed policy attachments support
#   - Optional instance profile for EC2 use cases
#   - Consistent tagging across all resources
#   - Supports any AWS service principal
#
# Common Use Cases:
#   - EC2 Instance Roles: Attach to instances via instance profile
#   - Lambda Execution Roles: Grant Lambda function permissions
#   - ECS Task Roles: Provide permissions to containerized applications
#   - Cross-Account Roles: Enable cross-account access patterns
#   - Service Roles: Allow AWS services to act on your behalf
#
# Security Model:
#   - Trust Policy: Defines who/what can assume the role
#   - Managed Policies: Grant specific AWS service permissions
#   - Least Privilege: Attach only required policies
#   - Instance Profile: EC2-specific role attachment mechanism
#
# IMPORTANT:
#   - Trust policy must be valid JSON and include sts:AssumeRole action
#   - Policy ARNs must exist before attachment
#   - Instance profile only needed for EC2 use cases
#   - Role name must be unique within AWS account
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# IAM ROLE
# -----------------------------------------------------------------------------

# IAM role with configurable trust policy
# Defines identity that can be assumed by specified principals
resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = var.assume_role_policy

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}

# -----------------------------------------------------------------------------
# MANAGED POLICY ATTACHMENTS
# -----------------------------------------------------------------------------

# Attach AWS managed or customer managed policies to role
# Grants permissions defined in the policies to role principals
resource "aws_iam_role_policy_attachment" "this" {
  count = length(var.policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = var.policy_arns[count.index]
}

# -----------------------------------------------------------------------------
# INSTANCE PROFILE (EC2)
# -----------------------------------------------------------------------------

# Instance profile for attaching role to EC2 instances
# Only created when create_instance_profile is true
resource "aws_iam_instance_profile" "this" {
  count = var.create_instance_profile ? 1 : 0

  name = var.name
  role = aws_iam_role.this.name

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}
