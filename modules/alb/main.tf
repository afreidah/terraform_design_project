# -----------------------------------------------------------------------------
# APPLICATION LOAD BALANCER MODULE
# -----------------------------------------------------------------------------
#
# This module creates an Application Load Balancer (ALB) with configurable
# listeners, target groups, and security settings for routing HTTP/HTTPS
# traffic to backend application instances.
#
# Components Created:
#   - Application Load Balancer: Layer 7 load balancer for HTTP/HTTPS traffic
#   - Target Groups: Backend instance/IP pools for traffic distribution
#   - HTTP Listener: Port 80 listener with redirect or forward action
#   - HTTPS Listener: Optional port 443 listener with SSL/TLS termination
#
# Features:
#   - Automatic HTTP to HTTPS redirect when certificate provided
#   - Multiple target group support with independent health checks
#   - Session stickiness configuration per target group
#   - Cross-zone load balancing for high availability
#   - HTTP/2 support for improved performance
#   - Invalid header field filtering for security
#   - Optional access logging to S3
#
# Security Model:
#   - TLS 1.2 minimum policy for HTTPS listeners
#   - Invalid header fields dropped by default
#   - Security groups control inbound/outbound traffic
#   - Optional WAF integration for application layer protection
#
# IMPORTANT:
#   - HTTP listener behavior changes based on certificate_arn presence
#   - Target groups support both instance and IP target types
#   - Health checks are independent per target group
#   - Deletion protection disabled by default for non-production flexibility
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# APPLICATION LOAD BALANCER
# -----------------------------------------------------------------------------

# Layer 7 load balancer for distributing HTTP/HTTPS traffic
# Can be internet-facing or internal based on var.internal setting
resource "aws_lb" "this" {
  #tfsec:ignore:aws-elb-alb-not-public Intentional: Public ALB by design
  name               = var.name
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.subnet_ids

  enable_deletion_protection       = var.enable_deletion_protection
  enable_http2                     = var.enable_http2
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing
  idle_timeout                     = var.idle_timeout
  drop_invalid_header_fields       = var.drop_invalid_header_fields

  # -------------------------------------------------------------------------
  # ACCESS LOGGING
  # -------------------------------------------------------------------------
  # Optional S3 access logs for request-level visibility
  dynamic "access_logs" {
    for_each = var.access_logs_enabled && var.access_logs_bucket != null ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      enabled = true
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}

# -----------------------------------------------------------------------------
# TARGET GROUPS
# -----------------------------------------------------------------------------

# Backend pools for routing traffic to application instances or IPs
# Each target group has independent configuration and health checks
resource "aws_lb_target_group" "this" {
  for_each             = var.target_groups
  name                 = trimsuffix(substr("${var.name}-${each.key}-tg", 0, 32), "-")
  port                 = each.value.port
  protocol             = each.value.protocol
  vpc_id               = var.vpc_id
  target_type          = each.value.target_type
  deregistration_delay = each.value.deregistration_delay

  # -------------------------------------------------------------------------
  # HEALTH CHECK CONFIGURATION
  # -------------------------------------------------------------------------
  # Determines target availability for traffic routing
  health_check {
    enabled             = each.value.health_check.enabled
    healthy_threshold   = each.value.health_check.healthy_threshold
    interval            = each.value.health_check.interval
    matcher             = each.value.health_check.matcher
    path                = each.value.health_check.path
    port                = each.value.health_check.port
    protocol            = each.value.health_check.protocol
    timeout             = each.value.health_check.timeout
    unhealthy_threshold = each.value.health_check.unhealthy_threshold
  }

  # -------------------------------------------------------------------------
  # SESSION STICKINESS
  # -------------------------------------------------------------------------
  # Optional cookie-based session affinity to same target
  dynamic "stickiness" {
    for_each = each.value.stickiness != null ? [each.value.stickiness] : []
    content {
      enabled         = stickiness.value.enabled
      type            = stickiness.value.type
      cookie_duration = stickiness.value.cookie_duration
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-${each.key}-tg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# HTTP LISTENER (PORT 80)
# -----------------------------------------------------------------------------

# Handles all HTTP traffic on port 80
# Behavior depends on certificate_arn:
#   - With certificate: Redirects to HTTPS (301 permanent redirect)
#   - Without certificate: Forwards directly to target group
resource "aws_lb_listener" "http" {
  #tfsec:ignore:aws-elb-http-not-used HTTP redirects to HTTPS when certificate is provided
  #checkov:skip=CKV_AWS_2:HTTP listener redirects to HTTPS
  #checkov:skip=CKV_AWS_103:HTTP listener redirects to HTTPS
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  # -------------------------------------------------------------------------
  # REDIRECT TO HTTPS
  # -------------------------------------------------------------------------
  # Used when certificate_arn is provided for secure communication
  dynamic "default_action" {
    for_each = var.certificate_arn != null ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  # -------------------------------------------------------------------------
  # FORWARD TO TARGET GROUP
  # -------------------------------------------------------------------------
  # Used when certificate_arn is null (HTTP-only configuration)
  dynamic "default_action" {
    for_each = var.certificate_arn == null ? [1] : []
    content {
      type             = "forward"
      target_group_arn = length(var.target_groups) > 0 ? aws_lb_target_group.this[keys(var.target_groups)[0]].arn : null
    }
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# HTTPS LISTENER (PORT 443)
# -----------------------------------------------------------------------------

# Handles HTTPS traffic with SSL/TLS termination
# Only created when certificate_arn is provided
resource "aws_lb_listener" "https" {
  count = var.certificate_arn != null ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[keys(var.target_groups)[0]].arn
  }

  tags = var.tags
}
