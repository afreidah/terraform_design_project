# ----------------------------------------------------------------
# Security Groups Module Test Suite (plan-safe)
#
# Module under test:
#   - aws_security_group.this
#   - aws_security_group_rule.ingress (count)
#   - aws_security_group_rule.egress (count)
#
# Notes:
# - Avoid asserting on IDs/ARNs or SG Rule -> SG ID equality at plan time.
# - Keep each assertion to a single simple expression (no multi-line &&).
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# Shared defaults / mocks
# ----------------------------------------------------------------
variables {
  vpc_id = "vpc-12345678"
  name   = "web-sg"

  tags = {
    Env  = "test"
    Team = "netops"
  }
}

# ----------------------------------------------------------------
# Baseline: public ALB-style SG
# Ingress: tcp/80, tcp/443 from 0.0.0.0/0
# Egress: tcp 0-65535 to 0.0.0.0/0
# ----------------------------------------------------------------
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

  # SG basics
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

  # Ingress[0] HTTP
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

  # Ingress[1] HTTPS
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

  # Outputs (plan-known)
  assert {
    condition     = output.security_group_name == var.name
    error_message = "Output security_group_name should match input"
  }
}

# ----------------------------------------------------------------
# No rules: empty ingress/egress
# ----------------------------------------------------------------
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

# ----------------------------------------------------------------
# Mixed protocols and null descriptions
# ----------------------------------------------------------------
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
        # description intentionally omitted -> null
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
        protocol    = "-1" # all protocols
        cidr_blocks = ["0.0.0.0/0"]
        # description omitted -> null
      }
    ]
  }

  assert {
    condition     = aws_security_group.this.name == "mixed-sg"
    error_message = "SG name should be mixed-sg"
  }

  # Ingress[0] SSH
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

  # Ingress[1] OpenVPN UDP
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

  # Output
  assert {
    condition     = output.security_group_name == "mixed-sg"
    error_message = "Output security_group_name should be mixed-sg"
  }
}

# ----------------------------------------------------------------
# Wide-open egress convention (typical default)
# ----------------------------------------------------------------
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
