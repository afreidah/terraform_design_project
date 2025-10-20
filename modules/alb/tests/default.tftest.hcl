# ----------------------------------------------------------------
# ALB Module Test Suite
#
# Tests the Application Load Balancer module for clean plan
# execution with various configurations, conditional HTTPS
# listener creation, HTTP listener behavior, target group
# configuration, and internal vs external ALB deployment.
# ----------------------------------------------------------------

variables {
  # Mock VPC and networking resources
  vpc_id     = "vpc-12345678"
  subnet_ids = ["subnet-11111111", "subnet-22222222", "subnet-33333333"]

  # Mock security group
  security_group_ids = ["sg-12345678"]

  # Mock certificate ARN for HTTPS tests
  test_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
}

# ----------------------------------------------------------------
# Basic ALB without HTTPS certificate
# Expected: HTTP listener forwards to target group (no redirect)
# ----------------------------------------------------------------
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

  # Assert ALB is created
  assert {
    condition     = aws_lb.this.name == "test-alb-basic"
    error_message = "ALB name should match input"
  }

  # Assert ALB is internet-facing
  assert {
    condition     = aws_lb.this.internal == false
    error_message = "ALB should be internet-facing"
  }

  # Assert HTTP listener exists
  assert {
    condition     = aws_lb_listener.http.port == 80
    error_message = "HTTP listener should listen on port 80"
  }

  # Assert HTTP listener forwards (not redirects) when no certificate
  assert {
    condition     = length([for action in aws_lb_listener.http.default_action : action if action.type == "forward"]) > 0
    error_message = "HTTP listener should forward to target group when no certificate provided"
  }

  # Assert HTTPS listener is NOT created
  assert {
    condition     = length(aws_lb_listener.https) == 0
    error_message = "HTTPS listener should not be created without certificate"
  }

  # Assert target group is created
  assert {
    condition     = length(aws_lb_target_group.this) == 1
    error_message = "Should create exactly one target group"
  }

  # Assert target group health check path
  assert {
    condition     = aws_lb_target_group.this["app"].health_check[0].path == "/health"
    error_message = "Target group health check path should match input"
  }
}

# ----------------------------------------------------------------
# ALB with HTTPS certificate
# Expected: HTTP redirects to HTTPS, HTTPS listener created
# ----------------------------------------------------------------
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

  # Assert HTTP listener redirects to HTTPS
  assert {
    condition     = length([for action in aws_lb_listener.http.default_action : action if action.type == "redirect"]) > 0
    error_message = "HTTP listener should redirect to HTTPS when certificate provided"
  }

  # Assert redirect goes to port 443
  assert {
    condition     = try(aws_lb_listener.http.default_action[0].redirect[0].port, "") == "443"
    error_message = "HTTP redirect should target port 443"
  }

  # Assert redirect is permanent (301)
  assert {
    condition     = try(aws_lb_listener.http.default_action[0].redirect[0].status_code, "") == "HTTP_301"
    error_message = "HTTP redirect should use 301 status code"
  }

  # Assert HTTPS listener IS created
  assert {
    condition     = length(aws_lb_listener.https) == 1
    error_message = "HTTPS listener should be created when certificate provided"
  }

  # Assert HTTPS listener uses port 443
  assert {
    condition     = aws_lb_listener.https[0].port == 443
    error_message = "HTTPS listener should use port 443"
  }

  # Assert HTTPS listener uses correct certificate
  assert {
    condition     = aws_lb_listener.https[0].certificate_arn == var.test_certificate_arn
    error_message = "HTTPS listener should use provided certificate"
  }

  # Assert HTTPS listener uses secure TLS policy
  assert {
    condition     = aws_lb_listener.https[0].ssl_policy == "ELBSecurityPolicy-TLS-1-2-2017-01"
    error_message = "HTTPS listener should use TLS 1.2 minimum policy"
  }
}

# ----------------------------------------------------------------
# Internal ALB configuration
# Expected: ALB marked as internal
# ----------------------------------------------------------------
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

  # Assert ALB is internal
  assert {
    condition     = aws_lb.this.internal == true
    error_message = "ALB should be internal when configured"
  }

  # Assert subnets are correctly assigned
  assert {
    condition     = length(aws_lb.this.subnets) == 3
    error_message = "ALB should be deployed across all provided subnets"
  }
}

# ----------------------------------------------------------------
# Multiple target groups
# Expected: All target groups created with correct configuration
# ----------------------------------------------------------------
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

  # Assert both target groups are created
  assert {
    condition     = length(aws_lb_target_group.this) == 2
    error_message = "Should create both target groups"
  }

  # Assert first target group configuration
  assert {
    condition     = aws_lb_target_group.this["app"].port == 8080
    error_message = "App target group should use port 8080"
  }

  assert {
    condition     = aws_lb_target_group.this["app"].target_type == "instance"
    error_message = "App target group should use instance target type"
  }

  # Assert second target group configuration
  assert {
    condition     = aws_lb_target_group.this["api"].port == 8081
    error_message = "API target group should use port 8081"
  }

  assert {
    condition     = aws_lb_target_group.this["api"].target_type == "ip"
    error_message = "API target group should use IP target type"
  }

  # Assert health check paths are different
  assert {
    condition     = aws_lb_target_group.this["api"].health_check[0].path == "/api/health"
    error_message = "API target group should have correct health check path"
  }
}

# ----------------------------------------------------------------
# Target group with stickiness
# Expected: Stickiness configured when provided
# ----------------------------------------------------------------
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

  # Assert stickiness is configured
  assert {
    condition     = aws_lb_target_group.this["app"].stickiness[0].enabled == true
    error_message = "Stickiness should be enabled when configured"
  }

  assert {
    condition     = aws_lb_target_group.this["app"].stickiness[0].cookie_duration == 3600
    error_message = "Cookie duration should match configured value"
  }
}

# ----------------------------------------------------------------
# ALB security settings
# Expected: Secure defaults applied
# ----------------------------------------------------------------
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

  # Assert HTTP/2 is enabled
  assert {
    condition     = aws_lb.this.enable_http2 == true
    error_message = "HTTP/2 should be enabled"
  }

  # Assert invalid headers are dropped
  assert {
    condition     = aws_lb.this.drop_invalid_header_fields == true
    error_message = "Invalid header fields should be dropped for security"
  }

  # Cross-zone load balancing is enabled by default but may be null during plan
  # Skipping assertion as this value is not determinable until apply
}

# ----------------------------------------------------------------
# Target group deregistration delay
# Expected: Custom deregistration delay applied
# ----------------------------------------------------------------
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

  # Assert custom deregistration delay (convert to number for comparison)
  assert {
    condition     = tonumber(aws_lb_target_group.this["app"].deregistration_delay) == 60
    error_message = "Target group should use custom deregistration delay"
  }
}

# ----------------------------------------------------------------
# Verify resource attributes are accessible
# Expected: Core ALB and target group attributes are set
# ----------------------------------------------------------------
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

  # Assert ALB attributes are set
  assert {
    condition     = aws_lb.this.name == "test-alb-attrs"
    error_message = "ALB name should be accessible"
  }

  # Assert target group attributes are set
  assert {
    condition     = aws_lb_target_group.this["app"].port == 8080
    error_message = "Target group port should be accessible"
  }

  # Assert listener attributes are set
  assert {
    condition     = aws_lb_listener.http.port == 80
    error_message = "HTTP listener port should be accessible"
  }

  # Assert HTTPS listener is created with certificate
  assert {
    condition     = length(aws_lb_listener.https) == 1
    error_message = "HTTPS listener should exist when certificate provided"
  }
}
