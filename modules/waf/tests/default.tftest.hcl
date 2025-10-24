# -----------------------------------------------------------------------------
# WAF MODULE TEST SUITE
# -----------------------------------------------------------------------------
#
# Plan-safe assertions validating WebACL configuration, rule presence, and
# visibility settings. Tests avoid equality checks against computed values
# like capacity, IDs, and ARNs that are unknown at plan time.
#
# Test Coverage:
# WebACL creation with name and scope configuration. Default action behavior
# for allow and block modes. AWS managed rule group presence including Core
# Rule Set, Known Bad Inputs, and IP Reputation lists. Rate limiting rule
# configuration with request threshold validation. Geographic blocking with
# country code validation. CloudWatch metrics and sampled request settings.
# Tag propagation. Output values known at plan time.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# TEST DEFAULTS AND MOCK VALUES
# -----------------------------------------------------------------------------

variables {
  name  = "test-web-acl"
  scope = "REGIONAL"

  default_action = "allow"

  enable_aws_managed_rules = true
  enable_rate_limiting     = true
  rate_limit               = 2000

  enable_geo_blocking = false
  blocked_countries   = []

  enable_ip_reputation = true

  cloudwatch_metrics_enabled = true
  sampled_requests_enabled   = true

  tags = {
    Env  = "test"
    Team = "secops"
  }
}

# -----------------------------------------------------------------------------
# BASELINE CONFIGURATION TEST
# -----------------------------------------------------------------------------
# Validates default configuration with all managed rules enabled

run "baseline_defaults" {
  command = plan

  variables {
    # Use defaults above
  }

  # WebACL basic properties
  assert {
    condition     = aws_wafv2_web_acl.this.name == var.name
    error_message = "WebACL name should match input"
  }
  assert {
    condition     = aws_wafv2_web_acl.this.scope == var.scope
    error_message = "WebACL scope should match input"
  }

  # Default action allow
  assert {
    condition     = try(length(aws_wafv2_web_acl.this.default_action[0].allow), 0) == 1
    error_message = "Default action should be allow"
  }

  # Visibility configuration
  assert {
    condition     = aws_wafv2_web_acl.this.visibility_config[0].cloudwatch_metrics_enabled == true
    error_message = "CloudWatch metrics should be enabled"
  }
  assert {
    condition     = aws_wafv2_web_acl.this.visibility_config[0].sampled_requests_enabled == true
    error_message = "Sampled requests should be enabled"
  }

  # AWS managed rule groups presence
  assert {
    condition     = length([for r in aws_wafv2_web_acl.this.rule : r if r.name == "AWSManagedRulesCommonRuleSet"]) == 1
    error_message = "CommonRuleSet should be present"
  }
  assert {
    condition     = length([for r in aws_wafv2_web_acl.this.rule : r if r.name == "AWSManagedRulesKnownBadInputsRuleSet"]) == 1
    error_message = "KnownBadInputsRuleSet should be present"
  }
  assert {
    condition     = length([for r in aws_wafv2_web_acl.this.rule : r if r.name == "AWSManagedRulesAmazonIpReputationList"]) == 1
    error_message = "AmazonIpReputationList should be present"
  }

  # Rate limiting rule validation
  assert {
    condition     = length([for r in aws_wafv2_web_acl.this.rule : r if r.name == "RateLimitRule"]) == 1
    error_message = "RateLimitRule should be present"
  }
  assert {
    condition     = try([for r in aws_wafv2_web_acl.this.rule : r.statement[0].rate_based_statement[0].limit if r.name == "RateLimitRule"][0], 0) == var.rate_limit
    error_message = "RateLimitRule limit should match input"
  }

  # Tag validation
  assert {
    condition     = aws_wafv2_web_acl.this.tags["Name"] == var.name
    error_message = "Name tag should equal WebACL name"
  }
  assert {
    condition     = aws_wafv2_web_acl.this.tags["Env"] == "test"
    error_message = "Env tag should be present"
  }

  # Plan-known output
  assert {
    condition     = output.web_acl_name == var.name
    error_message = "Output web_acl_name should match input"
  }
}

# -----------------------------------------------------------------------------
# DEFAULT ACTION BLOCK TEST
# -----------------------------------------------------------------------------
# Validates block default action configuration

run "default_action_block" {
  command = plan

  variables {
    default_action = "block"
  }

  assert {
    condition     = try(length(aws_wafv2_web_acl.this.default_action[0].block), 0) == 1
    error_message = "Default action should be block"
  }
  assert {
    condition     = try(length(aws_wafv2_web_acl.this.default_action[0].allow), 0) == 0
    error_message = "Allow action should not be set when default is block"
  }
}

# -----------------------------------------------------------------------------
# SELECTIVE MANAGED RULES TEST
# -----------------------------------------------------------------------------
# Validates disabling core managed rules while keeping IP reputation

run "disable_managed_rules_keep_reputation" {
  command = plan

  variables {
    enable_aws_managed_rules = false
    enable_ip_reputation     = true
  }

  assert {
    condition     = length([for r in aws_wafv2_web_acl.this.rule : r if r.name == "AWSManagedRulesCommonRuleSet"]) == 0
    error_message = "CommonRuleSet should be disabled"
  }
  assert {
    condition     = length([for r in aws_wafv2_web_acl.this.rule : r if r.name == "AWSManagedRulesKnownBadInputsRuleSet"]) == 0
    error_message = "KnownBadInputsRuleSet should be disabled"
  }
  assert {
    condition     = length([for r in aws_wafv2_web_acl.this.rule : r if r.name == "AWSManagedRulesAmazonIpReputationList"]) == 1
    error_message = "AmazonIpReputationList should remain enabled"
  }
}

# -----------------------------------------------------------------------------
# DISABLE REPUTATION AND RATE LIMITING TEST
# -----------------------------------------------------------------------------
# Validates WebACL with minimal protection rules

run "disable_reputation_and_rate" {
  command = plan

  variables {
    enable_ip_reputation = false
    enable_rate_limiting = false
  }

  assert {
    condition     = length([for r in aws_wafv2_web_acl.this.rule : r if r.name == "AWSManagedRulesAmazonIpReputationList"]) == 0
    error_message = "AmazonIpReputationList should be disabled"
  }
  assert {
    condition     = length([for r in aws_wafv2_web_acl.this.rule : r if r.name == "RateLimitRule"]) == 0
    error_message = "RateLimitRule should be disabled"
  }
}

# -----------------------------------------------------------------------------
# GEOGRAPHIC BLOCKING TEST
# -----------------------------------------------------------------------------
# Validates country-based traffic filtering

run "geo_blocking_enabled" {
  command = plan

  variables {
    enable_geo_blocking = true
    blocked_countries   = ["RU", "CN"]
  }

  assert {
    condition     = length([for r in aws_wafv2_web_acl.this.rule : r if r.name == "GeoBlockingRule"]) == 1
    error_message = "GeoBlockingRule should be present"
  }
  assert {
    condition     = try(length([for r in aws_wafv2_web_acl.this.rule : r.statement[0].geo_match_statement[0].country_codes if r.name == "GeoBlockingRule"][0]), 0) == 2
    error_message = "GeoBlockingRule should include two country codes"
  }
}

# -----------------------------------------------------------------------------
# CLOUDFRONT SCOPE TEST
# -----------------------------------------------------------------------------
# Validates global CloudFront distribution protection

run "cloudfront_scope" {
  command = plan

  variables {
    scope = "CLOUDFRONT"
  }

  assert {
    condition     = aws_wafv2_web_acl.this.scope == "CLOUDFRONT"
    error_message = "Scope should be CLOUDFRONT when configured"
  }
}

# -----------------------------------------------------------------------------
# METRICS AND SAMPLING DISABLED TEST
# -----------------------------------------------------------------------------
# Validates WebACL with minimal observability

run "metrics_sampling_disabled" {
  command = plan

  variables {
    cloudwatch_metrics_enabled = false
    sampled_requests_enabled   = false
  }

  assert {
    condition     = aws_wafv2_web_acl.this.visibility_config[0].cloudwatch_metrics_enabled == false
    error_message = "CloudWatch metrics should be disabled"
  }
  assert {
    condition     = aws_wafv2_web_acl.this.visibility_config[0].sampled_requests_enabled == false
    error_message = "Sampled requests should be disabled"
  }
}
