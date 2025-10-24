# -----------------------------------------------------------------------------
# VPC / GENERAL NETWORKING MODULE - TEST SUITE
# -----------------------------------------------------------------------------
#
# This test suite validates the VPC and networking module functionality across
# various configuration scenarios. Tests use Terraform's native testing framework
# to verify resource creation, subnet architecture, routing behavior, and output
# correctness without requiring actual AWS infrastructure deployment.
#
# Test Categories:
#   - Baseline Configuration: VPC, subnets, IGW, NAT, routes (3 AZ)
#   - Tagging & Naming: Resource tag validation and naming conventions
#   - Outputs: Subnet IDs, route tables, and resource counts
#   - NAT Gateway Configurations: Enabled vs disabled scenarios
#   - Routing Specifics: Route table and route configuration validation
#
# Testing Approach:
#   - Uses terraform plan to validate resource configuration
#   - Mock values for VPC CIDR, subnets, and availability zones
#   - Assertions verify expected behavior without AWS API calls
#   - Tests three-tier subnet architecture across multiple AZs
#
# IMPORTANT:
#   - Tests run in plan mode only (no actual infrastructure created)
#   - Mock values must be syntactically valid CIDR blocks
#   - Assertions validate Terraform configuration, not runtime behavior
#   - Tests verify per-AZ resource distribution and HA patterns
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# TEST DEFAULTS / MOCKS
# -----------------------------------------------------------------------------

# Mock VPC and subnet configuration for testing
# These values simulate production VPC layout without requiring real AWS resources
variables {
  # Core VPC inputs
  vpc_cidr = "10.0.0.0/16"
  vpc_name = "test-net"

  # Three AZ layout for high availability
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

# -----------------------------------------------------------------------------
# BASELINE: VPC, SUBNETS, IGW, NAT, ROUTES (3 AZ)
# -----------------------------------------------------------------------------

# Validates complete VPC stack creation with three-tier architecture
# Expected Behavior:
#   - VPC created with DNS support
#   - Three subnets per tier (public, private-app, private-data)
#   - One NAT Gateway per AZ for high availability
#   - Route tables properly configured for each tier
#   - All associations created correctly
run "baseline_three_az" {
  command = plan

  variables {
    # use test defaults
  }

  # -------------------------------------------------------------------------
  # VPC ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify VPC CIDR matches input
  assert {
    condition     = aws_vpc.main.cidr_block == var.vpc_cidr
    error_message = "VPC CIDR should match input"
  }

  # Verify DNS settings enabled
  assert {
    condition     = aws_vpc.main.enable_dns_hostnames == true && aws_vpc.main.enable_dns_support == true
    error_message = "VPC DNS hostnames/support should be enabled"
  }

  # -------------------------------------------------------------------------
  # INTERNET GATEWAY ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify IGW naming convention
  assert {
    condition     = startswith(aws_internet_gateway.main.tags["Name"], "${var.vpc_name}-")
    error_message = "IGW Name tag should be prefixed with vpc_name"
  }

  # -------------------------------------------------------------------------
  # SUBNET COUNT ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify correct number of subnets per tier
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

  # -------------------------------------------------------------------------
  # SUBNET CONFIGURATION ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify public subnet auto-assigns public IPs
  assert {
    condition     = aws_subnet.public[0].map_public_ip_on_launch == true
    error_message = "Public subnets should map public IPs on launch"
  }

  # -------------------------------------------------------------------------
  # NAT GATEWAY ASSERTIONS (HIGH AVAILABILITY)
  # -------------------------------------------------------------------------

  # Verify one EIP per NAT Gateway
  assert {
    condition     = length(aws_eip.nat) == length(var.availability_zones)
    error_message = "Should allocate one EIP per NAT"
  }

  # Verify one NAT Gateway per AZ for HA
  assert {
    condition     = length(aws_nat_gateway.main) == length(var.availability_zones)
    error_message = "Should create one NAT per AZ for HA"
  }

  # -------------------------------------------------------------------------
  # ROUTE TABLE ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify public route table created
  assert {
    condition     = aws_route_table.public.tags["Name"] == "${var.vpc_name}-public-rt"
    error_message = "Public route table should have expected Name tag"
  }

  # Verify public default route to internet
  assert {
    condition     = aws_route.public_internet.destination_cidr_block == "0.0.0.0/0"
    error_message = "Public route must send 0.0.0.0/0"
  }

  # -------------------------------------------------------------------------
  # PRIVATE APP ROUTE TABLE ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify one route table per AZ for app tier
  assert {
    condition     = length(aws_route_table.private_app) == length(var.availability_zones)
    error_message = "Should create a private-app route table per AZ"
  }

  # Verify one default route per app route table
  assert {
    condition     = length(aws_route.private_app_nat) == length(var.availability_zones)
    error_message = "Should create a default route per private-app RT"
  }

  # Verify default route targets internet
  assert {
    condition     = aws_route.private_app_nat[0].destination_cidr_block == "0.0.0.0/0"
    error_message = "Private-app AZ[0] default route should target 0.0.0.0/0"
  }

  # -------------------------------------------------------------------------
  # PRIVATE DATA ROUTE TABLE ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify shared data route table created
  assert {
    condition     = aws_route_table.private_data.tags["Name"] == "${var.vpc_name}-private-data-rt"
    error_message = "Private-data route table should have the expected Name tag"
  }

  # Verify single default route for data tier
  assert {
    condition     = length(aws_route.private_data_nat) == 1
    error_message = "Private-data should have exactly one default route"
  }

  # Verify default route targets internet
  assert {
    condition     = aws_route.private_data_nat[0].destination_cidr_block == "0.0.0.0/0"
    error_message = "Private-data default route should target 0.0.0.0/0"
  }

  # -------------------------------------------------------------------------
  # ROUTE TABLE ASSOCIATION ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify all public subnets associated
  assert {
    condition     = length(aws_route_table_association.public) == length(var.availability_zones)
    error_message = "All public subnets should associate with public RT"
  }

  # Verify all private app subnets associated
  assert {
    condition     = length(aws_route_table_association.private_app) == length(var.availability_zones)
    error_message = "All private-app subnets should associate with their RTs"
  }

  # Verify all private data subnets associated
  assert {
    condition     = length(aws_route_table_association.private_data) == length(var.availability_zones)
    error_message = "All private-data subnets should associate with the shared RT"
  }
}

# -----------------------------------------------------------------------------
# TAGGING & NAMING
# -----------------------------------------------------------------------------

# Validates resource tagging and naming conventions
# Expected Behavior:
#   - Subnets have Tier tags (public, private-app, private-data)
#   - All resources have Name tags
#   - Tags follow consistent naming patterns
run "tagging_and_naming" {
  command = plan

  variables {
    # use test defaults
  }

  # -------------------------------------------------------------------------
  # PUBLIC SUBNET TAGGING
  # -------------------------------------------------------------------------

  # Verify public subnet tier tag
  assert {
    condition     = aws_subnet.public[0].tags["Tier"] == "public"
    error_message = "Public subnet should have Tier=public"
  }

  # Verify public subnet has name tag
  assert {
    condition     = length(aws_subnet.public[0].tags["Name"]) > 0
    error_message = "Public subnet should have a Name tag"
  }

  # -------------------------------------------------------------------------
  # PRIVATE APP SUBNET TAGGING
  # -------------------------------------------------------------------------

  # Verify private-app subnet tier tag
  assert {
    condition     = aws_subnet.private_app[1].tags["Tier"] == "private-app"
    error_message = "Private-app subnet should have Tier=private-app"
  }

  # Verify private-app subnet has name tag
  assert {
    condition     = length(aws_subnet.private_app[1].tags["Name"]) > 0
    error_message = "Private-app subnet should have a Name tag"
  }

  # -------------------------------------------------------------------------
  # PRIVATE DATA SUBNET TAGGING
  # -------------------------------------------------------------------------

  # Verify private-data subnet tier tag
  assert {
    condition     = aws_subnet.private_data[2].tags["Tier"] == "private-data"
    error_message = "Private-data subnet should have Tier=private-data"
  }

  # Verify private-data subnet has name tag
  assert {
    condition     = length(aws_subnet.private_data[2].tags["Name"]) > 0
    error_message = "Private-data subnet should have a Name tag"
  }

  # -------------------------------------------------------------------------
  # INTERNET GATEWAY TAGGING
  # -------------------------------------------------------------------------

  # Verify IGW naming pattern includes vpc_name
  assert {
    condition     = startswith(aws_internet_gateway.main.tags["Name"], "${var.vpc_name}-")
    error_message = "IGW Name tag should be prefixed with vpc_name"
  }
}

# -----------------------------------------------------------------------------
# OUTPUTS (ENABLED NAT)
# -----------------------------------------------------------------------------

# Validates output values with NAT Gateway enabled
# Expected Behavior:
#   - All subnet ID lists have correct counts
#   - NAT Gateway IDs list populated
#   - Availability zones match input
run "outputs_enabled_nat" {
  command = plan

  variables {
    # use test defaults (enable_nat_gateway = true)
  }

  # -------------------------------------------------------------------------
  # SUBNET OUTPUT ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify public subnet IDs output
  assert {
    condition     = length(output.public_subnet_ids) == length(var.availability_zones)
    error_message = "public_subnet_ids output should include all public subnets"
  }

  # Verify private app subnet IDs output
  assert {
    condition     = length(output.private_app_subnet_ids) == length(var.availability_zones)
    error_message = "private_app_subnet_ids output should include all private-app subnets"
  }

  # Verify private data subnet IDs output
  assert {
    condition     = length(output.private_data_subnet_ids) == length(var.availability_zones)
    error_message = "private_data_subnet_ids output should include all private-data subnets"
  }

  # -------------------------------------------------------------------------
  # NAT GATEWAY OUTPUT ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify NAT gateway IDs output (enabled)
  assert {
    condition     = length(output.nat_gateway_ids) == length(var.availability_zones)
    error_message = "nat_gateway_ids output should include one ID per AZ when enabled"
  }

  # -------------------------------------------------------------------------
  # AVAILABILITY ZONE OUTPUT ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify availability zones passthrough
  assert {
    condition     = length(output.availability_zones) == length(var.availability_zones)
    error_message = "availability_zones output should match input length"
  }
}

# -----------------------------------------------------------------------------
# OUTPUTS (DISABLED NAT)
# -----------------------------------------------------------------------------

# Validates output values with NAT Gateway disabled
# Expected Behavior:
#   - NAT Gateway IDs list is empty
run "outputs_disabled_nat" {
  command = plan

  variables {
    enable_nat_gateway = false
  }

  # -------------------------------------------------------------------------
  # NAT GATEWAY OUTPUT ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify NAT gateway IDs output is empty when disabled
  assert {
    condition     = length(output.nat_gateway_ids) == 0
    error_message = "nat_gateway_ids output should be empty when NAT is disabled"
  }
}

# -----------------------------------------------------------------------------
# ROUTING SPECIFICS
# -----------------------------------------------------------------------------

# Validates detailed routing configuration
# Expected Behavior:
#   - Public subnets route to Internet Gateway
#   - Private app subnets route to per-AZ NAT Gateways
#   - Private data subnets share single route table with NAT access
run "routing_specifics" {
  command = plan

  variables {
    # use test defaults
  }

  # -------------------------------------------------------------------------
  # PUBLIC ROUTING ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify public default route targets internet
  assert {
    condition     = aws_route.public_internet.destination_cidr_block == "0.0.0.0/0"
    error_message = "Public route table must route 0.0.0.0/0"
  }

  # -------------------------------------------------------------------------
  # PRIVATE APP ROUTING ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify private-app AZ-2 default route exists
  assert {
    condition     = aws_route.private_app_nat[2].destination_cidr_block == "0.0.0.0/0"
    error_message = "AZ-2 private-app default route should target 0.0.0.0/0"
  }

  # -------------------------------------------------------------------------
  # PRIVATE DATA ROUTING ASSERTIONS
  # -------------------------------------------------------------------------

  # Verify private-data shared route table has default route
  assert {
    condition     = aws_route.private_data_nat[0].destination_cidr_block == "0.0.0.0/0"
    error_message = "Private-data should route 0.0.0.0/0"
  }
}
