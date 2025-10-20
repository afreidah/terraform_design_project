# ----------------------------------------------------------------
# WAF Module Test Suite (plan-safe)
#
# Module under test:
#   - aws_wafv2_web_acl.this
#
# Plan-safe assertions only (avoid computed capacity/ids/arns).
# Focus:
#   - Name, scope, default_action (allow/block)
#   - Presence/absence of managed rules by name
#   - Rate limit value when enabled
#   - Geo blocking rule wiring
#   - Visibility config flags and tags
#   - Outputs that are plan-known (web_acl_name)
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# Shared defaults / mocks
# ----------------------------------------------------------------
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

# ----------------------------------------------------------------
# Baseline: defaults with managed rules, reputation, rate limiting
# ----------------------------------------------------------------
run "baseline_defaults" {
  command = plan

  variables {
    # use defaults above
  }

  # Basic properties
  assert {
    condition     = aws_wafv2_web_acl.this.name == var.name
    error_message = "WebACL name should match input"
  }
  assert {
    condition     = aws_wafv2_web_acl.this.scope == var.scope
    error_message = "WebACL scope should match input"
  }

  # Default action = allow
  assert {
    condition     = try(length(aws_wafv2_web_acl.this.default_action[0].allow), 0) == 1
    error_message = "Default action should be allow"
  }

  # Visibility config flags
  assert {
    condition     = aws_wafv2_web_acl.this.visibility_config[0].cloudwatch_metrics_enabled == true
    error_message = "CloudWatch metrics should be enabled"
  }
  assert {
    condition     = aws_wafv2_web_acl.this.visibility_config[0].sampled_requests_enabled == true
    error_message = "Sampled requests should be enabled"
  }

  # Required managed rule groups present
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

  # Rate limit rule present with correct limit
  assert {
    condition     = length([for r in aws_wafv2_web_acl.this.rule : r if r.name == "RateLimitRule"]) == 1
    error_message = "RateLimitRule should be present"
  }
  assert {
    condition     = try([for r in aws_wafv2_web_acl.this.rule : r.statement[0].rate_based_statement[0].limit if r.name == "RateLimitRule"][0], 0) == var.rate_limit
    error_message = "RateLimitRule limit should match input"
  }

  # Tags
  assert {
    condition     = aws_wafv2_web_acl.this.tags["Name"] == var.name
    error_message = "Name tag should equal WebACL name"
  }
  assert {
    condition     = aws_wafv2_web_acl.this.tags["Env"] == "test"
    error_message = "Env tag should be present"
  }

  # Outputs (plan-known)
  assert {
    condition     = output.web_acl_name == var.name
    error_message = "Output web_acl_name should match input"
  }
}

# ----------------------------------------------------------------
# Default action = block
# ----------------------------------------------------------------
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

# ----------------------------------------------------------------
# Disable AWS managed rules (Common/KnownBad), keep reputation on
# ----------------------------------------------------------------
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

# ----------------------------------------------------------------
# Disable reputation and rate limiting
# ----------------------------------------------------------------
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

# ----------------------------------------------------------------
# Geo blocking enabled with two countries
# ----------------------------------------------------------------
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
  # Check the list length (ordering is not guaranteed)
  assert {
    condition     = try(length([for r in aws_wafv2_web_acl.this.rule : r.statement[0].geo_match_statement[0].country_codes if r.name == "GeoBlockingRule"][0]), 0) == 2
    error_message = "GeoBlockingRule should include two country codes"
  }
}

# ----------------------------------------------------------------
# CloudFront scope variant
# ----------------------------------------------------------------
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

# ----------------------------------------------------------------
# Metrics and sampling disabled variant
# ----------------------------------------------------------------
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
