# CDKTF VPC Peering Module

Reusable [CDKTF](https://developer.hashicorp.com/terraform/cdktf) module for managing AWS VPC peering connections with automated bi-directional routing, DNS resolution, and subnet route management. Supports multi-account and multi-region environments with YAML-driven configuration.

---

## Features

- Automated VPC peering across AWS accounts and regions
- Bi-directional routing (main + subnet route tables)
- DNS resolution and cross-account/region support
- YAML-driven configuration
- Type-safe Go implementation

---

## Integration Options

### Option 1: Use CDKTF Module Directly

Best for CDKTF projects or when you need programmatic control and type safety. See [Usage](#usage) below.

### Option 2: Convert to Native Terraform

For standard Terraform projects, convert this module to HCL. The logic in `helpers.go` and `main.go` translates cleanly to Terraform resources and data sources.

---

## Usage

**Prerequisites:** Go 1.22+, Node.js 20.x, Terraform 1.12+, CDKTF CLI

**Setup:**
```sh
make init    # Install dependencies
make get     # Generate provider bindings
make tidy    # Tidy Go modules
```

**Configuration:**

Create a `peering.yaml` file in the repo root. Example:

```yaml
peers:
  dev-peer:
    vpc_id: vpc-0aaa1111aaa1111aa
    region: us-east-1
    role_arn: "arn:aws:iam::111111111111:role/DevRole"
    dns_resolution: true
    has_additional_routes: false

  prod-peer:
    vpc_id: vpc-0bbb2222bbb2222bb
    region: us-west-2
    role_arn: "arn:aws:iam::222222222222:role/ProdRole"
    dns_resolution: true
    has_additional_routes: true

  staging-peer:
    vpc_id: vpc-0ccc3333ccc3333cc
    region: us-east-2
    role_arn: "arn:aws:iam::333333333333:role/StagingRole"
    dns_resolution: false
    has_additional_routes: false

  qa-peer:
    vpc_id: vpc-0ddd4444ddd4444dd
    region: us-west-1
    role_arn: "arn:aws:iam::444444444444:role/QARole"
    dns_resolution: true
    has_additional_routes: true

peering_matrix:
  dev-peer:
    - prod-peer
    - staging-peer
  qa-peer:
    - prod-peer
```

- **`peers`**: VPC definitions with `vpc_id`, `region`, `role_arn`, `dns_resolution`, and `has_additional_routes`
- **`peering_matrix`**: Source peer → list of target peers to connect

**Deployment:**
```sh
make synth    # Synthesize Terraform config
make plan     # Preview changes
make deploy   # Apply changes
```

**Filter by source:**
```sh
export CDKTF_SOURCE=dev-peer
make deploy
```

---

## Commands

```sh
make init     # Install dependencies
make get      # Generate provider bindings
make tidy     # Tidy Go modules
make fmt      # Format code
make lint     # Lint code
make test     # Run tests
make synth    # Synthesize Terraform
make plan     # Preview changes
make deploy   # Apply changes
make destroy  # Destroy resources
make sec      # Security scans (Trivy + Checkov)
make clean    # Remove build artifacts
```

---

## How It Works

1. Load `peering.yaml` and convert to internal config structs
2. Create AWS providers for each peer with role assumption
3. Create VPC peering connection + accepter (cross-region/account)
4. Configure DNS resolution options
5. Create bi-directional routes (main + optional subnet route tables)
6. Synthesize to Terraform JSON in `cdktf.out/`

**Key Files:**
- `main.go` - Entry point and stack orchestration
- `helpers.go` - Core peering and routing logic
- `peering.yaml` - Declarative configuration

---

## Testing & CI/CD

**Unit Tests:**
```sh
make test  # Tests ARN parsing, YAML loading, config conversion
```

**Security:**
```sh
make sec   # Runs Trivy and Checkov scans
```

**GitHub Actions:** Runs on PRs with Docker build, provider generation, linting, tests, and security scans.

---

## Advanced

**Cross-Account:** Ensure IAM roles exist with proper trust policies and VPC peering permissions in both accounts.

**Cross-Region:** Automatically handles `peer_region` and accepter resources.

**Subnet Routes:** When `has_additional_routes: true`, queries subnets tagged with `cdktf-source-main-rt` or `cdktf-peer-main-rt` and creates routes in their route tables.

---
