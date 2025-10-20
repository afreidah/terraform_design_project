# ----------------------------------------------------------------
# General Networking Module Test Suite
#
# Tests the VPC, subnets (public/private-app/private-data),
# IGW, NAT gateways, route tables, routes, and associations.
# Verifies per-AZ resource counts, routing behavior (IGW/NAT)
# via plan-known invariants (no ID equality), tagging/naming,
# and output shapes.
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# Test Defaults / Mocks
# ----------------------------------------------------------------
variables {
  # Core VPC inputs
  vpc_cidr = "10.0.0.0/16"
  vpc_name = "test-net"

  # Three AZ layout
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  # Subnet CIDRs (aligned with AZ ordering)
  public_subnet_cidrs = [
    "10.0.0.0/20",
    "10.0.16.0/20",
    "10.0.32.0/20",
  ]

  private_app_subnet_cidrs = [
    "10.0.64.0/20",
    "10.0.80.0/20",
    "10.0.96.0/20",
  ]

  private_data_subnet_cidrs = [
    "10.0.128.0/20",
    "10.0.144.0/20",
    "10.0.160.0/20",
  ]

  # NAT enabled by default in most tests
  enable_nat_gateway = true

  # Tags applied everywhere
  tags = {
    "Env"  = "test"
    "Team" = "neteng"
  }
}

# ----------------------------------------------------------------
# Baseline: VPC, Subnets, IGW, NAT, Routes (3 AZ)
# Expected: All core resources present with correct counts & wiring
#           (assert only plan-known values)
# ----------------------------------------------------------------
run "baseline_three_az" {
  command = plan

  variables {
    # use test defaults
  }

  # ----- VPC -----
  assert {
    condition     = aws_vpc.main.cidr_block == var.vpc_cidr
    error_message = "VPC CIDR should match input"
  }
  assert {
    condition     = aws_vpc.main.enable_dns_hostnames == true && aws_vpc.main.enable_dns_support == true
    error_message = "VPC DNS hostnames/support should be enabled"
  }

  # ----- Internet Gateway -----
  # Assert via plan-known tag (avoid IDs/attachments)
  assert {
    condition     = startswith(aws_internet_gateway.main.tags["Name"], "${var.vpc_name}-")
    error_message = "IGW Name tag should be prefixed with vpc_name"
  }

  # ----- Subnets: counts per tier -----
  assert {
    condition     = length(aws_subnet.public) == length(var.availability_zones)
    error_message = "Should create a public subnet per AZ"
  }
  assert {
    condition     = length(aws_subnet.private_app) == length(var.availability_zones)
    error_message = "Should create a private-app subnet per AZ"
  }
  assert {
    condition     = length(aws_subnet.private_data) == length(var.availability_zones)
    error_message = "Should create a private-data subnet per AZ"
  }

  # ----- Subnet basics -----
  assert {
    condition     = aws_subnet.public[0].map_public_ip_on_launch == true
    error_message = "Public subnets should map public IPs on launch"
  }

  # ----- NAT: one per AZ (HA) -----
  assert {
    condition     = length(aws_eip.nat) == length(var.availability_zones)
    error_message = "Should allocate one EIP per NAT"
  }
  assert {
    condition     = length(aws_nat_gateway.main) == length(var.availability_zones)
    error_message = "Should create one NAT per AZ for HA"
  }

  # ----- Route tables & routes -----
  # Public RT present (avoid ID equality)
  assert {
    condition     = aws_route_table.public.tags["Name"] == "${var.vpc_name}-public-rt"
    error_message = "Public route table should have expected Name tag"
  }
  # Public default route to 0.0.0.0/0 (do not assert gateway_id)
  assert {
    condition     = aws_route.public_internet.destination_cidr_block == "0.0.0.0/0"
    error_message = "Public route must send 0.0.0.0/0"
  }

  # Private-app: one RT per AZ, each should have a default route resource
  assert {
    condition     = length(aws_route_table.private_app) == length(var.availability_zones)
    error_message = "Should create a private-app route table per AZ"
  }
  assert {
    condition     = length(aws_route.private_app_nat) == length(var.availability_zones)
    error_message = "Should create a default route per private-app RT"
  }
  assert {
    condition     = aws_route.private_app_nat[0].destination_cidr_block == "0.0.0.0/0"
    error_message = "Private-app AZ[0] default route should target 0.0.0.0/0"
  }

  # Private-data: single shared RT with default route (avoid NAT IDs)
  assert {
    condition     = aws_route_table.private_data.tags["Name"] == "${var.vpc_name}-private-data-rt"
    error_message = "Private-data route table should have the expected Name tag"
  }
  assert {
    condition     = length(aws_route.private_data_nat) == 1
    error_message = "Private-data should have exactly one default route"
  }
  assert {
    condition     = aws_route.private_data_nat[0].destination_cidr_block == "0.0.0.0/0"
    error_message = "Private-data default route should target 0.0.0.0/0"
  }

  # ----- Associations -----
  assert {
    condition     = length(aws_route_table_association.public) == length(var.availability_zones)
    error_message = "All public subnets should associate with public RT"
  }
  assert {
    condition     = length(aws_route_table_association.private_app) == length(var.availability_zones)
    error_message = "All private-app subnets should associate with their RTs"
  }
  assert {
    condition     = length(aws_route_table_association.private_data) == length(var.availability_zones)
    error_message = "All private-data subnets should associate with the shared RT"
  }
}

# ----------------------------------------------------------------
# Tagging & Naming
# Expected: Subnets and gateways carry merged tags and Name/Tier
# ----------------------------------------------------------------
run "tagging_and_naming" {
  command = plan

  variables {
    # use test defaults
  }

  # Public subnet Tier/Name
  assert {
    condition     = aws_subnet.public[0].tags["Tier"] == "public"
    error_message = "Public subnet should have Tier=public"
  }
  assert {
    condition     = length(aws_subnet.public[0].tags["Name"]) > 0
    error_message = "Public subnet should have a Name tag"
  }

  # Private-app subnet Tier/Name
  assert {
    condition     = aws_subnet.private_app[1].tags["Tier"] == "private-app"
    error_message = "Private-app subnet should have Tier=private-app"
  }
  assert {
    condition     = length(aws_subnet.private_app[1].tags["Name"]) > 0
    error_message = "Private-app subnet should have a Name tag"
  }

  # Private-data subnet Tier/Name
  assert {
    condition     = aws_subnet.private_data[2].tags["Tier"] == "private-data"
    error_message = "Private-data subnet should have Tier=private-data"
  }
  assert {
    condition     = length(aws_subnet.private_data[2].tags["Name"]) > 0
    error_message = "Private-data subnet should have a Name tag"
  }

  # IGW Name pattern includes vpc_name
  assert {
    condition     = startswith(aws_internet_gateway.main.tags["Name"], "${var.vpc_name}-")
    error_message = "IGW Name tag should be prefixed with vpc_name"
  }
}

# ----------------------------------------------------------------
# Outputs (enabled NAT)
# Expected: Output values align with resource list sizes (plan-known)
# ----------------------------------------------------------------
run "outputs_enabled_nat" {
  command = plan

  variables {
    # use test defaults (enable_nat_gateway = true)
  }

  # Subnet ID lists should mirror counts
  assert {
    condition     = length(output.public_subnet_ids) == length(var.availability_zones)
    error_message = "public_subnet_ids output should include all public subnets"
  }
  assert {
    condition     = length(output.private_app_subnet_ids) == length(var.availability_zones)
    error_message = "private_app_subnet_ids output should include all private-app subnets"
  }
  assert {
    condition     = length(output.private_data_subnet_ids) == length(var.availability_zones)
    error_message = "private_data_subnet_ids output should include all private-data subnets"
  }

  # NAT gateways output (enabled): length equals AZ count
  assert {
    condition     = length(output.nat_gateway_ids) == length(var.availability_zones)
    error_message = "nat_gateway_ids output should include one ID per AZ when enabled"
  }

  # Availability zones passthrough
  assert {
    condition     = length(output.availability_zones) == length(var.availability_zones)
    error_message = "availability_zones output should match input length"
  }
}

# ----------------------------------------------------------------
# Outputs (disabled NAT)
# Expected: NAT output is empty list when enable_nat_gateway=false
# ----------------------------------------------------------------
run "outputs_disabled_nat" {
  command = plan

  variables {
    enable_nat_gateway = false
  }

  assert {
    condition     = length(output.nat_gateway_ids) == 0
    error_message = "nat_gateway_ids output should be empty when NAT is disabled"
  }
}

# ----------------------------------------------------------------
# Routing Specifics
# Expected: Public 0/0 -> exists, Private-app 0/0 -> exists per AZ,
#           Private-data 0/0 -> exists (shared RT)
#           (No ID equality; only destination invariants)
# ----------------------------------------------------------------
run "routing_specifics" {
  command = plan

  variables {
    # use test defaults
  }

  # Public default route
  assert {
    condition     = aws_route.public_internet.destination_cidr_block == "0.0.0.0/0"
    error_message = "Public route table must route 0.0.0.0/0"
  }

  # Private-app: spot-check AZ[2] default route exists
  assert {
    condition     = aws_route.private_app_nat[2].destination_cidr_block == "0.0.0.0/0"
    error_message = "AZ-2 private-app default route should target 0.0.0.0/0"
  }

  # Private-data: shared RT has default route
  assert {
    condition     = aws_route.private_data_nat[0].destination_cidr_block == "0.0.0.0/0"
    error_message = "Private-data should route 0.0.0.0/0"
  }
}

