# -----------------------------------------------------------------------------
# SECURITY GROUP MODULE TEST SUITE
# -----------------------------------------------------------------------------
#
# Plan-safe assertions validating security group creation, rule configuration,
# and tag propagation. Tests avoid equality checks against computed values
# like IDs and ARNs that are unknown at plan time.
#
# Test Coverage:
# Security group creation with VPC association. Ingress rule configuration
# including protocol, port ranges, CIDR blocks, and descriptions. Egress rule
# configuration with support for all protocols. Empty rule sets for security
# groups without traffic rules. Mixed protocol configurations including TCP,
# UDP, and all protocols. Multiple CIDR blocks per rule. Tag propagation.
# Output values known at plan time.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# TEST DEFAULTS AND MOCK VALUES
# -----------------------------------------------------------------------------

variables {
  vpc_id = "vpc-12345678"
  name   = "web-sg"

  tags = {
    Env  = "test"
    Team = "netops"
  }
}

# -----------------------------------------------------------------------------
# BASELINE PUBLIC ALB CONFIGURATION TEST
# -----------------------------------------------------------------------------
# Validates typical ALB security group with HTTP and HTTPS ingress

run "baseline_public_alb" {
  command = plan

  variables {
    ingress_rules = [
      {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "HTTP from anywhere"
      },
      {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "HTTPS from anywhere"
      }
    ]

    egress_rules = [
      {
        from_port   = 0
        to_port     = 65535
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "All TCP egress"
      }
    ]
  }

  # Security group basic configuration
  assert {
    condition     = aws_security_group.this.vpc_id == var.vpc_id
    error_message = "Security group must be created in the provided VPC"
  }
  assert {
    condition     = aws_security_group.this.name == var.name
    error_message = "Security group name should match input"
  }
  assert {
    condition     = aws_security_group.this.tags["Name"] == var.name
    error_message = "Security group Name tag should equal name"
  }
  assert {
    condition     = aws_security_group.this.tags["Env"] == "test"
    error_message = "Security group should carry Env tag"
  }

  # Ingress rules count
  assert {
    condition     = length(aws_security_group_rule.ingress) == 2
    error_message = "Should create two ingress rules (80 and 443)"
  }

  # Ingress rule 0 - HTTP
  assert {
    condition     = aws_security_group_rule.ingress[0].type == "ingress"
    error_message = "Ingress[0] type should be ingress"
  }
  assert {
    condition     = aws_security_group_rule.ingress[0].protocol == "tcp"
    error_message = "Ingress[0] protocol should be tcp"
  }
  assert {
    condition     = aws_security_group_rule.ingress[0].from_port == 80
    error_message = "Ingress[0] from_port should be 80"
  }
  assert {
    condition     = aws_security_group_rule.ingress[0].to_port == 80
    error_message = "Ingress[0] to_port should be 80"
  }
  assert {
    condition     = length(aws_security_group_rule.ingress[0].cidr_blocks) == 1
    error_message = "Ingress[0] should have a single CIDR"
  }
  assert {
    condition     = aws_security_group_rule.ingress[0].cidr_blocks[0] == "0.0.0.0/0"
    error_message = "Ingress[0] CIDR should be 0.0.0.0/0"
  }
  assert {
    condition     = aws_security_group_rule.ingress[0].description == "HTTP from anywhere"
    error_message = "Ingress[0] description mismatch"
  }

  # Ingress rule 1 - HTTPS
  assert {
    condition     = aws_security_group_rule.ingress[1].type == "ingress"
    error_message = "Ingress[1] type should be ingress"
  }
  assert {
    condition     = aws_security_group_rule.ingress[1].protocol == "tcp"
    error_message = "Ingress[1] protocol should be tcp"
  }
  assert {
    condition     = aws_security_group_rule.ingress[1].from_port == 443
    error_message = "Ingress[1] from_port should be 443"
  }
  assert {
    condition     = aws_security_group_rule.ingress[1].to_port == 443
    error_message = "Ingress[1] to_port should be 443"
  }
  assert {
    condition     = length(aws_security_group_rule.ingress[1].cidr_blocks) == 1
    error_message = "Ingress[1] should have a single CIDR"
  }
  assert {
    condition     = aws_security_group_rule.ingress[1].cidr_blocks[0] == "0.0.0.0/0"
    error_message = "Ingress[1] CIDR should be 0.0.0.0/0"
  }
  assert {
    condition     = aws_security_group_rule.ingress[1].description == "HTTPS from anywhere"
    error_message = "Ingress[1] description mismatch"
  }

  # Egress rules
  assert {
    condition     = length(aws_security_group_rule.egress) == 1
    error_message = "Should create one egress rule"
  }
  assert {
    condition     = aws_security_group_rule.egress[0].type == "egress"
    error_message = "Egress[0] type should be egress"
  }
  assert {
    condition     = aws_security_group_rule.egress[0].protocol == "tcp"
    error_message = "Egress[0] protocol should be tcp"
  }
  assert {
    condition     = aws_security_group_rule.egress[0].from_port == 0
    error_message = "Egress[0] from_port should be 0"
  }
  assert {
    condition     = aws_security_group_rule.egress[0].to_port == 65535
    error_message = "Egress[0] to_port should be 65535"
  }
  assert {
    condition     = length(aws_security_group_rule.egress[0].cidr_blocks) == 1
    error_message = "Egress[0] should have a single CIDR"
  }
  assert {
    condition     = aws_security_group_rule.egress[0].cidr_blocks[0] == "0.0.0.0/0"
    error_message = "Egress[0] CIDR should be 0.0.0.0/0"
  }

  # Plan-known output
  assert {
    condition     = output.security_group_name == var.name
    error_message = "Output security_group_name should match input"
  }
}

# -----------------------------------------------------------------------------
# EMPTY RULES TEST
# -----------------------------------------------------------------------------
# Validates security group creation without any traffic rules

run "no_rules" {
  command = plan

  variables {
    name          = "empty-sg"
    ingress_rules = []
    egress_rules  = []
  }

  assert {
    condition     = aws_security_group.this.name == "empty-sg"
    error_message = "SG name should be empty-sg"
  }
  assert {
    condition     = length(aws_security_group_rule.ingress) == 0
    error_message = "No ingress rules should be created"
  }
  assert {
    condition     = length(aws_security_group_rule.egress) == 0
    error_message = "No egress rules should be created"
  }
  assert {
    condition     = output.security_group_name == "empty-sg"
    error_message = "Output security_group_name should be empty-sg"
  }
}

# -----------------------------------------------------------------------------
# MIXED PROTOCOLS TEST
# -----------------------------------------------------------------------------
# Validates multiple protocols with optional descriptions

run "mixed_rules_null_descriptions" {
  command = plan

  variables {
    name = "mixed-sg"
    ingress_rules = [
      {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
      },
      {
        from_port   = 1194
        to_port     = 1194
        protocol    = "udp"
        cidr_blocks = ["192.168.0.0/16"]
        description = "OpenVPN"
      }
    ]
    egress_rules = [
      {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
      }
    ]
  }

  assert {
    condition     = aws_security_group.this.name == "mixed-sg"
    error_message = "SG name should be mixed-sg"
  }

  # Ingress rule 0 - SSH with null description
  assert {
    condition     = aws_security_group_rule.ingress[0].protocol == "tcp"
    error_message = "Ingress[0] protocol should be tcp"
  }
  assert {
    condition     = aws_security_group_rule.ingress[0].from_port == 22
    error_message = "Ingress[0] from_port should be 22"
  }
  assert {
    condition     = aws_security_group_rule.ingress[0].to_port == 22
    error_message = "Ingress[0] to_port should be 22"
  }
  assert {
    condition     = aws_security_group_rule.ingress[0].description == null
    error_message = "Ingress[0] description should be null when omitted"
  }

  # Ingress rule 1 - OpenVPN UDP
  assert {
    condition     = aws_security_group_rule.ingress[1].protocol == "udp"
    error_message = "Ingress[1] protocol should be udp"
  }
  assert {
    condition     = aws_security_group_rule.ingress[1].from_port == 1194
    error_message = "Ingress[1] from_port should be 1194"
  }
  assert {
    condition     = aws_security_group_rule.ingress[1].to_port == 1194
    error_message = "Ingress[1] to_port should be 1194"
  }
  assert {
    condition     = aws_security_group_rule.ingress[1].description == "OpenVPN"
    error_message = "Ingress[1] description mismatch"
  }

  # Egress all protocols
  assert {
    condition     = aws_security_group_rule.egress[0].protocol == "-1"
    error_message = "Egress protocol should allow all (-1)"
  }
  assert {
    condition     = aws_security_group_rule.egress[0].from_port == 0
    error_message = "Egress from_port should be 0"
  }
  assert {
    condition     = aws_security_group_rule.egress[0].to_port == 0
    error_message = "Egress to_port should be 0 for all protocols"
  }
  assert {
    condition     = aws_security_group_rule.egress[0].description == null
    error_message = "Egress description should be null when omitted"
  }

  # Output validation
  assert {
    condition     = output.security_group_name == "mixed-sg"
    error_message = "Output security_group_name should be mixed-sg"
  }
}

# -----------------------------------------------------------------------------
# WIDE OPEN EGRESS TEST
# -----------------------------------------------------------------------------
# Validates typical default egress configuration with multiple CIDRs

run "wide_open_egress" {
  command = plan

  variables {
    name = "egress-any"
    ingress_rules = [
      {
        from_port   = 8080
        to_port     = 8080
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12"]
        description = "App HTTP from RFC1918"
      }
    ]
    egress_rules = [
      {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        description = "All egress"
      }
    ]
    tags = {
      Env  = "stage"
      Team = "netops"
    }
  }

  assert {
    condition     = aws_security_group.this.tags["Env"] == "stage"
    error_message = "Env tag should be stage"
  }
  assert {
    condition     = length(aws_security_group_rule.ingress[0].cidr_blocks) == 2
    error_message = "Ingress CIDR list should contain two entries"
  }
  assert {
    condition     = aws_security_group_rule.egress[0].protocol == "-1"
    error_message = "Egress should allow all protocols"
  }
  assert {
    condition     = output.security_group_name == "egress-any"
    error_message = "Output security_group_name should be egress-any"
  }
}
