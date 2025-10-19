# environments/production/main.tf

# =============================================================================
# NETWORKING
# =============================================================================

module "networking" {
  source = "../../modules/general-networking"

  vpc_cidr                  = var.vpc_cidr
  vpc_name                  = var.environment
  availability_zones        = var.availability_zones
  public_subnet_cidrs       = var.public_subnet_cidrs
  private_app_subnet_cidrs  = var.private_app_subnet_cidrs
  private_data_subnet_cidrs = var.private_data_subnet_cidrs

  tags = {
    Environment = var.environment
  }
}

# =============================================================================
# SECURITY GROUPS
# =============================================================================

module "security_groups" {
  source   = "../../modules/security-group"
  for_each = local.security_groups

  vpc_id        = module.networking.vpc_id
  name          = "${var.environment}-${each.key}-sg"
  description   = each.value.description
  ingress_rules = each.value.ingress_rules
  egress_rules  = each.value.egress_rules

  tags = {
    Environment = var.environment
    Purpose     = each.key
  }
}

# =============================================================================
# IAM ROLES
# =============================================================================

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
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${var.region}.amazonaws.com"]
    }
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

# =============================================================================
# LOAD BALANCERS
# =============================================================================

# Public-facing ALB
module "alb_public" {
  source = "../../modules/alb"

  name               = "${var.environment}-public-alb"
  internal           = false
  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.public_subnet_ids
  security_group_ids = [module.security_groups["alb_public"].security_group_id]

  # Certificate ARN for HTTPS (optional - uncomment when you have a cert in ACM)
  # certificate_arn = var.ssl_certificate_arn

  # WAF will be added later
  # enable_waf   = true
  # waf_acl_arn  = module.waf.web_acl_arn

  target_groups = {
    ec2 = {
      port        = 8080
      protocol    = "HTTP"
      target_type = "instance"
      health_check = {
        enabled             = true
        healthy_threshold   = 3
        interval            = 30
        matcher             = "200"
        path                = "/health"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 3
      }
    }
  }

  tags = {
    Environment = var.environment
    Type        = "public"
  }
}

# Internal ALB
module "alb_internal" {
  source = "../../modules/alb"

  name               = "${var.environment}-internal-alb"
  internal           = true
  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.private_app_subnet_ids
  security_group_ids = [module.security_groups["alb_internal"].security_group_id]

  target_groups = {
    ec2 = {
      port        = 8080
      protocol    = "HTTP"
      target_type = "instance"
      health_check = {
        enabled             = true
        healthy_threshold   = 3
        interval            = 30
        matcher             = "200"
        path                = "/health"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 3
      }
    }
  }

  tags = {
    Environment = var.environment
    Type        = "internal"
  }
}

# =============================================================================
# EC2 INSTANCES
# =============================================================================

module "ec2_app" {
  source = "../../modules/ec2"

  name                 = "${var.environment}-app"
  ami_id               = var.ec2_ami_id
  instance_type        = var.ec2_instance_type
  subnet_ids           = module.networking.private_app_subnet_ids
  security_group_ids   = [module.security_groups["ec2_app"].security_group_id]
  iam_instance_profile = module.ec2_iam_role.instance_profile_name

  desired_capacity = 2
  min_size         = 1
  max_size         = 4

  # Attach to ALB target groups
  target_group_arns = [
    module.alb_public.target_group_arns["ec2"],
    module.alb_internal.target_group_arns["ec2"]
  ]

  tags = {
    Environment = var.environment
    Purpose     = "application"
  }
}

# =============================================================================
# PARAMETER STORE (Secrets Management)
# =============================================================================

module "parameter_store" {
  source = "../../modules/parameter-store"

  parameters = {
    "/${var.environment}/database/master_username" = {
      description = "RDS master username"
      type        = "SecureString"
      value       = "dbadmin" # this would go in sops, or ideally it would use Vault
    }
    "/${var.environment}/database/master_password" = {
      description = "RDS master password"
      type        = "SecureString"
      value       = "ChangeMe123!"
    }
    "/${var.environment}/app/api_key" = {
      description = "Application API key"
      type        = "SecureString"
      value       = "your-api-key-here"
    }
    "/${var.environment}/app/encryption_key" = {
      description = "Application encryption key"
      type        = "SecureString"
      value       = "your-encryption-key-here"
    }
  }

  tags = {
    Environment = var.environment
  }
}
