# -----------------------------------------------------------------------------
# WAF
# -----------------------------------------------------------------------------

module "waf" {
  source = "../../modules/waf"

  name  = "${var.environment}-public-alb-waf"
  scope = "REGIONAL"

  default_action = "allow"

  enable_aws_managed_rules = true
  enable_rate_limiting     = true
  rate_limit               = 2000 # 2000 requests per 5 minutes per IP
  enable_ip_reputation     = true

  # Optional: Enable geo blocking
  # enable_geo_blocking = true
  # blocked_countries   = ["CN", "RU"]  # Example: block China and Russia

  cloudwatch_metrics_enabled = true
  sampled_requests_enabled   = true

  tags = {
    Environment = var.environment
  }
}
