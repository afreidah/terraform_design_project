# -----------------------------------------------------------------------------
# WEB APPLICATION FIREWALL (WAF)
# -----------------------------------------------------------------------------
#
# This file configures AWS WAF for the public-facing Application Load Balancer.
#
# Protection Features:
#   - AWS Managed Rules: OWASP Top 10, bot control, known bad inputs
#   - Rate Limiting: 2000 requests per 5 minutes per IP (prevents DDoS)
#   - IP Reputation: Blocks IPs with poor reputation scores
#   - Custom Rules: Optional geo-blocking and custom patterns
#
# Architecture:
#   - Scope: REGIONAL (attached to ALB, not CloudFront)
#   - Default Action: ALLOW (only block on rule match)
#   - Rule Evaluation: Rules evaluated in priority order
#   - Logging: Metrics enabled for monitoring rule effectiveness
#
# AWS Managed Rule Groups:
#   - Core Rule Set: Protection against common exploits (SQLi, XSS, LFI, RFI)
#   - Known Bad Inputs: Block requests with patterns of exploitation
#   - IP Reputation: Block requests from known malicious IPs
#
# Rate Limiting:
#   - Threshold: 2000 requests per 5 minutes per IP address
#   - Purpose: Prevent DDoS attacks and aggressive scanning
#   - Action: BLOCK requests exceeding threshold
#   - Tuning: Adjust based on legitimate traffic patterns
#
# Monitoring:
#   - CloudWatch Metrics: Request counts, blocked requests, rule matches
#   - Sampled Requests: Sample of blocked requests for analysis
#   - WAF Logs: Optional logging to S3/CloudWatch (not enabled by default)
# -----------------------------------------------------------------------------

module "waf" {
  source = "../../modules/waf"

  name  = "${var.environment}-public-alb-waf"
  scope = "REGIONAL" # For ALB (use CLOUDFRONT for CloudFront distributions)

  default_action = "allow" # Allow traffic unless explicitly blocked by rules

  # -------------------------------------------------------------------------
  # AWS MANAGED RULE SETS
  # -------------------------------------------------------------------------
  # Pre-configured rule groups maintained by AWS for common threats
  enable_aws_managed_rules = true # OWASP Top 10, SQLi, XSS, etc.
  enable_ip_reputation     = true # Block known malicious IPs

  # -------------------------------------------------------------------------
  # RATE LIMITING
  # -------------------------------------------------------------------------
  # Prevent DDoS and aggressive scanning
  enable_rate_limiting = true
  rate_limit           = 2000 # Requests per 5 minutes per IP

  # -------------------------------------------------------------------------
  # OPTIONAL: GEO-BLOCKING
  # -------------------------------------------------------------------------
  # Uncomment to restrict access by country (ISO 3166-1 alpha-2 codes)
  # Useful for region-specific applications or compliance requirements
  # enable_geo_blocking = true
  # blocked_countries   = ["CN", "RU"]          # Example: block China and Russia

  # -------------------------------------------------------------------------
  # MONITORING
  # -------------------------------------------------------------------------
  cloudwatch_metrics_enabled = true # Enable CloudWatch metrics for rules
  sampled_requests_enabled   = true # Sample blocked requests for analysis

  tags = {
    Environment = var.environment
  }
}
