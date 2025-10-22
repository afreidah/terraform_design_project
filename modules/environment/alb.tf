# -----------------------------------------------------------------------------
# LOAD BALANCERS CONFIGURATION
# -----------------------------------------------------------------------------
#
# This file defines Application Load Balancers (ALBs) for the environment.
# Two ALBs are deployed following the defense-in-depth security model:
#   - Public ALB:  Internet-facing, handles external traffic with WAF protection
#   - Internal ALB: VPC-only, handles internal service-to-service communication
#
# Architecture:
#   - Public ALB:  Deployed in public subnets with internet gateway access
#   - Internal ALB: Deployed in private app subnets, no direct internet access
#   - Both ALBs route to EC2 instances on port 8080
#   - HTTPS termination at ALB layer with ACM certificates
#
# Health Checks:
#   - Path: /health (application MUST expose this endpoint returning HTTP 200)
#   - Healthy threshold: 3 consecutive successes
#   - Unhealthy threshold: 3 consecutive failures
#   - Interval: 30 seconds
#   - Timeout: 5 seconds
#
# IMPORTANT:
#   - SSL certificate ARN required for production HTTPS
#   - Configure access logging S3 bucket before enabling logs
#   - WAF attached to public ALB only (internal traffic assumed trusted)
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# PUBLIC-FACING APPLICATION LOAD BALANCER
# -----------------------------------------------------------------------------

module "alb_public" {
  source = "../../modules/alb"

  name               = "${var.environment}-public-alb"
  internal           = false
  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.public_subnet_ids
  security_group_ids = [module.security_groups["alb_public"].security_group_id]

  # -------------------------------------------------------------------------
  # HTTPS CONFIGURATION
  # -------------------------------------------------------------------------
  # REQUIRED: SSL certificate from AWS Certificate Manager for production
  # Obtain ACM certificate for your domain before deploying
  certificate_arn            = var.ssl_certificate_arn
  enable_deletion_protection = true
  drop_invalid_header_fields = true

  # -------------------------------------------------------------------------
  # ACCESS LOGGING
  # -------------------------------------------------------------------------
  # Disabled by default - enable after creating dedicated S3 bucket
  # Access logs capture detailed request information for compliance/debugging
  access_logs_enabled = false
  access_logs_bucket  = null # Set to S3 bucket name when enabling

  # -------------------------------------------------------------------------
  # WEB APPLICATION FIREWALL (WAF)
  # -------------------------------------------------------------------------
  # Protects against OWASP Top 10, DDoS, and other web exploits
  waf_web_acl_arn = module.waf.web_acl_arn

  # -------------------------------------------------------------------------
  # TARGET GROUPS
  # -------------------------------------------------------------------------
  # Routes traffic to EC2 instances running application on port 8080
  # Application MUST expose /health endpoint returning HTTP 200 for health checks
  target_groups = {
    ec2 = {
      port                 = 8080
      protocol             = "HTTP"
      target_type          = "instance"
      deregistration_delay = 300 # 5 minutes for connection draining

      health_check = {
        enabled             = true
        healthy_threshold   = 3  # 3 consecutive successes = healthy
        interval            = 30 # Check every 30 seconds
        matcher             = "200"
        path                = "/health" # REQUIRED: Application must expose this
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 3 # 3 consecutive failures = unhealthy
      }

      stickiness = null # Session stickiness disabled (stateless application)
    }
  }

  tags = merge(
    local.common_tags,
    {
      Type = "public"
    }
  )
}

# -----------------------------------------------------------------------------
# INTERNAL APPLICATION LOAD BALANCER
# -----------------------------------------------------------------------------

module "alb_internal" {
  source = "../../modules/alb"

  name               = "${var.environment}-internal-alb"
  internal           = true # VPC-only, no internet access
  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.private_app_subnet_ids
  security_group_ids = [module.security_groups["alb_internal"].security_group_id]

  # -------------------------------------------------------------------------
  # HTTPS CONFIGURATION
  # -------------------------------------------------------------------------
  # Optional for internal traffic, but recommended for encryption in transit
  certificate_arn            = null # Set to ACM cert ARN when available
  enable_deletion_protection = true
  drop_invalid_header_fields = true

  # -------------------------------------------------------------------------
  # ACCESS LOGGING
  # -------------------------------------------------------------------------
  access_logs_enabled = false
  access_logs_bucket  = null

  # -------------------------------------------------------------------------
  # WAF
  # -------------------------------------------------------------------------
  # No WAF on internal ALB - internal traffic assumed trusted
  waf_web_acl_arn = null

  # -------------------------------------------------------------------------
  # TARGET GROUPS
  # -------------------------------------------------------------------------
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
        path                = "/health"
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

# -----------------------------------------------------------------------------
# WAF ASSOCIATION
# -----------------------------------------------------------------------------

# Attach WAF Web ACL to public ALB for protection against web exploits
resource "aws_wafv2_web_acl_association" "public_alb" {
  resource_arn = module.alb_public.alb_arn
  web_acl_arn  = module.waf.web_acl_arn
}
