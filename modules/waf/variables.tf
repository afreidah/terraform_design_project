# -----------------------------------------------------------------------------
# WAF MODULE VARIABLES
# -----------------------------------------------------------------------------

variable "name" {
  description = "Name of the WAF WebACL"
  type        = string
}

variable "scope" {
  description = "Scope of the WAF (REGIONAL for ALB/API Gateway, CLOUDFRONT for CloudFront)"
  type        = string
  default     = "REGIONAL"
}

variable "default_action" {
  description = "Default action for requests that do not match any rules (allow or block)"
  type        = string
  default     = "allow"
}

variable "enable_aws_managed_rules" {
  description = "Enable AWS managed rule groups for common vulnerabilities and bad inputs"
  type        = bool
  default     = true
}

variable "enable_rate_limiting" {
  description = "Enable rate limiting to prevent request flooding"
  type        = bool
  default     = true
}

variable "rate_limit" {
  description = "Maximum number of requests allowed per 5 minutes from a single IP"
  type        = number
  default     = 2000
}

variable "enable_geo_blocking" {
  description = "Enable geographic blocking based on country codes"
  type        = bool
  default     = false
}

variable "blocked_countries" {
  description = "List of country codes to block using ISO 3166-1 alpha-2 format"
  type        = list(string)
  default     = []
}

variable "enable_ip_reputation" {
  description = "Enable AWS IP reputation lists to block known malicious sources"
  type        = bool
  default     = true
}

variable "cloudwatch_metrics_enabled" {
  description = "Enable CloudWatch metrics for monitoring WAF activity"
  type        = bool
  default     = true
}

variable "sampled_requests_enabled" {
  description = "Enable sampling of requests for analysis and troubleshooting"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to the WAF WebACL"
  type        = map(string)
  default     = {}
}
