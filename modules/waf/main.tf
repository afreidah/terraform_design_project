# -----------------------------------------------------------------------------
# WAF MODULE
# -----------------------------------------------------------------------------
#
# This module creates an AWS WAFv2 WebACL with configurable managed rule
# groups, rate limiting, and geographic blocking for application protection.
# The WebACL can be scoped for regional resources like Application Load
# Balancers or for global CloudFront distributions.
#
# AWS managed rule groups provide protection against common vulnerabilities
# including OWASP Top 10 threats, known malicious IP addresses, and suspicious
# input patterns. Rate limiting prevents abuse by restricting requests from
# individual IP addresses. Geographic blocking allows traffic restriction based
# on source country codes using ISO 3166-1 alpha-2 format.
#
# CloudWatch metrics and sampled request logging enable monitoring and analysis
# of blocked and allowed traffic patterns. Each rule includes configurable
# visibility settings for granular observability.
#
# IMPORTANT: WebACL capacity is consumed by each enabled rule and managed rule
# group. Monitor capacity usage to ensure it remains within AWS limits. Scope
# cannot be changed after creation without recreating the WebACL.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# WAF WEBACL
# -----------------------------------------------------------------------------

# AWS WAFv2 WebACL for application traffic filtering and protection
# Applies managed rules, rate limiting, and geographic restrictions
resource "aws_wafv2_web_acl" "this" {
  name  = var.name
  scope = var.scope

  # -------------------------------------------------------------------------
  # DEFAULT ACTION CONFIGURATION
  # -------------------------------------------------------------------------
  # Action taken when request does not match any rules
  default_action {
    dynamic "allow" {
      for_each = var.default_action == "allow" ? [1] : []
      content {}
    }

    dynamic "block" {
      for_each = var.default_action == "block" ? [1] : []
      content {}
    }
  }

  # -------------------------------------------------------------------------
  # AWS MANAGED RULES - CORE RULE SET
  # -------------------------------------------------------------------------
  # Protection against common application vulnerabilities and exploits
  dynamic "rule" {
    for_each = var.enable_aws_managed_rules ? [1] : []
    content {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 10

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          vendor_name = "AWS"
          name        = "AWSManagedRulesCommonRuleSet"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
        metric_name                = "${var.name}-common-rules"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  # -------------------------------------------------------------------------
  # AWS MANAGED RULES - KNOWN BAD INPUTS
  # -------------------------------------------------------------------------
  # Detection of invalid or malformed request patterns
  dynamic "rule" {
    for_each = var.enable_aws_managed_rules ? [1] : []
    content {
      name     = "AWSManagedRulesKnownBadInputsRuleSet"
      priority = 20

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          vendor_name = "AWS"
          name        = "AWSManagedRulesKnownBadInputsRuleSet"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
        metric_name                = "${var.name}-bad-inputs"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  # -------------------------------------------------------------------------
  # AWS MANAGED RULES - IP REPUTATION LIST
  # -------------------------------------------------------------------------
  # Blocking of known malicious IP addresses
  dynamic "rule" {
    for_each = var.enable_ip_reputation ? [1] : []
    content {
      name     = "AWSManagedRulesAmazonIpReputationList"
      priority = 30

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          vendor_name = "AWS"
          name        = "AWSManagedRulesAmazonIpReputationList"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
        metric_name                = "${var.name}-ip-reputation"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  # -------------------------------------------------------------------------
  # RATE LIMITING RULE
  # -------------------------------------------------------------------------
  # Request throttling per source IP address
  dynamic "rule" {
    for_each = var.enable_rate_limiting ? [1] : []
    content {
      name     = "RateLimitRule"
      priority = 40

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = var.rate_limit
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
        metric_name                = "${var.name}-rate-limit"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  # -------------------------------------------------------------------------
  # GEOGRAPHIC BLOCKING RULE
  # -------------------------------------------------------------------------
  # Country-based traffic filtering using ISO 3166-1 alpha-2 codes
  dynamic "rule" {
    for_each = var.enable_geo_blocking && length(var.blocked_countries) > 0 ? [1] : []
    content {
      name     = "GeoBlockingRule"
      priority = 50

      action {
        block {}
      }

      statement {
        geo_match_statement {
          country_codes = var.blocked_countries
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
        metric_name                = "${var.name}-geo-block"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  # -------------------------------------------------------------------------
  # WEBACL VISIBILITY CONFIGURATION
  # -------------------------------------------------------------------------
  # CloudWatch metrics and request sampling for the entire WebACL
  visibility_config {
    cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
    metric_name                = var.name
    sampled_requests_enabled   = var.sampled_requests_enabled
  }

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}
