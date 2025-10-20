# Implementation Guide

This guide tracks the completion status of all requirements from the Infrastructure Design Exercise and provides actionable steps for remaining work.

---

## Requirements Compliance Status

| Requirement | Status | Priority | Notes |
|-------------|--------|----------|-------|
| **Network Architecture** |
| Multi-tier VPC (public/app/data subnets) | ✅ Complete | - | 3 AZs, NAT per AZ |
| Servers/pods reach app resources | ✅ Complete | - | Security groups configured |
| Cross-VPC connectivity (Prod ↔ Prod-PCI) | ⚠️ Tool Available | **HIGH** | CDKTF peering tool ready for deployment |
| ALB-only cross-VPC traffic | ✅ Complete | - | Data tier excludes peering routes |
| Pod traffic encryption | ❌ Not Implemented | **MEDIUM** | Requires service mesh |
| Route table examples | ✅ Complete | - | Documented in README |
| **Security & Access Control** |
| Network security rules | ✅ Complete | - | 3-tier isolation (ALB→App→Data) |
| DevOps-only admin ports | ⚠️ Overly Permissive | **CRITICAL** | `devops_ip_ranges = ["0.0.0.0/0"]` |
| ALB-only app ports | ✅ Complete | - | Port 8080 restricted to ALB SG |
| DevOps EKS admin access | ✅ Complete | - | IAM role → `system:masters` |
| Dev EKS read-only access | ✅ Complete | - | IAM role → `view-only` ClusterRole |
| Secure secrets storage | ✅ Complete | - | Parameter Store + KMS |
| **CI/CD & Deployments** |
| Code deployment process | ❌ Not Implemented | **HIGH** | Need app pipelines (EKS + EC2) |
| Production approval gates | ❌ Not Implemented | **HIGH** | GitHub environments + reviewers |
| Promotion process (dev→staging→prod) | ❌ Not Implemented | **HIGH** | Multi-stage pipeline |
| Blue/green deployments | ❌ Not Implemented | **MEDIUM** | Argo Rollouts + CodeDeploy |
| **Infrastructure Automation** |
| Terraform modules | ✅ Complete | - | All services modularized + tested |
| CI/CD for infrastructure | ✅ Complete | - | GitHub Actions + Docker tooling |

---

## Critical Action Items

### 1. Restrict DevOps Access (SECURITY CRITICAL)

**Current Risk**: SSH/RDP accessible from any IP address.

**Solution**: Update all environment `terraform.tfvars`:

```hcl
# environments/production/terraform.tfvars
devops_ip_ranges = [
  "203.0.113.0/24",    # Office Network
  "198.51.100.0/24",   # VPN Concentrator
  "192.0.2.0/24",      # Bastion Host
]

# environments/production-pci/terraform.tfvars
devops_ip_ranges = [
  "203.0.113.0/24",    # Office Only (more restrictive)
]
```

**Apply immediately**:
```bash
make plan ENV=production
make apply ENV=production
```

**Validation**:
```bash
# From approved IP - should succeed
ssh ec2-user@<instance-ip>

# From non-approved IP - should timeout
ssh ec2-user@<instance-ip>  # Connection refused
```

---

### 2. Deploy VPC Peering

**Current State**: CDKTF VPC peering tool exists but is not deployed.

**Deployment Steps**:

```bash
# 1. Get VPC IDs from Terraform outputs
cd environments/production
terraform output vpc_id  # vpc-0prod123
cd ../production-pci
terraform output vpc_id  # vpc-0pci456

# 2. Create peering configuration
cd <cdktf-peering-tool-directory>
cat > peering.yaml <<EOF
peers:
  production:
    vpc_id: vpc-0prod123  # From step 1
    region: us-east-1
    role_arn: "arn:aws:iam::111111111111:role/TerraformRole"
    dns_resolution: true
    has_additional_routes: true
  
  production-pci:
    vpc_id: vpc-0pci456   # From step 1
    region: us-east-1
    role_arn: "arn:aws:iam::222222222222:role/TerraformRole"
    dns_resolution: true
    has_additional_routes: true

peering_matrix:
  production:
    - production-pci
EOF

# 3. Deploy peering
make get      # Generate provider bindings
make synth    # Synthesize Terraform
make plan     # Preview changes
make deploy   # Apply peering

# 4. Verify connectivity
aws ec2 describe-vpc-peering-connections \
  --filters "Name=status-code,Values=active"
```

**Security Validation**:

After peering is established, verify isolation:

```bash
# From Production EC2 instance:
# 1. Test app-to-app via Internal ALB (should succeed)
curl http://internal-prod-pci-alb.example.com/health

# 2. Test direct DB access (should fail - no route)
nc -zv 10.21.21.30 5432  # Production-PCI RDS private IP
# Connection timeout (expected - data tier has no peering routes)
```

**Route Table Verification**:
```bash
# App subnet route table (should have peering route)
aws ec2 describe-route-tables \
  --route-table-ids rtb-app-XXXXX \
  --query 'RouteTables[*].Routes[?VpcPeeringConnectionId!=`null`]'

# Data subnet route table (should NOT have peering route)
aws ec2 describe-route-tables \
  --route-table-ids rtb-data-XXXXX \
  --query 'RouteTables[*].Routes[?VpcPeeringConnectionId!=`null`]'
# Should return empty
```

---

### 3. Implement Application CI/CD Pipelines

**Current State**: Only infrastructure CI/CD exists. No application deployment pipelines.

**Required Pipelines**:

#### EKS Application Pipeline

Create `.github/workflows/app-deploy-eks.yml`:

```yaml
name: Deploy to EKS

on:
  push:
    branches: [develop]  # Auto-deploy to dev
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options: [dev, staging, production, production-pci]

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
          aws-region: us-east-1
      
      - name: Login to ECR
        id: ecr
        uses: aws-actions/amazon-ecr-login@v2
      
      - name: Build and push image
        env:
          ECR_REGISTRY: ${{ steps.ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/myapp:$IMAGE_TAG .
          docker push $ECR_REGISTRY/myapp:$IMAGE_TAG
    
    outputs:
      image-tag: ${{ github.sha }}

  security-scan:
    needs: build-and-push
    runs-on: ubuntu-latest
    steps:
      - name: Scan image with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ needs.build-and-push.outputs.ecr-registry }}/myapp:${{ needs.build-and-push.outputs.image-tag }}
          severity: 'CRITICAL,HIGH'
          exit-code: '1'  # Fail on findings

  deploy:
    needs: [build-and-push, security-scan]
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment || 'dev' }}
    steps:
      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig --name ${{ github.event.inputs.environment }}-eks
      
      - name: Deploy to Kubernetes
        run: |
          kubectl set image deployment/myapp \
            myapp=${{ steps.ecr.outputs.registry }}/myapp:${{ needs.build-and-push.outputs.image-tag }}
          kubectl rollout status deployment/myapp
```

#### EC2 Application Pipeline

Create `.github/workflows/app-deploy-ec2.yml` with CodeDeploy integration (similar structure to EKS pipeline).

**Required Infrastructure**:
- ECR repositories: `terraform apply` in `modules/environment/ecr.tf` (needs creation)
- CodeDeploy applications: Add to `modules/environment/codedeploy.tf`
- IAM roles for GitHub Actions (OIDC provider)

---

### 4. Production Approval Gates

**Implementation**: Configure GitHub Environment protection rules.

**Steps**:
1. GitHub Repository → Settings → Environments
2. Create environments: `production`, `production-pci`
3. Configure protection rules:

**Production Environment:**
- Required reviewers: 2 (from @devops-team)
- Wait timer: 5 minutes
- Deployment branches: `main` only
- Secrets: AWS credentials, EKS cluster names

**Production-PCI Environment:**
- Required reviewers: 3 (2 DevOps + 1 Security)
- Wait timer: 10 minutes
- Deployment branches: `main` only
- Additional approval from Security team required

**Workflow Integration**:

The `environment:` key in workflows automatically enforces these rules:

```yaml
deploy:
  runs-on: ubuntu-latest
  environment: production  # Triggers approval gate
  steps:
    - name: Deploy
      run: kubectl apply -f k8s/
```

**Slack Notifications** (optional enhancement):

```yaml
- name: Request approval
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "🚀 Production deployment requires approval",
        "blocks": [{
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": "Commit: `${{ github.sha }}`\n<${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}|View workflow>"
          }
        }]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

---

### 5. Application Promotion Process

**Strategy**: Progressive deployment with quality gates at each stage.

**Promotion Flow**:
```
develop branch → dev (auto-deploy)
  ↓ smoke tests pass
main branch → staging (auto-deploy)
  ↓ integration tests + load tests + 24h soak
manual trigger → production (2 DevOps approvals)
  ↓ 48h soak + monitoring
manual trigger → production-pci (3 approvals: 2 DevOps + 1 Security)
```

**Implementation**: Create `.github/workflows/promote.yml`:

```yaml
name: Promote Application

on:
  workflow_dispatch:
    inputs:
      from_environment:
        type: choice
        options: [dev, staging, production]
      to_environment:
        type: choice
        options: [staging, production, production-pci]

jobs:
  validate-promotion-path:
    runs-on: ubuntu-latest
    steps:
      - name: Check promotion rules
        run: |
          # dev → staging only
          # staging → production only
          # production → production-pci only
          if [[ "${{ inputs.from_environment }}" == "dev" && "${{ inputs.to_environment }}" != "staging" ]]; then
            echo "ERROR: Can only promote from dev to staging"
            exit 1
          fi

  get-version:
    needs: validate-promotion-path
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.get-tag.outputs.tag }}
    steps:
      - name: Get current version from source
        id: get-tag
        run: |
          aws eks update-kubeconfig --name ${{ inputs.from_environment }}-eks
          TAG=$(kubectl get deployment myapp -o jsonpath='{.spec.template.spec.containers[0].image}' | cut -d':' -f2)
          echo "tag=$TAG" >> $GITHUB_OUTPUT

  run-tests:
    needs: get-version
    runs-on: ubuntu-latest
    steps:
      - name: Integration tests
        run: |
          # Run test suite against source environment
          npm test -- --env=${{ inputs.from_environment }}
      
      - name: Load tests (production only)
        if: inputs.to_environment == 'production'
        run: k6 run loadtest.js --env=${{ inputs.from_environment }}

  promote:
    needs: [get-version, run-tests]
    runs-on: ubuntu-latest
    environment: ${{ inputs.to_environment }}  # Triggers approval gate
    steps:
      - name: Deploy to target environment
        run: |
          aws eks update-kubeconfig --name ${{ inputs.to_environment }}-eks
          kubectl set image deployment/myapp \
            myapp=$ECR_REGISTRY/myapp:${{ needs.get-version.outputs.image-tag }}
          kubectl rollout status deployment/myapp
```

**Validation Requirements Per Stage**:

| Stage | Tests | Approvals | Soak Period |
|-------|-------|-----------|-------------|
| dev → staging | Smoke tests | 0 | None |
| staging → production | Integration + Load + Security | 2 DevOps | 24h minimum |
| production → production-pci | All staging tests + PCI compliance | 2 DevOps + 1 Security | 48h minimum |

---

## Medium Priority Items

### Pod-to-Pod Encryption

**Requirement**: Traffic secure when leaving EKS cluster.

**Solution**: AWS App Mesh with mutual TLS (mTLS).

**Implementation Steps**:

1. **Create App Mesh** (`modules/environment/app-mesh.tf`):

```hcl
resource "aws_appmesh_mesh" "main" {
  name = "${var.environment}-mesh"
  
  spec {
    egress_filter {
      type = "ALLOW_ALL"
    }
  }
}

resource "aws_appmesh_virtual_gateway" "main" {
  name      = "${var.environment}-gateway"
  mesh_name = aws_appmesh_mesh.main.name
  
  spec {
    listener {
      port_mapping {
        port     = 443
        protocol = "http"
      }
      
      tls {
        mode = "STRICT"
        certificate {
          acm {
            certificate_arn = var.acm_certificate_arn
          }
        }
      }
    }
  }
}
```

2. **Deploy App Mesh Controller to EKS**:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm upgrade -i appmesh-controller eks/appmesh-controller \
  --namespace appmesh-system \
  --set region=us-east-1 \
  --set serviceAccount.create=true \
  --set serviceAccount.name=appmesh-controller
```

3. **Configure Services for mTLS**:

```yaml
# kubernetes/virtual-service.yaml
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualService
metadata:
  name: myapp
spec:
  meshName: production-mesh
  provider:
    virtualNode:
      virtualNodeName: myapp-vn
  listeners:
    - portMapping:
        port: 8080
        protocol: http
      tls:
        mode: STRICT
        certificate:
          acm:
            certificateARN: arn:aws:acm:...
```

**Validation**:
```bash
# Check mTLS is enforced
kubectl exec -it pod/test-pod -- curl -v https://myapp.default.svc:8080
# Should see TLS handshake in output
```

**Alternative**: Kubernetes Network Policies + VPC CNI security groups (simpler but less feature-rich).

---

### Blue/Green Deployments

**Requirement**: Zero-downtime deployments with instant rollback.

#### For EKS: Argo Rollouts

**Installation**:
```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

**Rollout Configuration**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  replicas: 5
  strategy:
    blueGreen:
      activeService: myapp-active      # Production traffic
      previewService: myapp-preview    # Testing traffic
      autoPromotionEnabled: false      # Manual promotion
      scaleDownDelaySeconds: 30
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:v2
        ports:
        - containerPort: 8080
```

**Deployment Process**:
```bash
# Deploy new version (green)
kubectl argo rollouts set image myapp myapp=myapp:v2

# Preview in test environment
kubectl argo rollouts promote myapp --preview

# Promote to production after validation
kubectl argo rollouts promote myapp

# Instant rollback if issues
kubectl argo rollouts undo myapp
```

#### For EC2: AWS CodeDeploy

**Configuration** (`modules/environment/codedeploy-bluegreen.tf`):

```hcl
resource "aws_codedeploy_deployment_group" "blue_green" {
  app_name               = aws_codedeploy_app.main.name
  deployment_group_name  = "myapp-blue-green-dg"
  service_role_arn       = aws_iam_role.codedeploy.arn
  
  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 30
    }
    
    deployment_ready_option {
      action_on_timeout    = "STOP_DEPLOYMENT"
      wait_time_in_minutes = 15  # Manual approval window
    }
    
    green_fleet_provisioning_option {
      action = "COPY_AUTO_SCALING_GROUP"
    }
  }
  
  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.https.arn]
      }
      target_group {
        name = aws_lb_target_group.blue.name
      }
      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }
  
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }
}
```

**Deployment**:
```bash
aws deploy create-deployment \
  --application-name myapp-production \
  --deployment-group-name myapp-blue-green-dg \
  --s3-location bucket=deployments,key=myapp-v2.zip,bundleType=zip
```

---

## Pre-Production Checklist

Before going live, complete these tasks:

### Security
- [ ] Update `devops_ip_ranges` in all environments
- [ ] Update `eks_public_access_cidrs` to restrict EKS API
- [ ] Provision ACM SSL certificates for ALBs
- [ ] Enable AWS GuardDuty
- [ ] Enable AWS Security Hub
- [ ] Configure AWS Config rules
- [ ] Set up MFA for all AWS accounts
- [ ] Review all `TODO` comments in codebase
- [ ] Conduct security audit of all security groups

### Monitoring
- [ ] Set up CloudWatch alarms for critical metrics
- [ ] Configure SNS topics for alerting
- [ ] Set up PagerDuty/OpsGenie integration
- [ ] Enable CloudWatch Container Insights for EKS
- [ ] Configure log aggregation (e.g., Datadog, Splunk)
- [ ] Set up performance dashboards

### Backup & DR
- [ ] Verify RDS automated backups (7-day retention configured)
- [ ] Test RDS point-in-time recovery
- [ ] Document disaster recovery runbooks
- [ ] Test failover procedures (RDS Multi-AZ, ElastiCache)
- [ ] Configure cross-region backup replication (if required)

### Compliance (PCI-DSS for Production-PCI)
- [ ] Verify data tier isolation (no peering routes)
- [ ] Confirm all data encrypted at rest and in transit
- [ ] Enable audit logging (365-day retention)
- [ ] Document data flow diagrams
- [ ] Conduct vulnerability scans
- [ ] Implement intrusion detection (AWS GuardDuty)
- [ ] Quarterly access reviews documented

### Operations
- [ ] Create operational runbooks for common tasks
- [ ] Document incident response procedures
- [ ] Set up on-call rotation
- [ ] Train team on deployment processes
- [ ] Conduct disaster recovery drill
- [ ] Document rollback procedures

---

## Cost Optimization

### Current Monthly Estimate (Production)

Based on infrastructure design:

| Service | Quantity | Monthly Cost (est.) |
|---------|----------|---------------------|
| EC2 (t3.medium) | 3 instances | ~$75 |
| NAT Gateways | 3 (HA) | ~$100 |
| ALBs | 2 (public + internal) | ~$50 |
| EKS Control Plane | 1 | $72 |
| EKS Nodes (t3.medium) | 3 instances | ~$75 |
| RDS (db.t3.micro Multi-AZ) | 1 | ~$50 |
| ElastiCache (cache.t3.medium) | 3 nodes | ~$120 |
| MSK (kafka.t3.small) | 3 brokers | ~$180 |
| OpenSearch (t3.medium) | 3 data + 3 master | ~$350 |
| **Total** | | **~$1,072/month** |

### Cost Savings Opportunities

**Non-Production Environments**:
- [ ] Use Spot instances for EKS nodes (60-90% savings)
- [ ] Single NAT Gateway instead of 3
- [ ] Smaller instance types (t3.micro/small)
- [ ] Reduce EKS node count to 1-2
- [ ] Schedule shutdowns for off-hours

**Production Optimizations**:
- [ ] Reserved Instances for stable workloads (1-year: 30% savings, 3-year: 50%)
- [ ] Savings Plans for compute-heavy workloads
- [ ] Right-size instances based on CloudWatch metrics
- [ ] Use gp3 instead of gp2 for EBS (20% cheaper, better performance)
- [ ] S3 Intelligent-Tiering for logs/backups
- [ ] ElastiCache reserved nodes (40-60% savings)

---

## Success Metrics

### Infrastructure Health
- **Uptime SLA**: 99.9% (43 minutes downtime/month)
- **Deployment frequency**: Daily to dev/staging, weekly to production
- **Mean time to recovery**: < 1 hour
- **Change failure rate**: < 5%

### Security
- **Critical vulnerabilities**: 0 in production
- **Security scan coverage**: 100% of deployments
- **Incident response time**: < 15 minutes
- **Access reviews**: Quarterly for production, monthly for production-pci

### Operations
- **Deployment time**: < 15 minutes
- **Rollback time**: < 5 minutes
- **Alert noise**: < 5 false positives/week
- **Documentation coverage**: 100% of runbooks

---

## Next Steps

**Week 1-2: Critical Security**
1. Update `devops_ip_ranges` across all environments
2. Update `eks_public_access_cidrs` to restrict EKS API
3. Deploy VPC peering between production environments
4. Verify cross-VPC connectivity and isolation

**Week 3-4: CI/CD Foundation**
1. Create ECR repositories for application images
2. Implement EKS application deployment pipeline
3. Implement EC2 application deployment pipeline (CodeDeploy)
4. Configure GitHub environment protection rules

**Week 5-6: Promotion & Approval**
1. Implement application promotion workflow
2. Set up production approval gates (2+ reviewers)
3. Configure Slack notifications for deployments
4. Create promotion runbooks

**Week 7-8: Blue/Green & Monitoring**
1. Deploy Argo Rollouts to EKS clusters
2. Configure CodeDeploy blue/green for EC2
3. Implement comprehensive CloudWatch alarms
4. Set up centralized logging/monitoring dashboard

**Week 9: Documentation & Training**
1. Complete operational runbooks
2. Conduct team training on deployment processes
3. Disaster recovery drill
4. Security audit

---

## Support & Escalation

**For Infrastructure Issues**:
- Slack: #infrastructure
- Email: devops@company.com
- On-call: PagerDuty rotation

**For Security Incidents**:
- Slack: #security-incidents
- Email: security@company.com
- Escalation: Follow incident response playbook

**For Compliance Questions** (Production-PCI):
- Slack: #compliance
- Email: compliance@company.com

---

## Requirements Compliance Status

| Requirement | Status | Priority | Notes |
|-------------|--------|----------|-------|
| **Network Architecture** |
| Multi-tier VPC (public/app/data subnets) | ✅ Complete | - | 3 AZs, NAT per AZ |
| Servers/pods reach app resources | ✅ Complete | - | Security groups configured |
| Cross-VPC connectivity (Prod ↔ Prod-PCI) | ⚠️ Tool Available | **HIGH** | CDKTF peering tool ready for deployment |
| ALB-only cross-VPC traffic | ✅ Complete | - | Data tier excludes peering routes |
| Pod traffic encryption | ❌ Not Implemented | **MEDIUM** | Requires service mesh |
| Route table examples | ✅ Complete | - | Documented in README |
| **Security & Access Control** |
| Network security rules | ✅ Complete | - | 3-tier isolation (ALB→App→Data) |
| DevOps-only admin ports | ⚠️ Overly Permissive | **CRITICAL** | `devops_ip_ranges = ["0.0.0.0/0"]` |
| ALB-only app ports | ✅ Complete | - | Port 8080 restricted to ALB SG |
| DevOps EKS admin access | ✅ Complete | - | IAM role → `system:masters` |
| Dev EKS read-only access | ✅ Complete | - | IAM role → `view-only` ClusterRole |
| Secure secrets storage | ✅ Complete | - | Parameter Store + KMS |
| **CI/CD & Deployments** |
| Code deployment process | ❌ Not Implemented | **HIGH** | Need app pipelines (EKS + EC2) |
| Production approval gates | ❌ Not Implemented | **HIGH** | GitHub environments + reviewers |
| Promotion process (dev→staging→prod) | ❌ Not Implemented | **HIGH** | Multi-stage pipeline |
| Blue/green deployments | ❌ Not Implemented | **MEDIUM** | Argo Rollouts + CodeDeploy |
| **Infrastructure Automation** |
| Terraform modules | ✅ Complete | - | All services modularized + tested |
| CI/CD for infrastructure | ✅ Complete | - | GitHub Actions + Docker tooling |

---

## Critical Action Items

### 1. Restrict DevOps Access (SECURITY CRITICAL)

**Current Risk**: SSH/RDP accessible from any IP address.

**Solution**: Update all environment `terraform.tfvars`:

```hcl
# environments/production/terraform.tfvars
devops_ip_ranges = [
  "203.0.113.0/24",    # Office Network
  "198.51.100.0/24",   # VPN Concentrator
  "192.0.2.0/24",      # Bastion Host
]

# environments/production-pci/terraform.tfvars
devops_ip_ranges = [
  "203.0.113.0/24",    # Office Only (more restrictive)
]
```

**Apply immediately**:
```bash
make plan ENV=production
make apply ENV=production
```

**Validation**:
```bash
# From approved IP - should succeed
ssh ec2-user@<instance-ip>

# From non-approved IP - should timeout
ssh ec2-user@<instance-ip>  # Connection refused
```

---

### 2. Deploy VPC Peering

**Current State**: CDKTF VPC peering tool exists but is not deployed.

**Deployment Steps**:

```bash
# 1. Get VPC IDs from Terraform outputs
cd environments/production
terraform output vpc_id  # vpc-0prod123
cd ../production-pci
terraform output vpc_id  # vpc-0pci456

# 2. Create peering configuration
cd <cdktf-peering-tool-directory>
cat > peering.yaml <<EOF
peers:
  production:
    vpc_id: vpc-0prod123  # From step 1
    region: us-east-1
    role_arn: "arn:aws:iam::111111111111:role/TerraformRole"
    dns_resolution: true
    has_additional_routes: true
  
  production-pci:
    vpc_id: vpc-0pci456   # From step 1
    region: us-east-1
    role_arn: "arn:aws:iam::222222222222:role/TerraformRole"
    dns_resolution: true
    has_additional_routes: true

peering_matrix:
  production:
    - production-pci
EOF

# 3. Deploy peering
make get      # Generate provider bindings
make synth    # Synthesize Terraform
make plan     # Preview changes
make deploy   # Apply peering

# 4. Verify connectivity
aws ec2 describe-vpc-peering-connections \
  --filters "Name=status-code,Values=active"
```

**Security Validation**:

After peering is established, verify isolation:

```bash
# From Production EC2 instance:
# 1. Test app-to-app via Internal ALB (should succeed)
curl http://internal-prod-pci-alb.example.com/health

# 2. Test direct DB access (should fail - no route)
nc -zv 10.21.21.30 5432  # Production-PCI RDS private IP
# Connection timeout (expected - data tier has no peering routes)
```

**Route Table Verification**:
```bash
# App subnet route table (should have peering route)
aws ec2 describe-route-tables \
  --route-table-ids rtb-app-XXXXX \
  --query 'RouteTables[*].Routes[?VpcPeeringConnectionId!=`null`]'

# Data subnet route table (should NOT have peering route)
aws ec2 describe-route-tables \
  --route-table-ids rtb-data-XXXXX \
  --query 'RouteTables[*].Routes[?VpcPeeringConnectionId!=`null`]'
# Should return empty
```

---

### 3. Implement Application CI/CD Pipelines

**Current State**: Only infrastructure CI/CD exists. No application deployment pipelines.

**Required Pipelines**:

#### EKS Application Pipeline

Create `.github/workflows/app-deploy-eks.yml`:

```yaml
name: Deploy to EKS

on:
  push:
    branches: [develop]  # Auto-deploy to dev
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options: [dev, staging, production, production-pci]

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
          aws-region: us-east-1
      
      - name: Login to ECR
        id: ecr
        uses: aws-actions/amazon-ecr-login@v2
      
      - name: Build and push image
        env:
          ECR_REGISTRY: ${{ steps.ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/myapp:$IMAGE_TAG .
          docker push $ECR_REGISTRY/myapp:$IMAGE_TAG
    
    outputs:
      image-tag: ${{ github.sha }}

  security-scan:
    needs: build-and-push
    runs-on: ubuntu-latest
    steps:
      - name: Scan image with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ needs.build-and-push.outputs.ecr-registry }}/myapp:${{ needs.build-and-push.outputs.image-tag }}
          severity: 'CRITICAL,HIGH'
          exit-code: '1'  # Fail on findings

  deploy:
    needs: [build-and-push, security-scan]
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment || 'dev' }}
    steps:
      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig --name ${{ github.event.inputs.environment }}-eks
      
      - name: Deploy to Kubernetes
        run: |
          kubectl set image deployment/myapp \
            myapp=${{ steps.ecr.outputs.registry }}/myapp:${{ needs.build-and-push.outputs.image-tag }}
          kubectl rollout status deployment/myapp
```

#### EC2 Application Pipeline

Create `.github/workflows/app-deploy-ec2.yml` with CodeDeploy integration (similar structure to EKS pipeline).

**Required Infrastructure**:
- ECR repositories: `terraform apply` in `modules/environment/ecr.tf` (needs creation)
- CodeDeploy applications: Add to `modules/environment/codedeploy.tf`
- IAM roles for GitHub Actions (OIDC provider)

---

### 4. Production Approval Gates

**Implementation**: Configure GitHub Environment protection rules.

**Steps**:
1. GitHub Repository → Settings → Environments
2. Create environments: `production`, `production-pci`
3. Configure protection rules:

**Production Environment:**
- Required reviewers: 2 (from @devops-team)
- Wait timer: 5 minutes
- Deployment branches: `main` only
- Secrets: AWS credentials, EKS cluster names

**Production-PCI Environment:**
- Required reviewers: 3 (2 DevOps + 1 Security)
- Wait timer: 10 minutes
- Deployment branches: `main` only
- Additional approval from Security team required

**Workflow Integration**:

The `environment:` key in workflows automatically enforces these rules:

```yaml
deploy:
  runs-on: ubuntu-latest
  environment: production  # Triggers approval gate
  steps:
    - name: Deploy
      run: kubectl apply -f k8s/
```

**Slack Notifications** (optional enhancement):

```yaml
- name: Request approval
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "🚀 Production deployment requires approval",
        "blocks": [{
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": "Commit: `${{ github.sha }}`\n<${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}|View workflow>"
          }
        }]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

---

### 5. Application Promotion Process

**Strategy**: Progressive deployment with quality gates at each stage.

**Promotion Flow**:
```
develop branch → dev (auto-deploy)
  ↓ smoke tests pass
main branch → staging (auto-deploy)
  ↓ integration tests + load tests + 24h soak
manual trigger → production (2 DevOps approvals)
  ↓ 48h soak + monitoring
manual trigger → production-pci (3 approvals: 2 DevOps + 1 Security)
```

**Implementation**: Create `.github/workflows/promote.yml`:

```yaml
name: Promote Application

on:
  workflow_dispatch:
    inputs:
      from_environment:
        type: choice
        options: [dev, staging, production]
      to_environment:
        type: choice
        options: [staging, production, production-pci]

jobs:
  validate-promotion-path:
    runs-on: ubuntu-latest
    steps:
      - name: Check promotion rules
        run: |
          # dev → staging only
          # staging → production only
          # production → production-pci only
          if [[ "${{ inputs.from_environment }}" == "dev" && "${{ inputs.to_environment }}" != "staging" ]]; then
            echo "ERROR: Can only promote from dev to staging"
            exit 1
          fi

  get-version:
    needs: validate-promotion-path
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.get-tag.outputs.tag }}
    steps:
      - name: Get current version from source
        id: get-tag
        run: |
          aws eks update-kubeconfig --name ${{ inputs.from_environment }}-eks
          TAG=$(kubectl get deployment myapp -o jsonpath='{.spec.template.spec.containers[0].image}' | cut -d':' -f2)
          echo "tag=$TAG" >> $GITHUB_OUTPUT

  run-tests:
    needs: get-version
    runs-on: ubuntu-latest
    steps:
      - name: Integration tests
        run: |
          # Run test suite against source environment
          npm test -- --env=${{ inputs.from_environment }}
      
      - name: Load tests (production only)
        if: inputs.to_environment == 'production'
        run: k6 run loadtest.js --env=${{ inputs.from_environment }}

  promote:
    needs: [get-version, run-tests]
    runs-on: ubuntu-latest
    environment: ${{ inputs.to_environment }}  # Triggers approval gate
    steps:
      - name: Deploy to target environment
        run: |
          aws eks update-kubeconfig --name ${{ inputs.to_environment }}-eks
          kubectl set image deployment/myapp \
            myapp=$ECR_REGISTRY/myapp:${{ needs.get-version.outputs.image-tag }}
          kubectl rollout status deployment/myapp
```

**Validation Requirements Per Stage**:

| Stage | Tests | Approvals | Soak Period |
|-------|-------|-----------|-------------|
| dev → staging | Smoke tests | 0 | None |
| staging → production | Integration + Load + Security | 2 DevOps | 24h minimum |
| production → production-pci | All staging tests + PCI compliance | 2 DevOps + 1 Security | 48h minimum |

---

## Medium Priority Items

### Pod-to-Pod Encryption

**Requirement**: Traffic secure when leaving EKS cluster.

**Solution**: AWS App Mesh with mutual TLS (mTLS).

**Implementation Steps**:

1. **Create App Mesh** (`modules/environment/app-mesh.tf`):

```hcl
resource "aws_appmesh_mesh" "main" {
  name = "${var.environment}-mesh"
  
  spec {
    egress_filter {
      type = "ALLOW_ALL"
    }
  }
}

resource "aws_appmesh_virtual_gateway" "main" {
  name      = "${var.environment}-gateway"
  mesh_name = aws_appmesh_mesh.main.name
  
  spec {
    listener {
      port_mapping {
        port     = 443
        protocol = "http"
      }
      
      tls {
        mode = "STRICT"
        certificate {
          acm {
            certificate_arn = var.acm_certificate_arn
          }
        }
      }
    }
  }
}
```

2. **Deploy App Mesh Controller to EKS**:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm upgrade -i appmesh-controller eks/appmesh-controller \
  --namespace appmesh-system \
  --set region=us-east-1 \
  --set serviceAccount.create=true \
  --set serviceAccount.name=appmesh-controller
```

3. **Configure Services for mTLS**:

```yaml
# kubernetes/virtual-service.yaml
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualService
metadata:
  name: myapp
spec:
  meshName: production-mesh
  provider:
    virtualNode:
      virtualNodeName: myapp-vn
  listeners:
    - portMapping:
        port: 8080
        protocol: http
      tls:
        mode: STRICT
        certificate:
          acm:
            certificateARN: arn:aws:acm:...
```

**Validation**:
```bash
# Check mTLS is enforced
kubectl exec -it pod/test-pod -- curl -v https://myapp.default.svc:8080
# Should see TLS handshake in output
```

**Alternative**: Kubernetes Network Policies + VPC CNI security groups (simpler but less feature-rich).

---

### Blue/Green Deployments

**Requirement**: Zero-downtime deployments with instant rollback.

#### For EKS: Argo Rollouts

**Installation**:
```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

**Rollout Configuration**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  replicas: 5
  strategy:
    blueGreen:
      activeService: myapp-active      # Production traffic
      previewService: myapp-preview    # Testing traffic
      autoPromotionEnabled: false      # Manual promotion
      scaleDownDelaySeconds: 30
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:v2
        ports:
        - containerPort: 8080
```

**Deployment Process**:
```bash
# Deploy new version (green)
kubectl argo rollouts set image myapp myapp=myapp:v2

# Preview in test environment
kubectl argo rollouts promote myapp --preview

# Promote to production after validation
kubectl argo rollouts promote myapp

# Instant rollback if issues
kubectl argo rollouts undo myapp
```

#### For EC2: AWS CodeDeploy

**Configuration** (`modules/environment/codedeploy-bluegreen.tf`):

```hcl
resource "aws_codedeploy_deployment_group" "blue_green" {
  app_name               = aws_codedeploy_app.main.name
  deployment_group_name  = "myapp-blue-green-dg"
  service_role_arn       = aws_iam_role.codedeploy.arn
  
  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 30
    }
    
    deployment_ready_option {
      action_on_timeout    = "STOP_DEPLOYMENT"
      wait_time_in_minutes = 15  # Manual approval window
    }
    
    green_fleet_provisioning_option {
      action = "COPY_AUTO_SCALING_GROUP"
    }
  }
  
  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.https.arn]
      }
      target_group {
        name = aws_lb_target_group.blue.name
      }
      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }
  
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }
}
```

**Deployment**:
```bash
aws deploy create-deployment \
  --application-name myapp-production \
  --deployment-group-name myapp-blue-green-dg \
  --s3-location bucket=deployments,key=myapp-v2.zip,bundleType=zip
```

---

## Pre-Production Checklist

Before going live, complete these tasks:

### Security
- [ ] Update `devops_ip_ranges` in all environments
- [ ] Update `eks_public_access_cidrs` to restrict EKS API
- [ ] Provision ACM SSL certificates for ALBs
- [ ] Enable AWS GuardDuty
- [ ] Enable AWS Security Hub
- [ ] Configure AWS Config rules
- [ ] Set up MFA for all AWS accounts
- [ ] Review all `TODO` comments in codebase
- [ ] Conduct security audit of all security groups

### Monitoring
- [ ] Set up CloudWatch alarms for critical metrics
- [ ] Configure SNS topics for alerting
- [ ] Set up PagerDuty/OpsGenie integration
- [ ] Enable CloudWatch Container Insights for EKS
- [ ] Configure log aggregation (e.g., Datadog, Splunk)
- [ ] Set up performance dashboards

### Backup & DR
- [ ] Verify RDS automated backups (7-day retention configured)
- [ ] Test RDS point-in-time recovery
- [ ] Document disaster recovery runbooks
- [ ] Test failover procedures (RDS Multi-AZ, ElastiCache)
- [ ] Configure cross-region backup replication (if required)

### Compliance (PCI-DSS for Production-PCI)
- [ ] Verify data tier isolation (no peering routes)
- [ ] Confirm all data encrypted at rest and in transit
- [ ] Enable audit logging (365-day retention)
- [ ] Document data flow diagrams
- [ ] Conduct vulnerability scans
- [ ] Implement intrusion detection (AWS GuardDuty)
- [ ] Quarterly access reviews documented

### Operations
- [ ] Create operational runbooks for common tasks
- [ ] Document incident response procedures
- [ ] Set up on-call rotation
- [ ] Train team on deployment processes
- [ ] Conduct disaster recovery drill
- [ ] Document rollback procedures

---

## Cost Optimization

### Current Monthly Estimate (Production)

Based on infrastructure design:

| Service | Quantity | Monthly Cost (est.) |
|---------|----------|---------------------|
| EC2 (t3.medium) | 3 instances | ~$75 |
| NAT Gateways | 3 (HA) | ~$100 |
| ALBs | 2 (public + internal) | ~$50 |
| EKS Control Plane | 1 | $72 |
| EKS Nodes (t3.medium) | 3 instances | ~$75 |
| RDS (db.t3.micro Multi-AZ) | 1 | ~$50 |
| ElastiCache (cache.t3.medium) | 3 nodes | ~$120 |
| MSK (kafka.t3.small) | 3 brokers | ~$180 |
| OpenSearch (t3.medium) | 3 data + 3 master | ~$350 |
| **Total** | | **~$1,072/month** |

### Cost Savings Opportunities

**Non-Production Environments**:
- [ ] Use Spot instances for EKS nodes (60-90% savings)
- [ ] Single NAT Gateway instead of 3
- [ ] Smaller instance types (t3.micro/small)
- [ ] Reduce EKS node count to 1-2
- [ ] Schedule shutdowns for off-hours

**Production Optimizations**:
- [ ] Reserved Instances for stable workloads (1-year: 30% savings, 3-year: 50%)
- [ ] Savings Plans for compute-heavy workloads
- [ ] Right-size instances based on CloudWatch metrics
- [ ] Use gp3 instead of gp2 for EBS (20% cheaper, better performance)
- [ ] S3 Intelligent-Tiering for logs/backups
- [ ] ElastiCache reserved nodes (40-60% savings)

---

## Success Metrics

### Infrastructure Health
- **Uptime SLA**: 99.9% (43 minutes downtime/month)
- **Deployment frequency**: Daily to dev/staging, weekly to production
- **Mean time to recovery**: < 1 hour
- **Change failure rate**: < 5%

### Security
- **Critical vulnerabilities**: 0 in production
- **Security scan coverage**: 100% of deployments
- **Incident response time**: < 15 minutes
- **Access reviews**: Quarterly for production, monthly for production-pci

### Operations
- **Deployment time**: < 15 minutes
- **Rollback time**: < 5 minutes
- **Alert noise**: < 5 false positives/week
- **Documentation coverage**: 100% of runbooks

---

## Next Steps

**Week 1-2: Critical Security**
1. Update `devops_ip_ranges` across all environments
2. Update `eks_public_access_cidrs` to restrict EKS API
3. Deploy VPC peering between production environments
4. Verify cross-VPC connectivity and isolation

**Week 3-4: CI/CD Foundation**
1. Create ECR repositories for application images
2. Implement EKS application deployment pipeline
3. Implement EC2 application deployment pipeline (CodeDeploy)
4. Configure GitHub environment protection rules

**Week 5-6: Promotion & Approval**
1. Implement application promotion workflow
2. Set up production approval gates (2+ reviewers)
3. Configure Slack notifications for deployments
4. Create promotion runbooks

**Week 7-8: Blue/Green & Monitoring**
1. Deploy Argo Rollouts to EKS clusters
2. Configure CodeDeploy blue/green for EC2
3. Implement comprehensive CloudWatch alarms
4. Set up centralized logging/monitoring dashboard

**Week 9: Documentation & Training**
1. Complete operational runbooks
2. Conduct team training on deployment processes
3. Disaster recovery drill
4. Security audit

---

## Support & Escalation

**For Infrastructure Issues**:
- Slack: #infrastructure
- Email: devops@company.com
- On-call: PagerDuty rotation

**For Security Incidents**:
- Slack: #security-incidents
- Email: security@company.com
- Escalation: Follow incident response playbook

**For Compliance Questions** (Production-PCI):
- Slack: #compliance
- Email: compliance@company.com
