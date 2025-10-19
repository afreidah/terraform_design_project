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

  # Certificate ARN for HTTPS (optional - uncomment when you have a cert in ACM)
  # certificate_arn = var.ssl_certificate_arn

  # Attach WAF
  enable_waf  = true
  waf_acl_arn = module.waf.web_acl_arn

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
