# -----------------------------------------------------------------------------
# IAM ROLES & POLICIES
# -----------------------------------------------------------------------------
#
# This file defines IAM roles and policies for EC2 instances and other
# AWS services to securely access resources without embedded credentials.
#
# Roles Defined:
#   - EC2 Application Role: Allows EC2 instances to access AWS services
#
# Permissions Granted:
#   - SSM Session Manager: Secure shell access without SSH keys/bastion hosts
#   - CloudWatch Agent: Publish metrics and logs
#   - Parameter Store: Read encrypted configuration and secrets
#   - KMS: Decrypt Parameter Store SecureString values
#
# Security Model:
#   - Least Privilege: Only permissions required for application operation
#   - No Access Keys: IAM roles eliminate need for embedded credentials
#   - Audit Trail: CloudTrail logs all API calls made using these roles
#   - Scope Limitation: Parameter Store access restricted to environment path
#
# IMPORTANT:
#   - Parameter Store access scoped to /${environment}/* only
#   - KMS key access required for decrypting SecureString parameters
#   - Instance profile automatically attached to EC2 instances
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# EC2 TRUST POLICY
# -----------------------------------------------------------------------------

# Allow EC2 service to assume this role
# Instances with this role can make AWS API calls on behalf of the role
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# -----------------------------------------------------------------------------
# PARAMETER STORE ACCESS POLICY
# -----------------------------------------------------------------------------

# Grants read access to Parameter Store for application configuration
# Scoped to environment-specific parameters only for security isolation
data "aws_iam_policy_document" "parameter_store_access" {
  # -------------------------------------------------------------------------
  # READ PARAMETERS
  # -------------------------------------------------------------------------
  # Access limited to parameters under /${environment}/ path
  statement {
    sid    = "AllowParameterStoreRead"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",       # Get single parameter
      "ssm:GetParameters",      # Get multiple parameters (batch)
      "ssm:GetParametersByPath" # Get all parameters under path
    ]
    resources = [
      "arn:aws:ssm:${var.region}:*:parameter/${var.environment}/*"
    ]
  }

  # -------------------------------------------------------------------------
  # DECRYPT SECURE STRINGS
  # -------------------------------------------------------------------------
  # Required for accessing SecureString parameters encrypted with KMS
  statement {
    sid    = "AllowKMSDecrypt"
    effect = "Allow"
    actions = [
      "kms:Decrypt" # Required for SecureString parameters
    ]
    resources = [module.kms_parameter_store.key_arn]
  }
}

# Create managed policy from document
resource "aws_iam_policy" "parameter_store_access" {
  name        = "${var.environment}-parameter-store-access"
  description = "Allow reading parameters from Parameter Store"
  policy      = data.aws_iam_policy_document.parameter_store_access.json
}

# -----------------------------------------------------------------------------
# EC2 APPLICATION ROLE
# -----------------------------------------------------------------------------

# IAM role for EC2 application instances
# Attached policies grant access to AWS services without embedded credentials
module "ec2_iam_role" {
  source = "../../modules/iam-role"

  name                    = "${var.environment}-ec2-app-role"
  assume_role_policy      = data.aws_iam_policy_document.ec2_assume_role.json
  create_instance_profile = true # Create instance profile for EC2 attachment

  # -------------------------------------------------------------------------
  # ATTACHED POLICIES
  # -------------------------------------------------------------------------
  # Combination of AWS managed policies and custom Parameter Store policy
  policy_arns = [
    # SSM Session Manager for secure shell access (no SSH keys needed)
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",

    # CloudWatch Agent for publishing metrics and logs
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",

    # Custom policy for Parameter Store read access
    aws_iam_policy.parameter_store_access.arn
  ]

  tags = {
    Environment = var.environment
  }
}
