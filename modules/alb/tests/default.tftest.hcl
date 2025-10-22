# -----------------------------------------------------------------------------
# ALB MODULE - TEST SUITE
# -----------------------------------------------------------------------------
#
# This test suite validates the Application Load Balancer module functionality
# across various configuration scenarios. Tests use Terraform's native testing
# framework to verify resource creation, conditional logic, and configuration
# correctness without requiring actual AWS infrastructure deployment.
#
# Test Categories:
#   - Basic Configuration: ALB creation without HTTPS
#   - HTTPS Configuration: Certificate-based HTTPS listener and redirects
#   - Internal vs External: Network visibility settings
#   - Target Groups: Multiple target group configurations
#   - Advanced Features: Stickiness, deregistration delay, security settings
#   - Resource Validation: Attribute accessibility and output verification
#
# Testing Approach:
#   - Uses terraform plan to validate resource configuration
#   - Mock values for VPC, subnets, and security groups
#   - Assertions verify expected behavior without AWS API calls
#   - Tests conditional resource creation (HTTPS listener, redirects)
#
# IMPORTANT:
#   - Tests run in plan mode only (no actual infrastructure created)
#   - Mock values must be syntactically valid AWS resource IDs
#   - Assertions validate Terraform configuration, not runtime behavior
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# TEST VARIABLES
# -----------------------------------------------------------------------------

# Mock AWS resources for testing
# These values simulate actual AWS resource IDs without requiring real infrastructure
variables {
  # Mock VPC and networking resources
  vpc_id     = "vpc-12345678"
  subnet_ids = ["subnet-11111111", "subnet-22222222", "subnet-33333333"]

  # Mock security group
  security_group_ids = ["sg-12345678"]

  # Mock certificate ARN for HTTPS tests
  test_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
}

# -----------------------------------------------------------------------------
# BASIC ALB WITHOUT HTTPS CERTIFICATE
# -----------------------------------------------------------------------------

# Validates basic ALB creation with HTTP-only configuration
# Expected Behavior:
#   - ALB created as internet-facing
#   - HTTP listener forwards to target group (no redirect)
#   - HTTPS listener NOT created
#   - Target group created with health check configuration
run "basic_alb_without_https" {
  command = plan

  variables {
    name               = "test-alb-basic"
    internal           = false
    vpc_id             = var.vpc_id
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
    certificate_arn    = null

    target_groups = {
      app = {
        port        = 8080
        protocol    = "HTTP"
        target_type = "instance"
        health_check = {
          path     = "/health"
          protocol = "HTTP"
        }
      }
    }
  }

  # -------------------------------------------------------------------------
  # ALB CONFIGURATION ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify ALB name matches input
  assert {
    condition     = aws_lb.this.name == "test-alb-basic"
    error_message = "ALB name should match input"
  }

  # Verify ALB is internet-facing
  assert {
    condition     = aws_lb.this.internal == false
    error_message = "ALB should be internet-facing"
  }

  # -------------------------------------------------------------------------
  # HTTP LISTENER ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify HTTP listener exists on port 80
  assert {
    condition     = aws_lb_listener.http.port == 80
    error_message = "HTTP listener should listen on port 80"
  }

  # Verify HTTP listener forwards (not redirects) when no certificate
  assert {
    condition     = length([for action in aws_lb_listener.http.default_action : action if action.type == "forward"]) > 0
    error_message = "HTTP listener should forward to target group when no certificate provided"
  }

  # -------------------------------------------------------------------------
  # HTTPS LISTENER ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify HTTPS listener is NOT created without certificate
  assert {
    condition     = length(aws_lb_listener.https) == 0
    error_message = "HTTPS listener should not be created without certificate"
  }

  # -------------------------------------------------------------------------
  # TARGET GROUP ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify target group creation
  assert {
    condition     = length(aws_lb_target_group.this) == 1
    error_message = "Should create exactly one target group"
  }

  # Verify target group health check path
  assert {
    condition     = aws_lb_target_group.this["app"].health_check[0].path == "/health"
    error_message = "Target group health check path should match input"
  }
}

# -----------------------------------------------------------------------------
# ALB WITH HTTPS CERTIFICATE
# -----------------------------------------------------------------------------

# Validates ALB with HTTPS configuration
# Expected Behavior:
#   - HTTP listener redirects to HTTPS (301 permanent)
#   - HTTPS listener created on port 443
#   - Certificate attached to HTTPS listener
#   - TLS 1.2 minimum security policy enforced
run "alb_with_https_certificate" {
  command = plan

  variables {
    name               = "test-alb-https"
    internal           = false
    vpc_id             = var.vpc_id
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
    certificate_arn    = var.test_certificate_arn

    target_groups = {
      app = {
        port        = 8080
        protocol    = "HTTP"
        target_type = "instance"
        health_check = {
          path = "/health"
        }
      }
    }
  }

  # -------------------------------------------------------------------------
  # HTTP REDIRECT ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify HTTP listener redirects to HTTPS
  assert {
    condition     = length([for action in aws_lb_listener.http.default_action : action if action.type == "redirect"]) > 0
    error_message = "HTTP listener should redirect to HTTPS when certificate provided"
  }

  # Verify redirect targets port 443
  assert {
    condition     = try(aws_lb_listener.http.default_action[0].redirect[0].port, "") == "443"
    error_message = "HTTP redirect should target port 443"
  }

  # Verify redirect is permanent (301)
  assert {
    condition     = try(aws_lb_listener.http.default_action[0].redirect[0].status_code, "") == "HTTP_301"
    error_message = "HTTP redirect should use 301 status code"
  }

  # -------------------------------------------------------------------------
  # HTTPS LISTENER ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify HTTPS listener IS created
  assert {
    condition     = length(aws_lb_listener.https) == 1
    error_message = "HTTPS listener should be created when certificate provided"
  }

  # Verify HTTPS listener uses port 443
  assert {
    condition     = aws_lb_listener.https[0].port == 443
    error_message = "HTTPS listener should use port 443"
  }

  # Verify HTTPS listener uses correct certificate
  assert {
    condition     = aws_lb_listener.https[0].certificate_arn == var.test_certificate_arn
    error_message = "HTTPS listener should use provided certificate"
  }

  # Verify HTTPS listener uses secure TLS policy
  assert {
    condition     = aws_lb_listener.https[0].ssl_policy == "ELBSecurityPolicy-TLS-1-2-2017-01"
    error_message = "HTTPS listener should use TLS 1.2 minimum policy"
  }
}

# -----------------------------------------------------------------------------
# INTERNAL ALB CONFIGURATION
# -----------------------------------------------------------------------------

# Validates internal ALB for private network access
# Expected Behavior:
#   - ALB marked as internal
#   - Deployed across all provided subnets
run "internal_alb" {
  command = plan

  variables {
    name               = "test-alb-internal"
    internal           = true
    vpc_id             = var.vpc_id
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids

    target_groups = {
      backend = {
        port         = 8080
        protocol     = "HTTP"
        target_type  = "instance"
        health_check = {}
      }
    }
  }

  # -------------------------------------------------------------------------
  # INTERNAL ALB ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify ALB is internal
  assert {
    condition     = aws_lb.this.internal == true
    error_message = "ALB should be internal when configured"
  }

  # Verify subnets are correctly assigned
  assert {
    condition     = length(aws_lb.this.subnets) == 3
    error_message = "ALB should be deployed across all provided subnets"
  }
}

# -----------------------------------------------------------------------------
# MULTIPLE TARGET GROUPS
# -----------------------------------------------------------------------------

# Validates multiple target group creation with different configurations
# Expected Behavior:
#   - All target groups created with unique configurations
#   - Each target group has independent health check settings
#   - Target types (instance vs IP) correctly configured
run "multiple_target_groups" {
  command = plan

  variables {
    name               = "test-alb-multi-tg"
    internal           = false
    vpc_id             = var.vpc_id
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids

    target_groups = {
      app = {
        port        = 8080
        protocol    = "HTTP"
        target_type = "instance"
        health_check = {
          path = "/health"
        }
      }
      api = {
        port        = 8081
        protocol    = "HTTP"
        target_type = "ip"
        health_check = {
          path = "/api/health"
        }
      }
    }
  }

  # -------------------------------------------------------------------------
  # TARGET GROUP COUNT ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify both target groups are created
  assert {
    condition     = length(aws_lb_target_group.this) == 2
    error_message = "Should create both target groups"
  }

  # -------------------------------------------------------------------------
  # APP TARGET GROUP ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify app target group configuration
  assert {
    condition     = aws_lb_target_group.this["app"].port == 8080
    error_message = "App target group should use port 8080"
  }

  assert {
    condition     = aws_lb_target_group.this["app"].target_type == "instance"
    error_message = "App target group should use instance target type"
  }

  # -------------------------------------------------------------------------
  # API TARGET GROUP ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify API target group configuration
  assert {
    condition     = aws_lb_target_group.this["api"].port == 8081
    error_message = "API target group should use port 8081"
  }

  assert {
    condition     = aws_lb_target_group.this["api"].target_type == "ip"
    error_message = "API target group should use IP target type"
  }

  # Verify health check paths are different
  assert {
    condition     = aws_lb_target_group.this["api"].health_check[0].path == "/api/health"
    error_message = "API target group should have correct health check path"
  }
}

# -----------------------------------------------------------------------------
# TARGET GROUP WITH STICKINESS
# -----------------------------------------------------------------------------

# Validates session stickiness configuration
# Expected Behavior:
#   - Stickiness enabled when configured
#   - Cookie duration matches specified value
run "target_group_stickiness" {
  command = plan

  variables {
    name               = "test-alb-sticky"
    internal           = false
    vpc_id             = var.vpc_id
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids

    target_groups = {
      app = {
        port         = 8080
        protocol     = "HTTP"
        target_type  = "instance"
        health_check = {}
        stickiness = {
          enabled         = true
          type            = "lb_cookie"
          cookie_duration = 3600
        }
      }
    }
  }

  # -------------------------------------------------------------------------
  # STICKINESS ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify stickiness is configured
  assert {
    condition     = aws_lb_target_group.this["app"].stickiness[0].enabled == true
    error_message = "Stickiness should be enabled when configured"
  }

  assert {
    condition     = aws_lb_target_group.this["app"].stickiness[0].cookie_duration == 3600
    error_message = "Cookie duration should match configured value"
  }
}

# -----------------------------------------------------------------------------
# ALB SECURITY SETTINGS
# -----------------------------------------------------------------------------

# Validates security-related ALB configuration
# Expected Behavior:
#   - HTTP/2 enabled for performance
#   - Invalid header fields dropped for security
run "security_settings" {
  command = plan

  variables {
    name                       = "test-alb-security"
    internal                   = false
    vpc_id                     = var.vpc_id
    subnet_ids                 = var.subnet_ids
    security_group_ids         = var.security_group_ids
    drop_invalid_header_fields = true
    enable_http2               = true

    target_groups = {
      app = {
        port         = 8080
        protocol     = "HTTP"
        target_type  = "instance"
        health_check = {}
      }
    }
  }

  # -------------------------------------------------------------------------
  # SECURITY FEATURE ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify HTTP/2 is enabled
  assert {
    condition     = aws_lb.this.enable_http2 == true
    error_message = "HTTP/2 should be enabled"
  }

  # Verify invalid headers are dropped
  assert {
    condition     = aws_lb.this.drop_invalid_header_fields == true
    error_message = "Invalid header fields should be dropped for security"
  }

  # Note: Cross-zone load balancing is enabled by default but may be null
  # during plan phase, so we skip assertion as value is not determinable
  # until apply
}

# -----------------------------------------------------------------------------
# CUSTOM DEREGISTRATION DELAY
# -----------------------------------------------------------------------------

# Validates custom deregistration delay configuration
# Expected Behavior:
#   - Target group uses specified deregistration delay
run "custom_deregistration_delay" {
  command = plan

  variables {
    name               = "test-alb-dereg"
    internal           = false
    vpc_id             = var.vpc_id
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids

    target_groups = {
      app = {
        port                 = 8080
        protocol             = "HTTP"
        target_type          = "instance"
        deregistration_delay = 60
        health_check         = {}
      }
    }
  }

  # -------------------------------------------------------------------------
  # DEREGISTRATION DELAY ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify custom deregistration delay (convert to number for comparison)
  assert {
    condition     = tonumber(aws_lb_target_group.this["app"].deregistration_delay) == 60
    error_message = "Target group should use custom deregistration delay"
  }
}

# -----------------------------------------------------------------------------
# RESOURCE ATTRIBUTE VERIFICATION
# -----------------------------------------------------------------------------

# Validates that all resource attributes are accessible
# Expected Behavior:
#   - ALB attributes are set and accessible
#   - Target group attributes are set and accessible
#   - Listener attributes are set and accessible
run "verify_resource_attributes" {
  command = plan

  variables {
    name               = "test-alb-attrs"
    internal           = false
    vpc_id             = var.vpc_id
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
    certificate_arn    = var.test_certificate_arn

    target_groups = {
      app = {
        port         = 8080
        protocol     = "HTTP"
        target_type  = "instance"
        health_check = {}
      }
    }
  }

  # -------------------------------------------------------------------------
  # ATTRIBUTE ACCESSIBILITY ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify ALB attributes are set
  assert {
    condition     = aws_lb.this.name == "test-alb-attrs"
    error_message = "ALB name should be accessible"
  }

  # Verify target group attributes are set
  assert {
    condition     = aws_lb_target_group.this["app"].port == 8080
    error_message = "Target group port should be accessible"
  }

  # Verify HTTP listener attributes are set
  assert {
    condition     = aws_lb_listener.http.port == 80
    error_message = "HTTP listener port should be accessible"
  }

  # Verify HTTPS listener is created with certificate
  assert {
    condition     = length(aws_lb_listener.https) == 1
    error_message = "HTTPS listener should exist when certificate provided"
  }
}
