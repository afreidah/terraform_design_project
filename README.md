# Infrastructure Design Summary

**Repository:** [github.com/afreidah/terraform_design_project](https://github.com/afreidah/terraform_design_project/tree/add-terraform-test)

This document outlines the architecture and processes designed to meet the requirements of the Infrastructure Design Exercise. It details the design strategy for networking, security, Kubernetes access, secrets management, and CI/CD workflows across all environments.

---

## 📋 Table of Contents

- [Production VPC Design](#production-vpc-design)
- [Production PCI VPC Design](#production-pci-vpc-design)
- [Deployment, Promotion, and Governance](#deployment-promotion-and-governance)
- [Detailed Networking, CIDR, and Routing](#detailed-networking-cidr-and-routing)
- [Terraform POC Implementation](#terraform-poc-implementation)

---

## 🏗️ Production VPC Design

### CIDR and Subnetting

Each VPC is assigned a unique, non-overlapping `/16` CIDR block. Subnets are divided into three tiers and distributed across three Availability Zones for high availability:

- **Public Tier** - Internet-facing resources (ALBs, NAT Gateways)
- **Private-App Tier** - Application workloads (EKS nodes, EC2 instances)
- **Private-Data Tier** - Data stores (RDS, ElastiCache, OpenSearch, MSK)

### Routing and Internet Access

**Public Subnets:**
- Direct internet access via Internet Gateways (IGW)
- Route table: `0.0.0.0/0 → IGW`

**Private-App Subnets:**
- Internet access via NAT Gateways (one per AZ for high availability)
- Route table: `0.0.0.0/0 → NAT Gateway`

**Private-Data Subnets:**
- No direct internet access
- AWS service access via VPC Endpoints only

### Security Groups

Layered security group architecture isolating each tier:

| Security Group | Purpose | Inbound Rules |
|:---------------|:--------|:--------------|
| Public ALB SG | Internet-facing load balancer | HTTP/HTTPS from `0.0.0.0/0` |
| Internal ALB SG | Internal load balancer | HTTP/HTTPS from VPC CIDR only |
| App Tier SG | Application instances/pods | Port 8080 from ALB SGs only |
| Data Tier SG | Databases and caches | DB ports from App Tier SG only |
| Admin SG | SSH/RDP access | Port 22/3389 from DevOps IP ranges |

**Key Principles:**
- Defense-in-depth with security group chaining
- Minimal network exposure
- Source-based access control (SG-to-SG rules)
- Admin ports restricted to DevOps IP ranges

### Secrets Management

All sensitive data managed through AWS Systems Manager Parameter Store:

- Database passwords
- Authentication tokens
- API keys
- Connection strings

**Security Features:**
- All secrets encrypted with AWS KMS
- SecureString parameter type
- No hardcoded credentials in code or state
- IAM role-based access control
- Automatic key rotation enabled

### EKS Access Control

Kubernetes cluster access managed through IAM roles and RBAC:

**DevOps Team:**
- IAM role mapped to `system:masters` Kubernetes group
- Full cluster administration privileges
- Can deploy, modify, and manage all resources

**Development Team:**
- IAM role mapped to read-only Kubernetes group
- View-only access to cluster resources
- Cannot modify production workloads

---

## 🔒 Production PCI VPC Design

The Production-PCI environment mirrors the Production VPC architecture with enhanced isolation for regulated workloads.

### Architecture Parity

- Identical VPC layout (public/private-app/private-data tiers)
- Same subnetting strategy across three AZs
- Equivalent security group isolation model
- Separate KMS keys for encryption

### Cross-VPC Connectivity

**VPC Peering Configuration:**
- Peering connection between Production and Production-PCI
- Selective routing for controlled communication

**Routing Rules:**

✅ Application Subnets - Bidirectional peering routes enabled  
✅ Public Subnets - Peering routes for ALB health checks  
✅ Data Subnets - VPC Peering enabled

**Traffic Patterns:**
- Service-to-service communication via internal ALBs
- No direct instance-to-instance communication
- Data tier remains completely isolated

**DNS Resolution:**
- Route 53 private hosted zones associated to both VPCs
- Consistent internal DNS resolution (e.g., `*.internal.example.com`)
- Cross-VPC service discovery enabled

---

## 🚀 Deployment, Promotion, and Governance

### CI/CD Workflow

**Container Workloads:**

1. Build and test container images
2. Push to Amazon ECR
3. Deploy to EKS using Kubernetes manifests or Helm charts
4. Automated rollout with health checks

**EC2 Workloads:**

1. Build application artifacts
2. Deploy using AWS CodeDeploy
3. Auto Scaling group integration
4. Rolling updates with health monitoring

### Promotion Process

Environment promotion follows a strict gating process:

```
Development → Staging → Production → Production-PCI
```

| Environment | Trigger | Requirements |
|:------------|:--------|:-------------|
| Development | Merge to `develop` branch | Automated deployment |
| Staging | Manual approval | Integration tests pass |
| Production | Manual approval | Security scans pass<br>Cost analysis reviewed |
| Production-PCI | Manual approval | Compliance validation<br>Change management approval |

**Testing Gates:**
- Unit tests
- Integration tests
- Security vulnerability scans
- Infrastructure security checks (Tfsec, Trivy, Checkov)
- Cost impact analysis (Infracost)

### Blue/Green Deployments

**Kubernetes (EKS):**
- Argo Rollouts for progressive delivery
- Canary deployments with traffic shifting
- Automated rollback on failures
- Prometheus metrics-based analysis

**EC2 Auto Scaling Groups:**
- AWS CodeDeploy with ALB target group shifting
- Blue/green deployment strategy
- Traffic cutover after validation
- Rollback capability maintained

### VPC Peering Management

Managed via CDKTF-based automation tool:

- **Configuration:** Define peering in `peering.yaml`
- **Automation:** Bi-directional peering setup
- **Routing:** Automatic route table configuration
- **DNS:** Cross-VPC DNS resolution enabled
- **Repository:** [vpc-peering-tool](https://github.com/afreidah/vpc-peering-tool)

---

## 🌐 Detailed Networking, CIDR, and Routing

### Addressing Plan

Each environment receives a dedicated `/16` CIDR block to ensure complete isolation:

| Environment | VPC CIDR | Purpose |
|:------------|:---------|:--------|
| Production | `10.20.0.0/16` | Production workloads |
| Production-PCI | `10.21.0.0/16` | PCI-compliant workloads |
| Staging | `10.10.0.0/16` | Pre-production testing |
| Development | `10.0.0.0/16` | Development and experimentation |

### Subnet Allocation (Per VPC)

Within each `/16` VPC, subnets are consistently allocated across three Availability Zones:

#### Public Subnets (ALBs, NAT Gateways)

Three `/24` subnets (256 IPs each):

```
10.X.0.0/24   - AZ A
10.X.1.0/24   - AZ B
10.X.2.0/24   - AZ C
```

#### Private-App Subnets (EKS, EC2)

Three `/20` subnets (4,096 IPs each):

```
10.X.16.0/20  - AZ A
10.X.32.0/20  - AZ B
10.X.48.0/20  - AZ C
```

**Rationale:** `/20` provides ample IP space for large EKS node groups, Auto Scaling group expansion, and pod IP allocation.

#### Private-Data Subnets (RDS, ElastiCache, OpenSearch, MSK)

Three `/22` subnets (1,024 IPs each):

```
10.X.64.0/22  - AZ A
10.X.68.0/22  - AZ B
10.X.72.0/22  - AZ C
```

**Rationale:** `/22` accommodates Multi-AZ database deployments, ElastiCache cluster nodes, MSK broker instances, and OpenSearch data nodes.

> **Note:** Replace `X` with the environment's second octet (e.g., Production uses `20`, so `10.20.16.0/20`)

### Route Table Configuration

#### Public Subnet Route Tables (One per AZ)

| Destination | Target | Purpose |
|:------------|:-------|:--------|
| `10.X.0.0/16` | local | Intra-VPC routing |
| `0.0.0.0/0` | `igw-<vpc>` | Internet access |
| `10.21.0.0/16`* | `pcx-<prod-pci>` | Cross-VPC (Prod↔PCI only) |

*Only configured for Production↔Production-PCI peering

#### Private-App Subnet Route Tables (One per AZ)

| Destination | Target | Purpose |
|:------------|:-------|:--------|
| `10.X.0.0/16` | local | Intra-VPC routing |
| `0.0.0.0/0` | `nat-<az>` | Internet egress via NAT |
| `10.21.0.0/16`* | `pcx-<prod-pci>` | Cross-VPC app traffic |

**VPC Endpoints Attached:**
- Gateway Endpoints: S3, DynamoDB
- Interface Endpoints: ECR (api/dkr), SSM, EC2Messages, CloudWatch Logs, STS

*Cross-VPC route only for Production↔Production-PCI

#### Private-Data Subnet Route Tables (Shared or per AZ)

| Destination | Target | Purpose |
|:------------|:-------|:--------|
| `10.X.0.0/16` | local | Intra-VPC routing only |

**No Additional Routes:**

❌ No `0.0.0.0/0` route (no internet access)  
❌ No VPC peering routes (complete isolation)

**VPC Endpoints Required:**
- Gateway: S3 (backups), DynamoDB
- Interface: RDS, KMS, SSM, CloudWatch Logs

> **Why no internet route on data tier?**
>
> Complete isolation ensures no direct internet exposure, prevents lateral movement from compromised app tier, enables AWS service access via private endpoints only, and maintains compliance with zero-trust networking principles.

### Security Group Traffic Patterns

Security groups enforce defense-in-depth with source-based rules:

```
Internet → Public ALB SG → App SG → Data SG
             ↓               ↓          ↓
         [80/443]        [8080]   [DB ports]
```

| Source | Destination | Ports | Protocol |
|:-------|:------------|:------|:---------|
| `0.0.0.0/0` | Public ALB SG | 80, 443 | TCP |
| VPC CIDR | Internal ALB SG | 80, 443 | TCP |
| Public ALB SG | App SG | 8080 | TCP |
| Internal ALB SG | App SG | 8080 | TCP |
| App SG | RDS SG | 5432 | TCP |
| App SG | ElastiCache SG | 6379 | TCP |
| App SG | OpenSearch SG | 443, 9200 | TCP |
| App SG | MSK SG | 9092, 9094 | TCP |
| DevOps IPs | App/Node SG | 22, 3389 | TCP |

**Egress Rules:**
- **App SG:** 80/443 to `0.0.0.0/0` (package repos, AWS APIs via NAT)
- **Data SGs:** Default deny egress (VPC endpoints only)

### Cross-VPC Communication (Production ↔ Production-PCI)

**Peering Connection:**
- VPC Peering (supports same/cross-account, same/cross-region)
- DNS resolution enabled for both VPCs
- Unique peering connection per VPC pair

**Routing Configuration:**

Production VPC:
```
10.21.0.0/16 → pcx-prod-pci (in public/app route tables only)
```

Production-PCI VPC:
```
10.20.0.0/16 → pcx-prod-pci (in public/app route tables only)
```

**Service Communication Pattern:**

```
Prod App → Prod Internal ALB → VPC Peering → PCI Internal ALB → PCI App
```

**Benefits:**
- Stable DNS endpoints (no IP hardcoding)
- ALB health checking and routing
- TLS termination at ALB boundary
- No direct instance communication
- Traffic observable and controllable

**DNS Strategy:**
- Route 53 private hosted zones
- Associated to both Production and Production-PCI VPCs
- Internal service discovery (e.g., `api.internal.example.com`)
- Split-horizon DNS if needed for environment-specific resolution

### Network ACLs

**Philosophy:** Stateless, permissive approach

- NACLs default to ALLOW ALL
- Primary enforcement via Security Groups
- Avoid operational friction from NACL rule conflicts

**If Required by Policy:**
- Add coarse-grained rules (e.g., block known bad IPs)
- Allow ephemeral port return traffic (32768-65535)
- Never duplicate Security Group logic in NACLs

---

## 💻 Terraform POC Implementation

The proof-of-concept implementation demonstrates a production-ready infrastructure foundation.

### Infrastructure Components

**Networking:**
- Full VPC/subnet layout for all four environments
- Multi-AZ deployment across three Availability Zones
- Internet Gateways, NAT Gateways, and Route Tables
- VPC Endpoints for AWS services
- VPC Peering connections (Production ↔ Production-PCI)

**Security:**
- Comprehensive Security Group configurations
- IAM roles and policies for all services
- KMS encryption keys per environment and service
- AWS WAF rules on public ALBs

**Compute:**
- EKS clusters with IAM-to-Kubernetes RBAC mappings
- EC2 Auto Scaling groups with ALB integration
- DevOps admin access and Developer read-only access

**Data Stores:**
- RDS PostgreSQL (Multi-AZ)
- ElastiCache Redis clusters
- OpenSearch domains
- Amazon MSK (Managed Kafka)

**Configuration Management:**
- AWS Systems Manager Parameter Store integration
- Automated secret generation and storage
- KMS encryption for all sensitive data

### CI/CD Pipeline (GitHub Actions)

**Automated Checks:**
- `terraform fmt` - Code formatting verification
- `terraform validate` - Syntax validation
- `terraform plan` - Infrastructure planning
- `terraform test` - Module testing
- `terraform apply` - Controlled deployment

**Security Scanning:**
- **Tfsec** - Terraform security best practices
- **Trivy** - Infrastructure vulnerability scanning
- **Checkov** - Policy-as-code compliance

**Cost Analysis:**
- **Infracost** integration for cost estimation
- PR comments with monthly cost projections
- Cost-awareness in review process

### Environment Management

**Separation Strategy:**
- Dedicated `terraform.tfvars` per environment
- Separate state files (local or remote backend)
- Environment-specific configuration values
- Non-overlapping CIDR blocks

**Deployment Workflow:**

1. Developer opens Pull Request
2. Automated validation runs for all environments
3. Security scans and cost analysis complete
4. Team reviews plan outputs and cost impacts
5. Approval required for merge
6. Manual promotion to higher environments

### VPC Peering Automation

**Tool:** CDKTF-based VPC Peering Tool

- **Repository:** [vpc-peering-tool](https://github.com/afreidah/vpc-peering-tool)
- **Configuration:** Simple YAML definition
- **Features:**
  - Automated peering connection creation
  - Bi-directional route table updates
  - DNS resolution enablement
  - Cross-account support
  - Multi-region capability

**Usage:**
```bash
# Define peering in peering.yaml
make deploy
```

### Beyond Requirements

This implementation exceeds the original design exercise requirements by providing:

- Complete working Terraform codebase
- Automated testing and validation
- Production-ready security configurations
- Full CI/CD pipeline integration
- Cost management tooling
- VPC peering automation tool
- Comprehensive documentation

The POC serves as both a design reference and an operational foundation that can be extended for production deployment.

---

## ✨ Summary

This infrastructure design provides a secure, scalable, and maintainable foundation for multi-environment AWS deployments. Key architectural decisions ensure:

✅ **Security by Design** - Defense-in-depth with layered controls  
✅ **High Availability** - Multi-AZ deployment for all critical services  
✅ **Environment Isolation** - Dedicated VPCs with no IP overlap  
✅ **PCI Compliance** - Isolated data tier with controlled cross-VPC access  
✅ **Secrets Management** - KMS-encrypted Parameter Store with IAM access  
✅ **Automated Governance** - CI/CD pipeline with security and cost gates  
✅ **Operational Excellence** - IaC best practices with comprehensive tooling

The Terraform POC implementation demonstrates that this design is not only theoretically sound but practically deployable, providing teams with a solid starting point for production infrastructure.
