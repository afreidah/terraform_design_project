# -----------------------------------------------------------------------------
# LOAD BALANCERS
# -----------------------------------------------------------------------------

# Public-facing ALB
module "alb_public" {
  source = "../../modules/alb"

  name               = "${var.environment}-public-alb"
  internal           = false
  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.public_subnet_ids
  security_group_ids = [module.security_groups["alb_public"].security_group_id]

  # HTTPS Configuration
  # SSL certificate required for production - obtain from AWS Certificate Manager
  certificate_arn            = var.ssl_certificate_arn
  enable_deletion_protection = true
  drop_invalid_header_fields = true

  # Access Logging
  access_logs_enabled = false # Set to true when S3 bucket is created
  access_logs_bucket  = null  # Set to S3 bucket name when created

  # WAF
  waf_web_acl_arn = module.waf.web_acl_arn

  # Target Groups
  # NOTE: Application must expose /health endpoint returning HTTP 200
  # Customize health_check.path if using a different endpoint
  target_groups = {
    ec2 = {
      port                 = 8080
      protocol             = "HTTP"
      target_type          = "instance"
      deregistration_delay = 300
      health_check = {
        enabled             = true
        healthy_threshold   = 3
        interval            = 30
        matcher             = "200"
        path                = "/health" # Application must expose this endpoint
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 3
      }
      stickiness = null
    }
  }

  tags = merge(
    local.common_tags,
    {
      Type = "public"
    }
  )
}

# Internal ALB
module "alb_internal" {
  source = "../../modules/alb"

  name               = "${var.environment}-internal-alb"
  internal           = true
  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.private_app_subnet_ids
  security_group_ids = [module.security_groups["alb_internal"].security_group_id]

  # HTTPS Configuration
  certificate_arn            = null # Set to your ACM cert ARN when available
  enable_deletion_protection = true
  drop_invalid_header_fields = true

  # Access Logging
  access_logs_enabled = false # Set to true when S3 bucket is created
  access_logs_bucket  = null  # Set to S3 bucket name when created

  # No WAF on internal ALB
  waf_web_acl_arn = null

  # Target Groups
  # NOTE: Application must expose /health endpoint returning HTTP 200
  target_groups = {
    ec2 = {
      port                 = 8080
      protocol             = "HTTP"
      target_type          = "instance"
      deregistration_delay = 300
      health_check = {
        enabled             = true
        healthy_threshold   = 3
        interval            = 30
        matcher             = "200"
        path                = "/health" # Application must expose this endpoint
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 3
      }
      stickiness = null
    }
  }

  tags = merge(
    local.common_tags,
    {
      Type = "internal"
    }
  )
}

# WAF Association for Public ALB
resource "aws_wafv2_web_acl_association" "public_alb" {
  resource_arn = module.alb_public.alb_arn
  web_acl_arn  = module.waf.web_acl_arn
}
