# AWS Infrastructure - Terraform

Production-grade AWS infrastructure with security best practices, high availability, and comprehensive monitoring.

## Architecture

```
┌─────────────────────────────────────────────────┐
│ Public Tier (10.0.1-3.0/24)                    │
│ - Public ALB + WAF                              │
│ - NAT Gateways (3 AZs)                         │
└─────────────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────────────┐
│ Private App Tier (10.0.11-13.0/24)            │
│ - EC2 Auto Scaling Groups                      │
│ - EKS Cluster + Node Groups                    │
│ - Internal ALB                                  │
└─────────────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────────────┐
│ Private Data Tier (10.0.21-23.0/24)           │
│ - RDS PostgreSQL (Multi-AZ)                    │
│ - ElastiCache Redis (3 nodes)                  │
│ - OpenSearch (3 nodes + 3 masters)             │
│ - MSK Kafka (3 brokers)                         │
└─────────────────────────────────────────────────┘
```

## Key Features

- **Security**: KMS encryption, WAF, VPC Flow Logs, IMDSv2, private subnets
- **High Availability**: Multi-AZ deployment (3 AZs), Auto Scaling, Multi-AZ RDS
- **Observability**: CloudWatch logs/metrics, Performance Insights, enhanced monitoring
- **CI/CD**: Automated security scanning (tfsec, trivy, checkov) and cost estimation

## Quick Start

```bash
# Using Docker (recommended)
make docker-build
make docker-run CMD="make plan ENV=production"
make docker-run CMD="make apply ENV=production"

# Using local tools
make plan ENV=production
make apply ENV=production
```

## Configuration

Update `environments/production/terraform.tfvars`:

```hcl
region      = "us-east-1"
environment = "production"

# IMPORTANT: Restrict EKS access
eks_public_access_cidrs = ["YOUR_VPN_IP/32"]

# Optional: Add SSL certificate
ssl_certificate_arn = "arn:aws:acm:..."
```

**Note**: Application must expose `/health` endpoint on port 8080.

## Common Commands

```bash
make help                    # Show all commands
make fmt                     # Format Terraform files
make lint                    # Run linters
make security                # Run security scans
make plan ENV=production     # Create plan
make apply ENV=production    # Apply changes
make cost                    # Estimate costs
```

## Module Structure

- `alb/` - Application Load Balancers
- `ec2/` - Auto Scaling Groups
- `eks-cluster/` - EKS control plane
- `eks-node-group/` - EKS worker nodes
- `elasticache/` - Redis clusters
- `environment/` - Complete environment orchestration
- `general-networking/` - VPC and networking
- `kms/` - Encryption keys
- `msk/` - Kafka clusters
- `opensearch/` - Search/analytics
- `parameter-store/` - Secrets management
- `rds/` - PostgreSQL databases
- `security-group/` - Security groups
- `waf/` - Web Application Firewall

## CI/CD Pipeline

GitHub Actions runs on pull requests:
- Terraform validation and formatting
- Security scanning (tfsec, trivy, checkov)
- Plan generation with Infracost cost estimation

## Before Production

- [ ] Update `ec2_ami_id` to latest AMI
- [ ] Restrict `eks_public_access_cidrs`
- [ ] Restrict `devops_ip_ranges` to VPN/office IPs
- [ ] Configure SSL certificate
- [ ] Verify `/health` endpoint exists
- [ ] Set up CloudWatch alarms
- [ ] Test RDS backup restoration

## Network Architecture Details

### Route Tables

**Public Subnets** (`10.0.1-3.0/24`):
```
Destination       Target
10.0.0.0/16      local
0.0.0.0/0        igw-xxxxx (Internet Gateway)
```
- Routes all internet traffic through Internet Gateway
- Used by: ALB, NAT Gateways

**Private App Subnets** (`10.0.11-13.0/24`) - One route table per AZ:
```
Destination       Target
10.0.0.0/16      local
0.0.0.0/0        nat-xxxxx (NAT Gateway in same AZ)
```
- Routes internet traffic through NAT Gateway for HA
- Used by: EC2 instances, EKS nodes
- Enables pulling updates and accessing AWS services

**Private Data Subnets** (`10.0.21-23.0/24`) - Shared route table:
```
Destination       Target
10.0.0.0/16      local
0.0.0.0/0        nat-xxxxx (NAT Gateway in AZ-1)
```
- Routes internet traffic through first NAT Gateway
- Used by: RDS, ElastiCache, OpenSearch, MSK
- Minimal internet access needed for maintenance

### Security Model

- **Public tier**: Internet-facing resources only (ALB, NAT)
- **Private app tier**: Application logic, never directly exposed
- **Private data tier**: Databases, completely isolated from internet
- **Admin access**: SSH restricted to `devops_ip_ranges` variable
- **Application access**: Ports 8080/80 only accessible via load balancers

### EKS Access Control

**DevOps Team** - Full cluster admin:
```bash
# Assume the DevOps role
aws sts assume-role \
  --role-arn arn:aws:iam::ACCOUNT_ID:role/production-eks-devops-role \
  --role-session-name devops-session \
  --external-id production

# Configure kubectl
aws eks update-kubeconfig --name production-eks --region us-east-1
kubectl get nodes  # Full access
```

**Developers Team** - Read-only access:
```bash
# Assume the Developers role
aws sts assume-role \
  --role-arn arn:aws:iam::ACCOUNT_ID:role/production-eks-developers-role \
  --role-session-name dev-session \
  --external-id production

# Apply read-only ClusterRole (DevOps does this once)
kubectl apply -f examples/rbac/read-only-clusterrole.yaml

# Developers can now view resources
kubectl get pods --all-namespaces
kubectl logs pod-name
# But cannot modify anything
```

## Troubleshooting

**EKS nodes not joining**: Check node IAM role in aws-auth ConfigMap and security groups

**RDS timeout**: Verify security group allows app tier traffic and NAT gateway routing

**ALB health checks failing**: Confirm `/health` endpoint returns HTTP 200 on port 8080

**High costs**: Consider single NAT gateway ($-65/mo) or smaller OpenSearch ($-200/mo) for non-prod

## Estimated Costs

**~$1,200-1,300/month** - Run `make cost` for detailed breakdown

Major components: EKS ($135), OpenSearch ($300), MSK ($300), ElastiCache ($120), NAT gateways ($100)
