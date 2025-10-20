# -----------------------------------------------------------------------------
# IAM ROLES
# -----------------------------------------------------------------------------

# EC2 Assume Role Policy
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# IAM Policy for Parameter Store access
data "aws_iam_policy_document" "parameter_store_access" {
  statement {
    sid    = "AllowParameterStoreRead"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:${var.region}:*:parameter/${var.environment}/*"
    ]
  }

  statement {
    sid    = "AllowKMSDecrypt"
    effect = "Allow"
    actions = [
      "kms:Decrypt"
    ]
    resources = [module.kms_parameter_store.key_arn]
  }
}

resource "aws_iam_policy" "parameter_store_access" {
  name        = "${var.environment}-parameter-store-access"
  description = "Allow reading parameters from Parameter Store"
  policy      = data.aws_iam_policy_document.parameter_store_access.json
}

# EC2 IAM Role
module "ec2_iam_role" {
  source = "../../modules/iam-role"

  name                    = "${var.environment}-ec2-app-role"
  assume_role_policy      = data.aws_iam_policy_document.ec2_assume_role.json
  create_instance_profile = true

  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    aws_iam_policy.parameter_store_access.arn
  ]

  tags = {
    Environment = var.environment
  }
}
