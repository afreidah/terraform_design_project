# -----------------------------------------------------------------------------
# ALB MODULE - INPUT VARIABLES
# -----------------------------------------------------------------------------
#
# This file defines all configurable parameters for the Application Load
# Balancer module, including ALB configuration, target group settings,
# listener options, and security features.
#
# Variable Categories:
#   - Core Configuration: Name, VPC, networking, and internal/external setting
#   - Security: Security groups, header filtering, certificate
#   - Performance: HTTP/2, cross-zone load balancing, timeouts
#   - Target Groups: Backend configuration with health checks and stickiness
#   - Logging: Access logs configuration
#   - Protection: Deletion protection, WAF integration
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# CORE CONFIGURATION
# -----------------------------------------------------------------------------

variable "name" {
  description = "Name of the ALB"
  type        = string
}

variable "internal" {
  description = "Whether the ALB is internal or internet-facing"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID where ALB will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ALB"
  type        = list(string)
}

# -----------------------------------------------------------------------------
# SECURITY CONFIGURATION
# -----------------------------------------------------------------------------

variable "security_group_ids" {
  description = "List of security group IDs for the ALB"
  type        = list(string)
}

variable "drop_invalid_header_fields" {
  description = "Drop invalid HTTP header fields"
  type        = bool
  default     = true
}

variable "certificate_arn" {
  description = "ARN of SSL certificate for HTTPS listener"
  type        = string
  default     = null
}

variable "waf_web_acl_arn" {
  description = "ARN of the WAF WebACL to associate with the ALB"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# PERFORMANCE & AVAILABILITY
# -----------------------------------------------------------------------------

variable "enable_http2" {
  description = "Enable HTTP/2 on the ALB"
  type        = bool
  default     = true
}

variable "enable_cross_zone_load_balancing" {
  description = "Enable cross-zone load balancing"
  type        = bool
  default     = true
}

variable "idle_timeout" {
  description = "Time in seconds that the connection is allowed to be idle"
  type        = number
  default     = 60
}

# -----------------------------------------------------------------------------
# PROTECTION & LIFECYCLE
# -----------------------------------------------------------------------------

variable "enable_deletion_protection" {
  description = "Enable deletion protection on the ALB"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# ACCESS LOGGING
# -----------------------------------------------------------------------------

variable "access_logs_enabled" {
  description = "Enable ALB access logging"
  type        = bool
  default     = false
}

variable "access_logs_bucket" {
  description = "S3 bucket for ALB access logs"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# TARGET GROUPS
# -----------------------------------------------------------------------------

# Target group configuration with health checks and stickiness
# Supports multiple target groups with independent configurations
variable "target_groups" {
  description = "Map of target group configurations"
  type = map(object({
    port                 = number
    protocol             = string
    target_type          = string
    deregistration_delay = optional(number, 300)
    health_check = object({
      enabled             = optional(bool, true)
      healthy_threshold   = optional(number, 3)
      interval            = optional(number, 30)
      matcher             = optional(string, "200")
      path                = optional(string, "/")
      port                = optional(string, "traffic-port")
      protocol            = optional(string, "HTTP")
      timeout             = optional(number, 5)
      unhealthy_threshold = optional(number, 3)
    })
    stickiness = optional(object({
      enabled         = optional(bool, false)
      type            = optional(string, "lb_cookie")
      cookie_duration = optional(number, 86400)
    }))
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# TAGGING
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
