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
  description = "Default action (allow or block)"
  type        = string
  default     = "allow"
}

variable "enable_aws_managed_rules" {
  description = "Enable AWS managed rule groups"
  type        = bool
  default     = true
}

variable "enable_rate_limiting" {
  description = "Enable rate limiting"
  type        = bool
  default     = true
}

variable "rate_limit" {
  description = "Rate limit (requests per 5 minutes)"
  type        = number
  default     = 2000
}

variable "enable_geo_blocking" {
  description = "Enable geo blocking"
  type        = bool
  default     = false
}

variable "blocked_countries" {
  description = "List of country codes to block (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
}

variable "enable_ip_reputation" {
  description = "Enable IP reputation lists"
  type        = bool
  default     = true
}

variable "cloudwatch_metrics_enabled" {
  description = "Enable CloudWatch metrics"
  type        = bool
  default     = true
}

variable "sampled_requests_enabled" {
  description = "Enable sampled requests"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
