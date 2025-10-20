# Terraform AWS Infrastructure

A comprehensive Terraform-based infrastructure codebase for multi-environment AWS deployments, demonstrating best practices in provisioning and managing cloud resources across Development, Staging, Production, and Production-PCI environments.

## Overview

This repository provides a production-ready infrastructure setup featuring:

- **Multi-tier network architecture** with complete environment isolation
- **Robust security** using AWS WAF, security groups, and KMS encryption
- **Automated CI/CD pipeline** for Terraform deployments
- **Comprehensive AWS service coverage** including VPC, EC2, EKS, RDS, ElastiCache, MSK, and OpenSearch
- **High availability** configurations across all components
- **Secrets management** via AWS SSM Parameter Store with KMS encryption

Each environment uses non-overlapping IP ranges to ensure complete isolation:
- **Dev**: `10.0.0.0/16`
- **Staging**: `10.10.0.0/16`
- **Production**: `10.20.0.0/16`
- **Production-PCI**: `10.21.0.0/16`

## Repository Structure

```
.
├── environments/          # Environment-specific configurations
│   ├── dev/
│   ├── staging/
│   ├── production/
│   └── production-pci/
├── modules/              # Reusable Terraform modules
│   ├── environment/
│   ├── general-networking/
│   ├── security-group/
│   ├── waf/
│   ├── alb/
│   ├── ec2/
│   ├── eks-cluster/
│   ├── eks-node-group/
│   ├── rds/
│   ├── elasticache/
│   ├── opensearch/
│   ├── msk/
│   ├── kms/
│   └── parameter-store/
├── .github/
│   └── workflows/        # CI/CD pipelines
├── Dockerfile            # Terraform tooling container
├── docker-compose.yml    # Local development environment
├── Makefile             # Development workflow automation
└── README.md
```

### Environments Directory

Each environment directory contains:

- **`main.tf`** - Invokes the root environment module
- **`variables.tf`** - Input variable definitions
- **`terraform.tfvars`** - Environment-specific values (VPC CIDRs, instance types, IP allowlists)
- **`outputs.tf`** - Exported values (IDs, endpoints, ARNs)

### Modules Directory

#### Core Infrastructure Modules

**`environment`** - Root module that orchestrates all other modules to build a complete environment stack

**`general-networking`** - Core network infrastructure:
- VPC with specified CIDR blocks
- Public and private subnets across multiple AZs
- Internet Gateway and NAT Gateways (one per AZ)
- Route tables for public and private subnets
- VPC peering route management for cross-environment connectivity

**`security-group`** - Factory module for creating security groups:
- Defense-in-depth security model
- Public ALB: HTTP/HTTPS from internet only
- Internal ALB: VPC traffic only
- EC2 instances: App port 8080 from ALB, admin ports restricted to DevOps IPs
- Databases/caches: Application subnet traffic only

**`waf`** - AWS WAFv2 Web ACL:
- AWS-managed rule groups for common threats
- IP reputation lists
- Rate limiting (2000 requests per 5 minutes per IP)
- Optional geo-blocking capabilities

#### Application & Compute Modules

**`alb`** - Application Load Balancer:
- Public ALB (internet-facing) with WAF integration
- Internal ALB (private) for internal traffic
- HTTPS with ACM certificates, HTTP→HTTPS redirect
- Health checks on `/health:8080`
- Deletion protection and security defaults

**`ec2`** - Auto Scaling groups:
- Amazon Linux 2 AMI (or custom AMI)
- Integration with ALB target groups
- Configurable instance types and capacity
- IAM instance profiles for AWS service access

**`eks-cluster`** & **`eks-node-group`** - Kubernetes infrastructure:
- EKS control plane with logging and secrets encryption (KMS)
- Public API access restricted by CIDR allowlists
- Managed node groups with autoscaling
- SSM Agent enabled on worker nodes
- RBAC configuration (admin and read-only roles)

#### Data & Storage Modules

**`rds`** - PostgreSQL database:
- Multi-AZ deployment for high availability
- Storage encryption with KMS
- Automated backups (7-day retention)
- Enhanced monitoring and Performance Insights
- Deletion protection and final snapshots

**`elasticache`** - Redis cluster:
- Primary/replica configuration
- AUTH token authentication
- Private subnet deployment
- KMS encryption at rest

**`opensearch`** - Elasticsearch/OpenSearch domain:
- Private subnet deployment
- Node-to-node encryption
- Encryption at rest with KMS
- Master user authentication

**`msk`** - Managed Kafka cluster:
- Multi-AZ broker deployment
- Encryption in transit (TLS) and at rest (KMS)
- Private subnet placement
- Bootstrap broker endpoints exported

#### Security & Configuration Modules

**`kms`** - KMS key management:
- Dedicated keys per environment and service
- Automatic key rotation enabled
- Descriptive aliases (e.g., `alias/<env>-parameter-store`)

**`parameter-store`** - Secrets and configuration management:
- Bulk parameter provisioning
- SecureString encryption with KMS
- Stores database passwords, auth tokens, connection strings
- Non-secret configuration values

## Development Workflow

### Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- Docker (optional, for containerized workflows)
- Make

### Makefile Targets

The `Makefile` provides a comprehensive set of commands for managing infrastructure:

#### Basic Operations

```bash
# Initialize Terraform (default: ENV=production)
make init

# Initialize with specific environment
make init ENV=staging

# Upgrade provider versions
make init-upgrade

# Create execution plan
make plan ENV=dev

# Apply infrastructure changes
make apply ENV=dev

# Destroy infrastructure
make destroy ENV=dev
```

#### Code Quality

```bash
# Format all Terraform files
make fmt

# Validate Terraform syntax
make validate

# Run TFLint
make tflint

# Run all linting checks
make lint
```

#### Security Scanning

```bash
# Run Tfsec security scanner
make tfsec

# Run Trivy IaC scan
make trivy

# Run Checkov policy scan
make checkov

# Run all security scanners
make security
```

#### Testing & Documentation

```bash
# Run Terraform module tests
make test

# Generate module documentation
make docs

# Show current outputs
make output

# Generate dependency graph
make graph
```

#### Cost Management

```bash
# Generate cost estimate with Infracost
make cost ENV=production
```

#### Docker Workflows

```bash
# Build Docker tooling image
make docker-build

# Open interactive shell in container
make docker-shell

# Run CI checks in container
make docker-ci ENV=dev

# Start docker-compose environment
make docker-compose-up

# Shell into docker-compose container
make docker-compose-shell
```

#### Development Setup

```bash
# Install pre-commit hooks
make dev-setup

# Clean environment artifacts
make clean

# Clean all environments
make clean-all
```

#### Environment Selection

Target different environments by setting the `ENV` variable:

```bash
make plan ENV=staging
make apply ENV=production
make destroy ENV=dev
```

Default environment is `production` if not specified.

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/terraform.yml`) provides comprehensive automation:

### Pull Request Validation

Triggered on PRs to `main` branch:

1. **Matrix Build** - Tests all environments in parallel
2. **Quality Checks**:
   - Terraform formatting verification
   - Syntax validation
   - TFLint execution
   - Module testing
   - Security scans (Tfsec, Trivy, Checkov)
3. **Infrastructure Planning**:
   - Generates Terraform plan for each environment
   - Extracts plan artifacts
   - Calculates cost estimates with Infracost
4. **PR Comments**:
   - Posts validation results (PASS/FAIL) for each environment
   - Includes expandable plan outputs
   - Links to cost impact analysis

All checks must pass before merge approval.

### Continuous Integration

On push to `main` branch:

- Re-validates all environments
- Ensures main branch remains in valid state
- Acts as final safety net

### Manual Deployments

Controlled deployments via GitHub Actions manual triggers:

- **Workflow Dispatch** with environment and action selection (plan/apply)
- **Environment Protection Rules** for production deployments
- **Approval Gates** - Requires authorization before applying changes
- **Audit Trail** - All plans and cost reports stored as artifacts (30-day retention)

### Security & Compliance

- **Gitleaks** - Prevents secret commits
- **Cost Awareness** - Every PR includes cost impact analysis
- **Traceability** - All plans and applies are logged and artifact-preserved

## Secrets Management

### Architecture

All sensitive data is managed through AWS KMS and Systems Manager Parameter Store:

#### KMS Keys Per Environment

Dedicated encryption keys for:
- Parameter Store secrets (`alias/<env>-parameter-store`)
- CloudWatch Logs (`alias/<env>-cloudwatch-logs`)
- RDS storage encryption
- ElastiCache encryption
- OpenSearch encryption
- MSK (Kafka) encryption
- EKS secrets encryption

Features:
- Automatic key rotation enabled
- Per-service isolation limits blast radius
- IAM policies enforce least privilege access

#### Parameter Store Integration

All secrets stored as SecureString parameters:
- **RDS master password** - Generated randomly, KMS-encrypted
- **Redis AUTH token** - Randomly generated
- **OpenSearch master user password** - Randomly generated
- **Connection strings and endpoints** - Non-secret configuration

**Access Pattern**: Applications retrieve secrets at runtime via IAM roles (no hardcoded credentials)

### Encryption Standards

- **At Rest**: All data stores encrypted (RDS, ElastiCache, MSK, OpenSearch, EBS volumes)
- **In Transit**: TLS/HTTPS enforced where applicable
- **Kubernetes Secrets**: Envelope encryption with KMS for EKS etcd
- **Backups & Snapshots**: Encrypted copies maintained

### CI/CD Secret Handling

- GitHub Secrets for AWS credentials and API keys
- No secret values in logs or artifacts
- Runtime injection only

## Cross-VPC Connectivity

### Production ↔ Production-PCI Peering

Secure networking between standard Production and Production-PCI environments:

#### VPC Peering Configuration

- **Peering Connection** between Production and Production-PCI VPCs
- **Selective Routing**:
  - ✅ Application subnets: Bidirectional peering routes
  - ✅ Public subnets: Peering routes (for ALB/bastion communication)
  - ❌ Data subnets: No peering routes (PCI isolation)

This ensures:
- Application tiers can communicate cross-VPC
- Database/data subnets remain isolated
- Even if non-PCI environment is compromised, PCI data is protected

#### Implementation Options

**Option 1: VPC Peering Tool (CDKTF)**
- Custom HashiCorp CDK for Terraform solution (Go)
- Automated setup via YAML definition
- Handles multi-account/multi-region scenarios
- Automatically configures routes, DNS resolution
- Supports full mesh peering

**Option 2: Standard Terraform**
- Use Terraform Registry VPC peering module
- Manual configuration for route tables
- Suitable for simple one-to-one peering
- Direct control over all peering aspects

#### Security Controls

- Security groups enforce port restrictions even with peering
- Cross-VPC traffic funneled through defined points (internal ALBs)
- Traffic monitoring and filtering at application layer

## Infrastructure Components

### Networking

- **VPC**: Isolated per environment with non-overlapping CIDRs
- **Subnets**: Multi-AZ deployment across three tiers (public, private app, private data)
- **NAT Gateways**: One per AZ for high availability
- **Route Tables**: Separate for public and private subnets
- **VPC Peering**: Controlled cross-environment connectivity

### Compute

- **EC2 Auto Scaling**: Application tier with configurable capacity
- **EKS Clusters**: Managed Kubernetes with encrypted secrets
- **Load Balancers**: Public and internal ALBs with health checks

### Databases & Caching

- **RDS PostgreSQL**: Multi-AZ, encrypted, automated backups
- **ElastiCache Redis**: Cluster mode, AUTH enabled
- **OpenSearch**: Search and analytics, private deployment

### Messaging & Streaming

- **Amazon MSK**: Managed Kafka for event streaming

### Security

- **AWS WAF**: Web application firewall on public ALBs
- **Security Groups**: Defense-in-depth network controls
- **KMS**: Encryption key management
- **IAM Roles**: Least privilege access control

### Monitoring & Logging

- **CloudWatch**: Metrics and log aggregation (encrypted)
- **RDS Enhanced Monitoring**: Database performance insights
- **VPC Flow Logs**: Network traffic analysis

## Best Practices Implemented

✅ **Infrastructure as Code**: Complete environment definition in Terraform  
✅ **Environment Isolation**: Separate VPCs, no IP overlap, independent state  
✅ **Security by Default**: Encryption at rest/transit, minimal network exposure  
✅ **High Availability**: Multi-AZ deployments for all critical services  
✅ **Secrets Management**: No hardcoded credentials, KMS encryption  
✅ **Automated Testing**: Pre-merge validation, security scans, cost analysis  
✅ **Change Management**: PR reviews, approval gates, audit trails  
✅ **Cost Visibility**: Infracost integration in CI/CD  
✅ **Documentation**: Auto-generated module docs, dependency graphs  
✅ **Compliance Ready**: PCI isolation patterns, encryption standards

## Getting Started

### 1. Clone Repository

```bash
git clone <repository-url>
cd terraform-aws-infrastructure
```

### 2. Install Development Tools

```bash
make dev-setup
```

This installs pre-commit hooks for automatic validation.

### 3. Configure AWS Credentials

```bash
aws configure
# or
export AWS_ACCESS_KEY_ID=xxx
export AWS_SECRET_ACCESS_KEY=xxx
```

### 4. Initialize Environment

```bash
make init ENV=dev
```

### 5. Review and Apply Changes

```bash
# Generate plan
make plan ENV=dev

# Review the plan output

# Apply changes
make apply ENV=dev
```

### 6. Verify Deployment

```bash
# View outputs
make output ENV=dev

# Check resources in AWS Console
```

## Contributing

1. Create a feature branch from `main`
2. Make changes and commit (pre-commit hooks will validate)
3. Push branch and open Pull Request
4. Review automated validation results and cost estimates
5. Address any failed checks
6. Request review from team members
7. Merge after approval

## Terraform Module Documentation

Each module includes comprehensive documentation generated by `terraform-docs`:

```bash
make docs
```

This updates all module `README.md` files with current inputs, outputs, and requirements.

## Cost Management

Monitor infrastructure costs with Infracost:

```bash
# Set API key (get free key at infracost.io)
export INFRACOST_API_KEY=xxx

# Generate cost estimate
make cost ENV=production
```

Cost breakdowns are automatically included in PR comments.

## Troubleshooting

### Common Issues

**Terraform State Lock**
```bash
# If state is locked, identify the lock and force unlock (use cautiously)
terraform force-unlock <lock-id> -chdir=environments/dev
```

**Module Changes Not Detected**
```bash
# Re-initialize to update module references
make init-upgrade ENV=dev
```

**Security Scan Failures**
```bash
# Run individual scanners for detailed output
make tfsec ENV=dev
make trivy ENV=dev
make checkov ENV=dev
```

**Cost Estimation Errors**
```bash
# Ensure Infracost API key is set
echo $INFRACOST_API_KEY

# Regenerate plan
make plan ENV=dev
make cost ENV=dev
```

## License

[Your License Here]

## Support

For issues and questions:
- Open a GitHub Issue
- Contact the infrastructure team
- Review module documentation

## Acknowledgments

This infrastructure leverages several open-source tools:
- Terraform by HashiCorp
- TFLint, Tfsec, Trivy, Checkov for security scanning
- Infracost for cost estimation
- terraform-docs for documentation generation
- Pre-commit framework for git hooks