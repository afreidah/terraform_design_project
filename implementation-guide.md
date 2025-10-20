# Implementation Guide - Infrastructure Design Exercise

This document provides detailed implementation guidance to achieve full compliance with the Infrastructure Design Exercise requirements.

---

## Current Status Summary

| Requirement Category | Status | Priority |
|---------------------|--------|----------|
| Network Architecture | ✅ Complete | - |
| VPC Connectivity | ⚠️ Solution Available (CDKTF Tool) | **HIGH** |
| Security Groups & Access Control | ⚠️ Partially Implemented | **HIGH** |
| EKS RBAC | ❌ Not Implemented | **HIGH** |
| Secrets Management | ✅ Complete | - |
| CI/CD Pipeline | ❌ Not Implemented | **HIGH** |
| Deployment Approvals | ❌ Not Implemented | **HIGH** |
| Promotion Process | ❌ Not Implemented | **MEDIUM** |
| Route Table Examples | ❌ Not Implemented | **MEDIUM** |
| Blue/Green Deployments | ❌ Not Implemented | **LOW** |
| Infrastructure Automation | ✅ Complete | - |

---

## 1. Security & Access Control

### 1.1 Restrict DevOps Access to Admin Ports

**Requirement**: *"Ensure only DevOps can reach pods and servers on admin ports (22, 3389, etc...)"*

**Current Gap**: `devops_ip_ranges = ["0.0.0.0/0"]` allows all traffic on admin ports, presenting a critical security vulnerability.

**Implementation Strategy**:

The infrastructure already supports IP-based access restrictions through the `devops_ip_ranges` variable. The implementation requires updating this variable in each environment's `terraform.tfvars` file with actual office and VPN CIDR blocks.

**Configuration Steps**:
1. Gather legitimate DevOps access points (office networks, VPN concentrators, bastion hosts)
2. Document CIDR blocks for each access point
3. Update environment configurations with restrictive CIDR lists
4. Apply more stringent restrictions for PCI environments
5. Test access from approved and non-approved IP addresses
6. Deploy incrementally: dev → staging → production

**Expected Security Group Behavior**:
- SSH (port 22) and RDP (port 3389) accessible only from specified DevOps IP ranges
- All other administrative ports similarly restricted
- Connection attempts from non-approved IPs should timeout or be refused
- CloudWatch logs should capture all connection attempts for audit purposes

**Validation Requirements**:
- Successful SSH/RDP from approved IP ranges
- Failed connection attempts from non-approved ranges
- Audit log review showing proper access control enforcement
- No degradation of legitimate DevOps workflows

---

### 1.2 Implement EKS RBAC

**Requirement**: 
- *"Ensure only DevOps has EKS cluster admin access"*
- *"Ensure Dev has EKS cluster read only access"*

**Current Gap**: No role-based access control configuration exists for EKS clusters.

**Implementation Strategy**:

The existing infrastructure includes EKS clusters but lacks the RBAC configuration to control access. Implementation requires three components:

**IAM Role Configuration**:
Create separate IAM roles for DevOps (admin access) and Dev (read-only access). These roles should be assumable by appropriate user groups and federated through the organization's identity provider.

**aws-auth ConfigMap**:
The aws-auth ConfigMap in the kube-system namespace maps IAM roles to Kubernetes RBAC groups. DevOps roles should map to the `system:masters` group for full cluster control. Dev roles should map to a custom read-only group.

**Kubernetes RBAC Resources**:
Create ClusterRole and ClusterRoleBinding resources defining the read-only access pattern. The view-only ClusterRole should permit get, list, and watch operations across all resources but deny all write operations (create, update, patch, delete).

**Key Implementation Details**:
- DevOps roles: Full cluster admin via system:masters group
- Dev roles: Read-only access via custom view-only ClusterRole
- Pod logs: Read access permitted for Dev team
- Exec into pods: Restricted to DevOps team only
- Resource deletion: DevOps only
- ConfigMap/Secret viewing: Consider restricting based on namespace

**Validation Requirements**:
- DevOps users can perform all kubectl operations including deletions
- Dev users can view all resources but cannot modify anything
- Dev users can read pod logs but cannot exec into pods
- Authentication failures properly logged
- Role assumption audit trail captured in CloudTrail

---

### 1.3 Verify Security Group Rules

**Requirement**: 
- *"Ensure only load balancers can reach applications on internal app ports (8080, 80, etc...)"*
- *"Provide network security rules and configuration"*

**Current Gap**: Security group rules exist within the module but require verification and documentation.

**Expected Security Group Architecture**:

**Public ALB Security Group**:
- Ingress: Ports 80/443 from 0.0.0.0/0 (internet-facing)
- Egress: Port 8080 to App Server Security Group only

**App Server Security Group**:
- Ingress: Port 8080 from ALB Security Group only (not from 0.0.0.0/0)
- Ingress: Port 22 from DevOps IP ranges only
- Egress: Port 5432 to RDS Security Group
- Egress: Port 6379 to ElastiCache Security Group  
- Egress: Port 443 to 0.0.0.0/0 (AWS API calls, external dependencies)

**RDS Security Group**:
- Ingress: Port 5432/3306 from App Server Security Group only
- No public ingress
- Stateful return traffic only

**EKS Node Security Group**:
- Ingress: Port 443 from EKS Control Plane Security Group
- Ingress: Port 22 from DevOps IP ranges only
- Ingress: Ports 10250-10259 from EKS Control Plane (kubelet, metrics)
- Egress: All traffic permitted (pods require NAT gateway access)

**Internal ALB Security Group**:
- Ingress: Port 80/443 from App Server Security Group and EKS Node Security Group
- Egress: Port 8080 to backend application security groups

**Validation Strategy**:
Create automated security group audit scripts that verify:
- No security groups allow 0.0.0.0/0 access to application ports
- All database security groups restrict access to application tier only
- Admin ports (22, 3389) restricted to DevOps IP ranges
- No overly permissive egress rules
- Security group chains properly implemented (ALB → App → Data)

---

## 2. VPC Connectivity

### 2.1 Establish Production ↔ Production-PCI Connectivity

**Requirement**: *"Servers and pods can reach internal applications securely between Production and Production PCI, servers and pods cannot intercommunicate directly"*

**Solution**: CDKTF VPC Peering Module (Available in Codebase)

The existing CDKTF VPC peering tool provides a complete solution for cross-VPC connectivity. This tool automates VPC peering connection creation, bi-directional route table management, and DNS resolution configuration.

**Architecture Approach**:

The peering architecture isolates direct server-to-server and pod-to-pod communication while enabling application-to-application connectivity through load balancers. This is achieved through:

**Route Table Segmentation**:
- Main route tables include peering routes for cross-VPC traffic
- Application subnet route tables allow traffic to peer VPC CIDR ranges
- Data subnet route tables explicitly exclude cross-VPC routes, maintaining data tier isolation
- Security groups enforce the principle that only application load balancers can initiate cross-VPC communication

**DNS Resolution**:
The peering configuration enables DNS resolution across VPCs, allowing applications to use internal DNS names rather than IP addresses. This supports dynamic infrastructure and simplifies application configuration.

**Implementation via CDKTF Tool**:
The tool is driven by a YAML configuration file specifying peers and peering relationships. It automatically:
- Creates VPC peering connections with proper accepter resources for cross-account scenarios
- Configures route tables in both VPCs for bi-directional connectivity
- Sets up DNS resolution options
- Handles cross-region peering with appropriate configurations
- Manages subnet-level routing for fine-grained control

**Deployment Process**:
1. Extract VPC IDs and CIDR blocks from Terraform outputs
2. Define peering relationships in peering.yaml configuration
3. Synthesize and apply CDKTF stack
4. Verify peering connections are active
5. Test connectivity between environments
6. Update application security groups to allow cross-VPC traffic patterns

**Security Considerations**:
- Security groups must be updated to permit traffic from peer VPC CIDR ranges
- Only specific application-to-application patterns should be allowed
- Direct server-to-server communication remains blocked through security group rules
- Data tier resources remain isolated with no cross-VPC routing
- All cross-VPC traffic flows through application load balancers for centralized control and logging

---

### 2.2 Implement Pod-to-Pod Encryption

**Requirement**: *"In the case of pods, traffic needs only be secure when leaving the cluster"*

**Implementation Approach**:

Pod-to-pod traffic within an EKS cluster uses the VPC CNI plugin and remains within the cluster's private network. However, when pod traffic exits the cluster (to other VPCs, external services, or the internet), encryption must be enforced.

**Encryption Strategies**:

**Application-Level TLS**: Applications configure TLS for all external communications. This approach provides end-to-end encryption and is the most portable solution. Applications use HTTPS for all API calls, TLS for database connections, and encrypted protocols for message queues.

**Service Mesh**: Implement AWS App Mesh or Istio to enforce mutual TLS (mTLS) for all service-to-service communication. The service mesh automatically encrypts traffic leaving the cluster while allowing unencrypted pod-to-pod traffic within the cluster mesh. This provides transparent encryption without application code changes.

**VPC CNI Security Groups for Pods**: Enable the VPC CNI security group feature to attach security groups directly to pods. Combined with encryption-enforcing security group rules, this ensures that pods can only communicate externally via encrypted channels.

**Network Policies**: Implement Kubernetes network policies that restrict pod egress to specific endpoints and require TLS validation. This provides policy-based enforcement at the network layer.

**Recommended Implementation**: Service mesh provides the best balance of security, observability, and operational simplicity. It handles certificate management, rotation, and mTLS enforcement automatically while providing traffic metrics and distributed tracing.

---

## 3. CI/CD Pipeline

### 3.1 Code Deployment Process

**Requirement**: *"Define a process for deploying code to servers and pods from Git repositories"*

**Implementation Architecture**:

The deployment process requires two parallel pipelines: one for containerized applications deployed to EKS, and another for traditional applications deployed to EC2 instances via Auto Scaling Groups.

**EKS Deployment Pipeline**:
Applications are containerized, pushed to Amazon ECR, and deployed to EKS clusters using kubectl or Helm. The pipeline includes:
- Source code checkout from Git repository
- Container image build with security scanning
- Image push to environment-specific ECR repositories
- Kubernetes manifest updates with new image tags
- Rolling deployment to EKS cluster
- Health check validation and rollback capability

**EC2 Deployment Pipeline**:
Traditional applications use AWS CodeDeploy with Auto Scaling Groups. The pipeline includes:
- Source code checkout and compilation
- Application artifact creation
- Artifact upload to S3
- CodeDeploy deployment to target Auto Scaling Group
- Health check validation through target group health
- Automatic rollback on deployment failure

**Deployment Triggers**:
- Development environment: Automatic deployment on merge to develop branch
- Staging environment: Automatic deployment on merge to main branch
- Production environment: Manual trigger after staging validation
- Production-PCI environment: Manual trigger with additional security approvals

**Security Integration**:
All deployment pipelines integrate security scanning:
- Container image vulnerability scanning with Trivy
- Infrastructure-as-code scanning with Checkov
- Dependency vulnerability scanning
- Compliance validation for PCI environments
- Security findings block production deployments

---

### 3.2 Production Approval Process

**Requirement**: *"Ensure that process requires approval for production deployments"*

**Approval Framework**:

Production deployments require explicit human approval to prevent unauthorized or untested changes from reaching customer-facing environments. The approval process varies based on environment criticality.

**Production Environment Approvals**:
- Minimum two approvals from DevOps team members
- Five-minute wait timer to allow for approval consideration
- Deployments restricted to main branch only
- Automated pre-deployment checks must pass
- Breaking change assessment required
- Rollback plan documented

**Production-PCI Environment Approvals**:
- Two approvals from DevOps team
- One additional approval from Security/Compliance team
- Extended ten-minute wait timer
- PCI compliance verification required
- Additional security scanning results reviewed
- Change management ticket required
- Deployment window restrictions enforced

**Approval Workflow**:
1. Developer triggers production deployment request
2. Automated pre-deployment checks execute (tests, security scans, migration dry-runs)
3. Deployment issue created with change summary and risk assessment
4. Required approvers notified via Slack/email
5. Approvers review changes, test results, and deployment plan
6. Minimum required approvals obtained
7. Wait timer expires
8. Deployment proceeds automatically
9. Post-deployment validation executes
10. Stakeholders notified of deployment completion

**Approval Notifications**:
Slack integration provides real-time notifications with deployment context, change diffs, test results, and direct links to approve. Approvers can review and approve directly from Slack or GitHub.

---

### 3.3 Application Promotion Process

**Requirement**: *"Provide a process for promoting applications from development, then to pre production, and then finally to the live, customer facing environment"*

**Promotion Strategy**:

Application promotion follows a progressive deployment model where applications advance through environments only after meeting quality gates at each stage.

**Development → Staging Promotion**:
Automatically triggered on merge to the develop branch. Basic smoke tests execute to ensure the application starts correctly and responds to health checks. No approval required as this is a testing environment.

**Staging → Production Promotion**:
Manually triggered after staging validation period. Comprehensive integration tests, load tests, and security scans must pass. Requires two DevOps approvals and a change management ticket. Staging serves as the final validation environment with architectural parity to production.

**Production → Production-PCI Promotion**:
Manually triggered after a minimum soak period in production (typically 24-48 hours). Requires all staging-to-production checks plus additional security scanning and PCI compliance verification. Three approvals required (two DevOps, one Security). Extended monitoring period before considering deployment successful.

**Promotion Validation**:
Each promotion stage includes:
- Automated test execution (unit, integration, load)
- Security vulnerability scanning
- Performance benchmarking against baseline
- Database migration validation
- Configuration verification
- Dependency availability checks
- Capacity verification in target environment

**Version Tracking**:
The promotion process maintains version continuity. The exact artifact (container image or deployment package) promoted from development flows through staging to production without rebuilding. This ensures what was tested in staging is exactly what runs in production. Image tags and artifact checksums provide traceability.

**Rollback Procedures**:
Each promotion includes documented rollback procedures. For EKS deployments, Kubernetes maintains previous ReplicaSets for instant rollback. For EC2 deployments, CodeDeploy maintains previous Auto Scaling Group configurations. Database migrations use reversible migration scripts.

---

## 4. Route Table Documentation

### 4.1 Complete Route Table Examples

**Requirement**: *"Provide example route tables from the subnets"*

**Route Table Architecture**:

The infrastructure implements a three-tier routing strategy separating public, private application, and private data traffic patterns.

---

**Production VPC (10.20.0.0/16)**

**Internet Gateway Route Table (Public Subnets)**
| Destination      | Target                    | Purpose                           |
|------------------|---------------------------|-----------------------------------|
| 10.20.0.0/16     | local                     | Intra-VPC routing                 |
| 10.21.0.0/16     | pcx-prod-to-prodpci       | Production-PCI VPC peering        |
| 0.0.0.0/0        | igw-0abc123               | Internet access                   |

Associated Subnets: 10.20.1.0/24, 10.20.2.0/24, 10.20.3.0/24 (Public Load Balancers)

---

**NAT Gateway Route Table (Private App Subnets)**
| Destination      | Target                    | Purpose                           |
|------------------|---------------------------|-----------------------------------|
| 10.20.0.0/16     | local                     | Intra-VPC routing                 |
| 10.21.0.0/16     | pcx-prod-to-prodpci       | Production-PCI VPC peering        |
| 0.0.0.0/0        | nat-0abc123               | Internet via NAT Gateway          |

Associated Subnets: 10.20.11.0/24, 10.20.12.0/24, 10.20.13.0/24 (App Servers, EKS Nodes)

---

**Data Tier Route Table (Private Data Subnets)**
| Destination      | Target                    | Purpose                           |
|------------------|---------------------------|-----------------------------------|
| 10.20.0.0/16     | local                     | Intra-VPC routing only            |
| 0.0.0.0/0        | nat-0abc123               | Internet via NAT Gateway          |

Associated Subnets: 10.20.21.0/24, 10.20.22.0/24, 10.20.23.0/24 (RDS, ElastiCache, MSK, OpenSearch)

**Note**: Data tier explicitly excludes peering routes to maintain PCI data isolation.

---

**Production-PCI VPC (10.21.0.0/16)**

Route table structure mirrors Production VPC with reciprocal peering routes (10.20.0.0/16 → pcx-prod-to-prodpci).

---

**Traffic Flow Patterns**:

**User → Production Application**:
```
Internet → IGW (10.20.1.0/24) → Public ALB → App Server (10.20.11.0/24) → RDS (10.20.21.0/24)
```

**Production App → Production-PCI Service**:
```
Production App (10.20.11.20) → VPC Peering → Production-PCI Internal ALB (10.21.11.10) → Production-PCI App (10.21.11.20)
```

**EKS Pod → External API**:
```
EKS Pod (10.20.11.50) → NAT Gateway → IGW → Internet
```

**Cross-VPC Database Access (Blocked)**:
```
Production App (10.20.11.20) ╳ Production-PCI RDS (10.21.21.30)
```
Reason: No peering route from app subnets to peer data subnets; data tier security groups only permit same-VPC traffic.

---

## 5. Blue/Green Deployments

### 5.1 EKS Blue/Green Strategy

**Requirement**: *"Bonus: Provide blue/green deployments"*

**Implementation Approach**:

Blue/green deployments for Kubernetes workloads use Argo Rollouts, providing automated traffic shifting, progressive delivery, and instant rollback capability.

**Core Blue/Green Configuration**:

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
      previewService: myapp-preview    # Preview/testing traffic
      autoPromotionEnabled: false      # Require manual promotion
      scaleDownDelaySeconds: 30        # Keep blue running briefly
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
1. New version (green) deployed alongside existing version (blue)
2. Green environment receives test traffic via preview service
3. Automated and manual validation performed on green environment
4. Manual promotion switches active service to green environment
5. Blue environment remains running during observation period
6. Blue environment scaled down after successful validation
7. Instant rollback available by switching active service back to blue

**Analysis and Validation**:
Argo Rollouts supports automated analysis during deployment using Prometheus metrics. Success criteria include HTTP success rates, response times, error rates, and custom business metrics. Failed analysis automatically aborts the deployment and maintains blue environment.

---

### 5.2 EC2 Blue/Green Strategy

**Implementation Approach**:

Blue/green deployments for EC2 Auto Scaling Groups use AWS CodeDeploy, which creates a new Auto Scaling Group (green), validates it, shifts traffic progressively, and terminates the old group (blue) after success.

**Configuration Elements**:

CodeDeploy blue/green configuration specifies:
- **Green Fleet Provisioning**: Copy existing Auto Scaling Group configuration to create green environment
- **Traffic Shifting**: Progressive traffic shift (10% every 10 minutes) from blue to green target group
- **Deployment Readiness**: Wait for manual approval or timeout before traffic shifting begins
- **Instance Termination**: Terminate blue instances 30 minutes after successful deployment
- **Automatic Rollback**: Trigger rollback on CloudWatch alarm thresholds

**Deployment Process**:

The deployment begins by creating a new Auto Scaling Group with updated application code while the existing group continues serving traffic. CodeDeploy registers the new instances with a green target group and waits for health checks to pass. 

After validation, traffic shifts progressively from blue to green target group according to the configured timeline. CloudWatch alarms monitor error rates, latency, and other metrics during the shift. If metrics exceed thresholds, CodeDeploy automatically rolls back by shifting traffic back to blue.

After successful traffic migration, the blue Auto Scaling Group remains running for a grace period allowing rapid rollback if issues emerge. The grace period expires, blue instances terminate, and the deployment completes.

**Load Balancer Configuration**:

The Application Load Balancer maintains two target groups (blue and green). Listener rules route production traffic to the active target group. During deployment, CodeDeploy modifies listener rules to shift traffic from blue to green target group. This approach provides instant cutover with the ability to shift back instantly if needed.

**Monitoring and Rollback**:

CloudWatch alarms monitor application metrics throughout the deployment. Alarm thresholds define acceptable error rates and performance characteristics. When alarms trigger, CodeDeploy automatically reverts listener rules to route traffic back to the blue target group, achieving near-instant rollback without instance replacement.

---

## Summary

### Requirements Compliance Status

| Requirement | Implementation Status |
|-------------|----------------------|
| Network CIDR | ✅ Complete |
| Multi-AZ subnets | ✅ Complete |
| Server/pod app resource access | ✅ Architecture supports, requires security group verification |
| Cross-VPC secure communication | ⚠️ CDKTF tool available, requires deployment |
| Pod traffic encryption | ❌ Requires service mesh or network policy implementation |
| Network security rules | ⚠️ Implemented in module, requires verification |
| DevOps admin port access | ⚠️ Variable exists, requires IP restriction |
| Load balancer app port access | ⚠️ Implemented in module, requires verification |
| DevOps EKS admin access | ❌ Requires RBAC implementation |
| Dev EKS read-only access | ❌ Requires RBAC implementation |
| Secure configuration storage | ✅ Complete (Parameter Store + KMS) |
| Production-PCI requirements | ⚠️ Same status as Production VPC |
| Git deployment process | ❌ Requires CI/CD pipeline implementation |
| Production approval process | ❌ Requires approval gate implementation |
| Application promotion process | ❌ Requires promotion workflow implementation |
| Route table examples | ✅ Documented in this guide |
| Blue/green deployments | ❌ Requires Argo Rollouts (EKS) and CodeDeploy configuration (EC2) |
| Infrastructure automation | ✅ Complete (Terraform + CDKTF peering tool) |

### Implementation Priorities

**Critical (Security & Access)**:
- Restrict DevOps IP ranges from 0.0.0.0/0 to specific CIDR blocks
- Implement EKS RBAC with DevOps admin and Dev read-only roles
- Verify and document security group rules
- Deploy VPC peering using existing CDKTF tool

**High (Operational)**:
- Build CI/CD pipeline for application deployments
- Implement production approval gates
- Create application promotion workflow
- Configure monitoring and alerting

**Medium (Enhancement)**:
- Implement pod traffic encryption (service mesh)
- Deploy blue/green deployment capability
- Create operational runbooks
- Train teams on processes

**Low (Optional)**:
- Multi-region disaster recovery
- Advanced cost optimization
- Additional compliance automation

### Success Criteria

- All security requirements satisfied with proper access controls
- Cross-VPC connectivity established with verified routing
- Automated deployment pipeline with approval gates
- Zero-downtime deployments via blue/green strategy
- Complete documentation and team training
- Regular security audits showing no critical findings

### 1.1 Restrict DevOps Access to Admin Ports

**Requirement**: *"Ensure only DevOps can reach pods and servers on admin ports (22, 3389, etc...)"*

**Current Gap**: `devops_ip_ranges = ["0.0.0.0/0"]` allows all traffic

**Implementation**:

```hcl
# environments/production/terraform.tfvars
devops_ip_ranges = [
  "203.0.113.0/24",    # Office Network
  "198.51.100.0/24",   # VPN Network
  "192.0.2.0/24"       # Secondary Office
]

# environments/production-pci/terraform.tfvars
devops_ip_ranges = [
  "203.0.113.0/24",    # Office Network - More restricted for PCI
]
```

**Tasks**:
- [ ] Gather actual office and VPN CIDR blocks from network team
- [ ] Update all environment `terraform.tfvars` files
- [ ] Apply changes to dev environment first
- [ ] Test SSH/RDP access from approved and non-approved IPs
- [ ] Apply to staging and production

**Validation**:
```bash
# Test from approved IP (should succeed)
ssh ec2-user@<instance-ip>

# Test from non-approved IP (should fail)
# Connection should timeout or be refused
```

---

### 1.2 Implement EKS RBAC

**Requirement**: 
- *"Ensure only DevOps has EKS cluster admin access"*
- *"Ensure Dev has EKS cluster read only access"*

**Current Gap**: No RBAC configuration exists

**Implementation**:

**Step 1**: Create IAM Roles
```hcl
# modules/environment/eks-rbac.tf
resource "aws_iam_role" "eks_devops_admin" {
  name = "${var.environment}-eks-devops-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        AWS = var.devops_role_arns
      }
    }]
  })
}

resource "aws_iam_role" "eks_dev_readonly" {
  name = "${var.environment}-eks-dev-readonly"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        AWS = var.dev_role_arns
      }
    }]
  })
}
```

**Step 2**: Configure aws-auth ConfigMap
```hcl
# modules/environment/eks-rbac.tf
resource "kubernetes_config_map_v1_data" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      # EKS Node Role (existing)
      {
        rolearn  = aws_iam_role.eks_node_role.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      },
      # DevOps Admin Role
      {
        rolearn  = aws_iam_role.eks_devops_admin.arn
        username = "devops-admin:{{SessionName}}"
        groups   = ["system:masters"]
      },
      # Dev Read-Only Role
      {
        rolearn  = aws_iam_role.eks_dev_readonly.arn
        username = "dev:{{SessionName}}"
        groups   = ["view-only"]
      }
    ])
  }

  force = true

  depends_on = [
    aws_eks_cluster.main
  ]
}
```

**Step 3**: Create ClusterRole for read-only access
```hcl
resource "kubernetes_cluster_role" "view_only" {
  metadata {
    name = "view-only"
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_cluster_role_binding" "view_only" {
  metadata {
    name = "view-only-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view-only"
  }

  subject {
    kind      = "Group"
    name      = "view-only"
    api_group = "rbac.authorization.k8s.io"
  }
}
```

**Tasks**:
- [ ] Create `modules/environment/eks-rbac.tf`
- [ ] Add required IAM role ARN variables to environment configs
- [ ] Deploy to dev environment
- [ ] Test DevOps admin access: `aws eks update-kubeconfig` and verify kubectl access
- [ ] Test Dev read-only access: verify can view but not modify resources
- [ ] Deploy to staging and production

**Validation**:
```bash
# As DevOps (should succeed)
aws sts assume-role --role-arn arn:aws:iam::ACCOUNT:role/dev-eks-devops-admin --role-session-name test
aws eks update-kubeconfig --name dev-eks-cluster --role-arn arn:aws:iam::ACCOUNT:role/dev-eks-devops-admin
kubectl delete pod test-pod  # Should succeed

# As Dev (should fail for write operations)
aws sts assume-role --role-arn arn:aws:iam::ACCOUNT:role/dev-eks-dev-readonly --role-session-name test
aws eks update-kubeconfig --name dev-eks-cluster --role-arn arn:aws:iam::ACCOUNT:role/dev-eks-dev-readonly
kubectl get pods              # Should succeed
kubectl delete pod test-pod   # Should fail with forbidden error
```

---

### 1.3 Verify Security Group Rules

**Requirement**: 
- *"Ensure only load balancers can reach applications on internal app ports (8080, 80, etc...)"*
- *"Provide network security rules and configuration"*

**Current Gap**: Rules exist in module but need verification

**Implementation**:

Create security group validation script:
```bash
#!/bin/bash
# scripts/verify-security-groups.sh

ENVIRONMENT=$1
VPC_ID=$(terraform output -raw vpc_id)

echo "Verifying security groups for environment: $ENVIRONMENT"

# Check ALB Security Group
echo "==> ALB Security Group"
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*alb*" \
  --query 'SecurityGroups[*].[GroupId,GroupName,IpPermissions[*].[FromPort,ToPort,IpRanges[*].CidrIp]]'

# Check App Server Security Group
echo "==> App Server Security Group"
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*app*" \
  --query 'SecurityGroups[*].[GroupId,GroupName,IpPermissions[*].[FromPort,ToPort,UserIdGroupPairs[*].GroupId]]'

# Verify:
# 1. ALB SG allows 80/443 from 0.0.0.0/0
# 2. App Server SG allows 8080 ONLY from ALB SG (not from 0.0.0.0/0)
# 3. App Server SG allows 22 ONLY from DevOps IPs
```

**Expected Security Group Configuration**:

```
Public ALB Security Group:
  Ingress:
    - Port 80   from 0.0.0.0/0
    - Port 443  from 0.0.0.0/0
  Egress:
    - Port 8080 to App Server SG

App Server Security Group:
  Ingress:
    - Port 8080 from ALB SG only
    - Port 22   from DevOps IP ranges only
  Egress:
    - Port 5432 to RDS SG
    - Port 6379 to ElastiCache SG
    - Port 443  to 0.0.0.0/0 (for AWS API calls)

RDS Security Group:
  Ingress:
    - Port 5432 from App Server SG only
  Egress:
    - None (stateful)

EKS Node Security Group:
  Ingress:
    - Port 443  from EKS Control Plane SG
    - Port 22   from DevOps IP ranges only
    - Port 10250-10259 from EKS Control Plane SG (kubelet)
  Egress:
    - All traffic (pods need internet access via NAT)
```

**Tasks**:
- [ ] Review `modules/environment/security-groups.tf` (if exists)
- [ ] Create security group verification script
- [ ] Run verification in dev environment
- [ ] Document any security group issues found
- [ ] Fix security group rules if needed
- [ ] Re-run verification

---

## Phase 2: VPC Connectivity (Week 3)

### 2.1 Establish Production ↔ Production-PCI Connectivity

**Requirement**: *"Servers and pods can reach internal applications securely between Production and Production PCI, servers and pods cannot intercommunicate directly"*

**Solution Available**: CDKTF VPC Peering Module

**Implementation**:

**Option A: Use CDKTF VPC Peering Tool (Recommended)**

```yaml
# peering.yaml
peers:
  production:
    vpc_id: vpc-0prod123456789abc    # From terraform output in environments/production
    region: us-east-1
    role_arn: "arn:aws:iam::111111111111:role/TerraformRole"
    dns_resolution: true
    has_additional_routes: true
  
  production-pci:
    vpc_id: vpc-0prodpci123456789    # From terraform output in environments/production-pci
    region: us-east-1
    role_arn: "arn:aws:iam::222222222222:role/TerraformRole"
    dns_resolution: true
    has_additional_routes: true
  
  staging:
    vpc_id: vpc-0stage123456789ab
    region: us-east-1
    role_arn: "arn:aws:iam::111111111111:role/TerraformRole"
    dns_resolution: true
    has_additional_routes: true
  
  staging-pci:
    vpc_id: vpc-0stagepci12345678
    region: us-east-1
    role_arn: "arn:aws:iam::222222222222:role/TerraformRole"
    dns_resolution: true
    has_additional_routes: true

peering_matrix:
  production:
    - production-pci
  staging:
    - staging-pci
```

**Deployment Steps**:
```bash
# 1. Get VPC IDs from Terraform
cd environments/production && terraform output vpc_id
cd environments/production-pci && terraform output vpc_id

# 2. Create peering.yaml with actual VPC IDs

# 3. Deploy peering
cd <cdktf-peering-root>
make get
make synth
make plan
make deploy

# 4. Verify peering
aws ec2 describe-vpc-peering-connections --filters "Name=status-code,Values=active"
```

**Option B: Native Terraform Module**

If not using CDKTF tool, create module:
```hcl
# modules/vpc-peering/main.tf
resource "aws_vpc_peering_connection" "this" {
  vpc_id        = var.requester_vpc_id
  peer_vpc_id   = var.accepter_vpc_id
  peer_owner_id = var.accepter_account_id
  peer_region   = var.accepter_region
  
  tags = {
    Name = "${var.requester_name}-to-${var.accepter_name}"
  }
}

resource "aws_vpc_peering_connection_accepter" "this" {
  provider                  = aws.accepter
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
  auto_accept               = true
}

resource "aws_vpc_peering_connection_options" "requester" {
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
  
  requester {
    allow_remote_vpc_dns_resolution = var.enable_dns_resolution
  }
}

resource "aws_route" "requester_routes" {
  count                     = length(var.requester_route_table_ids)
  route_table_id            = var.requester_route_table_ids[count.index]
  destination_cidr_block    = var.accepter_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

resource "aws_route" "accepter_routes" {
  provider                  = aws.accepter
  count                     = length(var.accepter_route_table_ids)
  route_table_id            = var.accepter_route_table_ids[count.index]
  destination_cidr_block    = var.requester_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}
```

**Tasks**:
- [ ] Choose Option A (CDKTF) or Option B (Terraform module)
- [ ] Gather VPC IDs and route table IDs from all environments
- [ ] Configure peering (YAML or Terraform)
- [ ] Deploy to staging environments first
- [ ] Test connectivity: ping/curl from staging to staging-pci
- [ ] Update security groups to allow cross-VPC traffic
- [ ] Deploy to production environments
- [ ] Document peering topology

**Validation**:
```bash
# From Production EC2 instance
ping 10.21.11.10  # Production-PCI private IP (should succeed)
curl http://internal-prod-pci-alb.amazonaws.com  # Should succeed

# From Production-PCI EC2 instance
ping 10.20.11.10  # Production private IP (should succeed)
curl http://internal-prod-alb.amazonaws.com  # Should succeed
```

---

### 2.2 Implement Pod-to-Pod Encryption

**Requirement**: *"In the case of pods, traffic needs only be secure when leaving the cluster"*

**Implementation**: Configure EKS with encryption in transit for pod traffic leaving cluster

**Option A: AWS VPC CNI with Security Groups for Pods**
```hcl
# modules/environment/eks-security-groups-for-pods.tf
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
  
  configuration_values = jsonencode({
    enableNetworkPolicy = true
    env = {
      ENABLE_POD_ENI                    = "true"
      POD_SECURITY_GROUP_ENFORCING_MODE = "standard"
    }
  })
}

# Security group for pods that need external access
resource "aws_security_group" "eks_pods_external" {
  name_prefix = "${var.environment}-eks-pods-external"
  vpc_id      = aws_vpc.main.id
  
  egress {
    description = "Allow HTTPS to Production-PCI"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.production_pci_vpc_cidr]
  }
  
  egress {
    description = "Allow HTTPS to internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**Option B: Service Mesh (Istio/AWS App Mesh)**
```hcl
# modules/environment/service-mesh.tf
resource "aws_appmesh_mesh" "main" {
  name = "${var.environment}-mesh"
  
  spec {
    egress_filter {
      type = "ALLOW_ALL"
    }
    service_discovery {
      ip_preference = "IPv4_ONLY"
    }
  }
}

# Configure mTLS for all service-to-service communication
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

**Tasks**:
- [ ] Choose service mesh solution (App Mesh recommended for AWS)
- [ ] Deploy service mesh to dev EKS cluster
- [ ] Configure mTLS policies for external traffic
- [ ] Deploy test application and verify encryption
- [ ] Roll out to staging and production

---

## Phase 3: CI/CD Pipeline (Week 4-5)

### 3.1 Define Code Deployment Process

**Requirement**: *"Define a process for deploying code to servers and pods from Git repositories"*

**Implementation**: GitHub Actions CI/CD Pipeline

**Directory Structure**:
```
.github/
└── workflows/
    ├── infrastructure.yml     # Terraform deployments
    ├── app-deploy-dev.yml     # Auto-deploy to dev
    ├── app-deploy-staging.yml # Auto-deploy to staging
    └── app-deploy-prod.yml    # Manual approval for production
```

**3.1.1 Application Deployment Pipeline**

```yaml
# .github/workflows/app-deploy-prod.yml
name: Deploy to Production

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options:
          - production
          - production-pci

permissions:
  contents: read
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GithubActionsRole
          aws-region: us-east-1
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2
      
      - name: Build and push Docker image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/myapp:$IMAGE_TAG .
          docker push $ECR_REGISTRY/myapp:$IMAGE_TAG
    
    outputs:
      image-tag: ${{ github.sha }}
  
  security-scan:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ needs.build.outputs.ecr-registry }}/myapp:${{ needs.build.outputs.image-tag }}
          format: 'sarif'
          output: 'trivy-results.sarif'
      
      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'
  
  deploy-ec2:
    needs: [build, security-scan]
    runs-on: ubuntu-latest
    environment: 
      name: ${{ github.event.inputs.environment }}
      url: https://${{ steps.deploy.outputs.alb-dns }}
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GithubActionsRole
          aws-region: us-east-1
      
      - name: Create CodeDeploy deployment
        run: |
          aws deploy create-deployment \
            --application-name myapp-${{ github.event.inputs.environment }} \
            --deployment-group-name myapp-dg \
            --s3-location bucket=myapp-deployments,key=myapp-${{ needs.build.outputs.image-tag }}.zip,bundleType=zip
  
  deploy-eks:
    needs: [build, security-scan]
    runs-on: ubuntu-latest
    environment: 
      name: ${{ github.event.inputs.environment }}
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GithubActionsRole
          aws-region: us-east-1
      
      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig --name ${{ github.event.inputs.environment }}-eks-cluster
      
      - name: Deploy to Kubernetes
        env:
          IMAGE_TAG: ${{ needs.build.outputs.image-tag }}
        run: |
          kubectl set image deployment/myapp myapp=${{ steps.login-ecr.outputs.registry }}/myapp:$IMAGE_TAG
          kubectl rollout status deployment/myapp
```

**3.1.2 For EC2 Deployments: CodeDeploy Configuration**

```yaml
# appspec.yml (in application repository)
version: 0.0
os: linux
files:
  - source: /
    destination: /opt/myapp
hooks:
  ApplicationStop:
    - location: scripts/stop_application.sh
      timeout: 300
  BeforeInstall:
    - location: scripts/install_dependencies.sh
      timeout: 300
  ApplicationStart:
    - location: scripts/start_application.sh
      timeout: 300
  ValidateService:
    - location: scripts/validate_service.sh
      timeout: 300
```

```hcl
# modules/environment/codedeploy.tf
resource "aws_codedeploy_app" "main" {
  name = "${var.environment}-myapp"
}

resource "aws_codedeploy_deployment_group" "main" {
  app_name              = aws_codedeploy_app.main.name
  deployment_group_name = "myapp-dg"
  service_role_arn      = aws_iam_role.codedeploy.arn
  
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
  
  ec2_tag_set {
    ec2_tag_filter {
      key   = "Environment"
      type  = "KEY_AND_VALUE"
      value = var.environment
    }
    
    ec2_tag_filter {
      key   = "Application"
      type  = "KEY_AND_VALUE"
      value = "myapp"
    }
  }
  
  load_balancer_info {
    target_group_info {
      name = aws_lb_target_group.main.name
    }
  }
}
```

**Tasks**:
- [ ] Create GitHub Actions workflows for all environments
- [ ] Configure AWS IAM roles for GitHub Actions (OIDC)
- [ ] Set up ECR repositories for container images
- [ ] Configure CodeDeploy for EC2 deployments
- [ ] Test deployment to dev environment
- [ ] Document deployment process

---

### 3.2 Implement Production Approval Process

**Requirement**: *"Ensure that process requires approval for production deployments"*

**Implementation**:

**3.2.1 GitHub Environments with Required Reviewers**

```yaml
# In repository settings, configure environments:
# Settings → Environments → New environment

# production environment:
#   - Required reviewers: 2 approvers from @devops-team
#   - Wait timer: 5 minutes
#   - Deployment branches: main only

# production-pci environment:
#   - Required reviewers: 2 approvers from @devops-team + 1 from @security-team
#   - Wait timer: 10 minutes
#   - Deployment branches: main only
```

**3.2.2 Approval Workflow**

```yaml
# .github/workflows/app-deploy-prod.yml (enhancement)
jobs:
  pre-deployment-checks:
    runs-on: ubuntu-latest
    steps:
      - name: Check for breaking changes
        run: |
          # Run database migration dry-run
          # Check API compatibility
          # Verify infrastructure capacity
          
      - name: Create deployment issue
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: 'Production Deployment: ${{ github.sha }}',
              body: '## Deployment Request\n\n' +
                    '**Commit**: ${{ github.sha }}\n' +
                    '**Requested by**: ${{ github.actor }}\n' +
                    '**Changes**: [View diff](https://github.com/${{ github.repository }}/compare/${{ github.event.before }}...${{ github.sha }})\n\n' +
                    '**Pre-deployment checklist**:\n' +
                    '- [ ] Database migrations reviewed\n' +
                    '- [ ] Breaking changes assessed\n' +
                    '- [ ] Rollback plan documented\n' +
                    '- [ ] Stakeholders notified\n\n' +
                    '/cc @devops-team',
              labels: ['deployment', 'production']
            })
  
  approval-gate:
    needs: pre-deployment-checks
    runs-on: ubuntu-latest
    environment: 
      name: production
    steps:
      - name: Approval received
        run: echo "Deployment approved by required reviewers"
  
  deploy:
    needs: approval-gate
    # ... deployment steps
```

**3.2.3 Slack Integration for Approvals**

```yaml
# Add to workflow
- name: Request approval in Slack
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "🚀 Production deployment approval needed",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*Production Deployment Request*\n\n" +
                      "Commit: `${{ github.sha }}`\n" +
                      "Requested by: ${{ github.actor }}\n\n" +
                      "<https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}|View workflow>"
            }
          },
          {
            "type": "actions",
            "elements": [
              {
                "type": "button",
                "text": { "type": "plain_text", "text": "Approve" },
                "style": "primary",
                "url": "https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}"
              }
            ]
          }
        ]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

**Tasks**:
- [ ] Configure GitHub environments with protection rules
- [ ] Set up required reviewers (2+ for production, 3+ for production-pci)
- [ ] Integrate Slack notifications
- [ ] Document approval process
- [ ] Test approval flow in staging
- [ ] Train team on approval process

---

### 3.3 Application Promotion Process

**Requirement**: *"Provide a process for promoting applications from development, then to pre production, and then finally to the live, customer facing environment"*

**Implementation**: Promotion Pipeline with Progressive Deployment

```yaml
# .github/workflows/promote.yml
name: Application Promotion

on:
  workflow_dispatch:
    inputs:
      from_environment:
        description: 'Source environment'
        required: true
        type: choice
        options:
          - dev
          - staging
      to_environment:
        description: 'Target environment'
        required: true
        type: choice
        options:
          - staging
          - production
          - production-pci

jobs:
  validate-promotion:
    runs-on: ubuntu-latest
    steps:
      - name: Validate promotion path
        run: |
          # dev → staging: always allowed
          # staging → production: allowed if staging tests pass
          # production → production-pci: allowed with security approval
          
          if [[ "${{ github.event.inputs.from_environment }}" == "dev" ]] && \
             [[ "${{ github.event.inputs.to_environment }}" != "staging" ]]; then
            echo "ERROR: Can only promote from dev to staging"
            exit 1
          fi
          
          if [[ "${{ github.event.inputs.from_environment }}" == "staging" ]] && \
             [[ "${{ github.event.inputs.to_environment }}" == "production-pci" ]]; then
            echo "ERROR: Must promote to production before production-pci"
            exit 1
          fi
  
  get-current-version:
    needs: validate-promotion
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.get-tag.outputs.tag }}
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GithubActionsRole
          aws-region: us-east-1
      
      - name: Get current image tag from source environment
        id: get-tag
        run: |
          # For EKS
          aws eks update-kubeconfig --name ${{ github.event.inputs.from_environment }}-eks-cluster
          TAG=$(kubectl get deployment myapp -o jsonpath='{.spec.template.spec.containers[0].image}' | cut -d':' -f2)
          echo "tag=$TAG" >> $GITHUB_OUTPUT
          
          # For EC2
          # TAG=$(aws deploy get-deployment --deployment-id $(aws deploy list-deployments --application-name myapp-${{ github.event.inputs.from_environment }} --max-items 1 --query 'deployments[0]' --output text) --query 'deploymentInfo.revision.s3Location.key' --output text | cut -d'-' -f2 | cut -d'.' -f1)
  
  run-tests:
    needs: get-current-version
    runs-on: ubuntu-latest
    steps:
      - name: Run integration tests
        run: |
          # Run comprehensive test suite against source environment
          echo "Running tests against ${{ github.event.inputs.from_environment }}"
          
      - name: Run security scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ secrets.ECR_REGISTRY }}/myapp:${{ needs.get-current-version.outputs.image-tag }}
      
      - name: Run load tests
        if: github.event.inputs.to_environment == 'production'
        run: |
          # Run load tests in staging
          k6 run loadtest.js
  
  create-release-notes:
    needs: [get-current-version, run-tests]
    runs-on: ubuntu-latest
    steps:
      - name: Generate release notes
        run: |
          # Create GitHub release with notes
          gh release create v${{ needs.get-current-version.outputs.image-tag }} \
            --title "Release ${{ needs.get-current-version.outputs.image-tag }}" \
            --notes "Promoting from ${{ github.event.inputs.from_environment }} to ${{ github.event.inputs.to_environment }}"
  
  promote:
    needs: [get-current-version, run-tests, create-release-notes]
    uses: ./.github/workflows/app-deploy-prod.yml
    with:
      environment: ${{ github.event.inputs.to_environment }}
      image-tag: ${{ needs.get-current-version.outputs.image-tag }}
    secrets: inherit
```

**Promotion Matrix**:

```
dev → staging:
  ✓ Automatic on merge to develop branch
  ✓ Basic smoke tests
  ✓ No approval required

staging → production:
  ✓ Manual trigger only
  ✓ Comprehensive integration tests
  ✓ Load testing
  ✓ 2+ DevOps approvals required
  ✓ Change management ticket required

production → production-pci:
  ✓ Manual trigger only
  ✓ All staging → production checks
  ✓ Additional security scan
  ✓ 2+ DevOps + 1+ Security approvals required
  ✓ PCI compliance verification
  ✓ Extended soak period (24h minimum in production)
```

**Tasks**:
- [ ] Create promotion workflow
- [ ] Define test requirements for each promotion
- [ ] Set up automated testing (integration, load, security)
- [ ] Document promotion process
- [ ] Create promotion runbook
- [ ] Train team on promotion workflow

---

## Phase 4: Documentation & Examples (Week 6)

### 4.1 Provide Route Table Examples

**Requirement**: *"Provide example route tables from the subnets"*

**Implementation**: Document complete routing topology

```markdown
# Route Tables Documentation

## Production VPC (10.20.0.0/16)

### Internet Gateway Route Table (for Public Subnets)
| Destination      | Target                    | Purpose                           |
|------------------|---------------------------|-----------------------------------|
| 10.20.0.0/16     | local                     | Intra-VPC routing                 |
| 10.21.0.0/16     | pcx-prod-to-prodpci       | To Production-PCI VPC             |
| 0.0.0.0/0        | igw-0abc123               | Internet access                   |

**Associated Subnets**:
- 10.20.1.0/24 (us-east-1a)
- 10.20.2.0/24 (us-east-1b)
- 10.20.3.0/24 (us-east-1c)

---

### NAT Gateway Route Table (for Private App Subnets)
| Destination      | Target                    | Purpose                           |
|------------------|---------------------------|-----------------------------------|
| 10.20.0.0/16     | local                     | Intra-VPC routing                 |
| 10.21.0.0/16     | pcx-prod-to-prodpci       | To Production-PCI VPC             |
| 0.0.0.0/0        | nat-0abc123               | Internet via NAT Gateway          |

**Associated Subnets**:
- 10.20.11.0/24 (us-east-1a) - App servers, EKS nodes
- 10.20.12.0/24 (us-east-1b)
- 10.20.13.0/24 (us-east-1c)

---

### Data Tier Route Table (for Private Data Subnets)
| Destination      | Target                    | Purpose                           |
|------------------|---------------------------|-----------------------------------|
| 10.20.0.0/16     | local                     | Intra-VPC routing                 |
| 0.0.0.0/0        | nat-0abc123               | Internet via NAT Gateway          |

**Note**: No cross-VPC routes for data tier to maintain PCI isolation

**Associated Subnets**:
- 10.20.21.0/24 (us-east-1a) - RDS, ElastiCache, MSK, OpenSearch
- 10.20.22.0/24 (us-east-1b)
- 10.20.23.0/24 (us-east-1c)

---

## Production-PCI VPC (10.21.0.0/16)

### Internet Gateway Route Table (for Public Subnets)
| Destination      | Target                    | Purpose                           |
|------------------|---------------------------|-----------------------------------|
| 10.21.0.0/16     | local                     | Intra-VPC routing                 |
| 10.20.0.0/16     | pcx-prod-to-prodpci       | To Production VPC                 |
| 0.0.0.0/0        | igw-0def456               | Internet access                   |

**Associated Subnets**:
- 10.21.1.0/24 (us-east-1a)
- 10.21.2.0/24 (us-east-1b)
- 10.21.3.0/24 (us-east-1c)

---

### NAT Gateway Route Table (for Private App Subnets)
| Destination      | Target                    | Purpose                           |
|------------------|---------------------------|-----------------------------------|
| 10.21.0.0/16     | local                     | Intra-VPC routing                 |
| 10.20.0.0/16     | pcx-prod-to-prodpci       | To Production VPC                 |
| 0.0.0.0/0        | nat-0def456               | Internet via NAT Gateway          |

**Associated Subnets**:
- 10.21.11.0/24 (us-east-1a) - App servers, EKS nodes
- 10.21.12.0/24 (us-east-1b)
- 10.21.13.0/24 (us-east-1c)

---

## Traffic Flow Examples

### Example 1: User → Production Application
```
User (Internet)
  ↓ HTTPS (443)
Internet Gateway (igw-0abc123)
  ↓
Public ALB (10.20.1.10)
  ↓ HTTP (8080)
App Server (10.20.11.20) [Private App Subnet]
  ↓ TCP (5432)
RDS (10.20.21.30) [Private Data Subnet]
```

### Example 2: Production App → Production-PCI Service
```
Production App (10.20.11.20)
  ↓ HTTPS (443)
VPC Peering (pcx-prod-to-prodpci)
  ↓
Production-PCI Internal ALB (10.21.11.10)
  ↓ HTTP (8080)
Production-PCI App Server (10.21.11.20)
```

### Example 3: EKS Pod → External API
```
EKS Pod (10.20.11.50)
  ↓
NAT Gateway (nat-0abc123)
  ↓
Internet Gateway (igw-0abc123)
  ↓
External API (Internet)
```

### Example 4: Cross-VPC Database Access (BLOCKED)
```
Production App (10.20.11.20)
  ↓ TCP (5432) ❌ BLOCKED
Production-PCI RDS (10.21.21.30)

Reason: No route from app subnets to peer data subnets
        Data tier security groups only allow same-VPC traffic
```
```

**Tasks**:
- [ ] Generate route table diagrams
- [ ] Document all traffic flows
- [ ] Create route table verification script
- [ ] Add to repository documentation

---

## Phase 5: Blue/Green Deployments (Bonus - Week 7-8)

### 5.1 EKS Blue/Green with Argo Rollouts

**Requirement**: *"Bonus: Provide blue/green deployments"*

**Implementation for Kubernetes**:

```yaml
# k8s/rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
  namespace: production
spec:
  replicas: 5
  strategy:
    blueGreen:
      activeService: myapp-active
      previewService: myapp-preview
      autoPromotionEnabled: false
      scaleDownDelaySeconds: 30
      prePromotionAnalysis:
        templates:
          - templateName: smoke-tests
      postPromotionAnalysis:
        templates:
          - templateName: load-tests
  
  revisionHistoryLimit: 3
  
  selector:
    matchLabels:
      app: myapp
  
  template:
    metadata:
      labels:
        app: myapp
        version: v2
    spec:
      containers:
        - name: myapp
          image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:latest
          ports:
            - containerPort: 8080
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"

---
apiVersion: v1
kind: Service
metadata:
  name: myapp-active
  namespace: production
spec:
  selector:
    app: myapp
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080

---
apiVersion: v1
kind: Service
metadata:
  name: myapp-preview
  namespace: production
spec:
  selector:
    app: myapp
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080

---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: smoke-tests
  namespace: production
spec:
  metrics:
    - name: http-success-rate
      interval: 30s
      successCondition: result >= 0.95
      provider:
        prometheus:
          address: http://prometheus.monitoring:9090
          query: |
            sum(rate(http_requests_total{status=~"2.."}[5m])) /
            sum(rate(http_requests_total[5m]))

---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: load-tests
  namespace: production
spec:
  metrics:
    - name: response-time-p95
      interval: 1m
      successCondition: result <= 500
      failureLimit: 3
      provider:
        prometheus:
          address: http://prometheus.monitoring:9090
          query: |
            histogram_quantile(0.95,
              rate(http_request_duration_seconds_bucket[5m])
            ) * 1000
```

**Deployment Process**:
```bash
# 1. Deploy new version (green)
kubectl argo rollouts set image myapp myapp=myapp:v2

# 2. Monitor rollout
kubectl argo rollouts status myapp

# 3. Preview traffic (test green environment)
kubectl argo rollouts promote myapp --preview

# 4. Run smoke tests
curl http://myapp-preview.production.svc.cluster.local/health

# 5. Promote to active (switch traffic to green)
kubectl argo rollouts promote myapp

# 6. Monitor metrics during promotion
kubectl argo rollouts dashboard

# 7. Rollback if needed
kubectl argo rollouts undo myapp
```

---

### 5.2 EC2 Blue/Green with CodeDeploy

**Implementation for EC2**:

```hcl
# modules/environment/codedeploy-bluegreen.tf
resource "aws_codedeploy_deployment_config" "blue_green" {
  deployment_config_name = "${var.environment}-BlueGreenConfig"
  
  traffic_routing_config {
    type = "TimeBasedLinear"
    
    time_based_linear {
      interval   = 10  # Minutes between traffic shifts
      percentage = 10  # Percentage to shift each interval
    }
  }
}

resource "aws_codedeploy_deployment_group" "blue_green" {
  app_name               = aws_codedeploy_app.main.name
  deployment_group_name  = "myapp-blue-green-dg"
  service_role_arn       = aws_iam_role.codedeploy.arn
  deployment_config_name = aws_codedeploy_deployment_config.blue_green.id
  
  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 30
    }
    
    deployment_ready_option {
      action_on_timeout = "STOP_DEPLOYMENT"
      wait_time_in_minutes = 15  # Wait for manual approval
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
  
  alarm_configuration {
    alarms  = [aws_cloudwatch_metric_alarm.error_rate.name]
    enabled = true
  }
}

# Blue Target Group
resource "aws_lb_target_group" "blue" {
  name     = "${var.environment}-myapp-blue"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  health_check {
    enabled             = true
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }
}

# Green Target Group
resource "aws_lb_target_group" "green" {
  name     = "${var.environment}-myapp-green"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  health_check {
    enabled             = true
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }
}

# CloudWatch Alarm for automatic rollback
resource "aws_cloudwatch_metric_alarm" "error_rate" {
  alarm_name          = "${var.environment}-myapp-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Triggers rollback if error rate is too high"
  
  dimensions = {
    LoadBalancer = aws_lb.public.arn_suffix
    TargetGroup  = aws_lb_target_group.green.arn_suffix
  }
}
```

**Deployment Script**:
```bash
#!/bin/bash
# scripts/deploy-bluegreen.sh

ENVIRONMENT=$1
IMAGE_TAG=$2

echo "Starting Blue/Green deployment to $ENVIRONMENT"

# Create deployment package
aws deploy push \
  --application-name myapp-$ENVIRONMENT \
  --s3-location s3://myapp-deployments/myapp-$IMAGE_TAG.zip \
  --source .

# Create deployment
DEPLOYMENT_ID=$(aws deploy create-deployment \
  --application-name myapp-$ENVIRONMENT \
  --deployment-group-name myapp-blue-green-dg \
  --s3-location bucket=myapp-deployments,key=myapp-$IMAGE_TAG.zip,bundleType=zip \
  --deployment-config-name production-BlueGreenConfig \
  --description "Blue/Green deployment of $IMAGE_TAG" \
  --query 'deploymentId' \
  --output text)

echo "Deployment created: $DEPLOYMENT_ID"

# Monitor deployment
aws deploy wait deployment-successful --deployment-id $DEPLOYMENT_ID

echo "Deployment successful!"
```

**Tasks**:
- [ ] Install Argo Rollouts in EKS clusters
- [ ] Create rollout definitions for applications
- [ ] Configure CodeDeploy blue/green for EC2
- [ ] Set up monitoring and alerting
- [ ] Test blue/green deployment in dev
- [ ] Document blue/green processes

---

## Summary & Timeline

### Total Estimated Timeline: 8 Weeks

| Phase | Duration | Status |
|-------|----------|--------|
| Phase 1: Security & Access Control | 2 weeks | ❌ Not Started |
| Phase 2: VPC Connectivity | 1 week | ⚠️ Tool Available |
| Phase 3: CI/CD Pipeline | 2 weeks | ❌ Not Started |
| Phase 4: Documentation | 1 week | ❌ Not Started |
| Phase 5: Blue/Green (Bonus) | 2 weeks | ❌ Not Started |

### Priority Order

**Immediate (Week 1-2)**:
1. Restrict DevOps IP ranges
2. Implement EKS RBAC
3. Verify security group rules

**High Priority (Week 3-5)**:
1. Establish VPC connectivity (use CDKTF tool)
2. Build CI/CD pipeline
3. Implement approval process
4. Create promotion workflow

**Medium Priority (Week 6)**:
1. Document route tables
2. Create runbooks
3. Train team

**Bonus (Week 7-8)**:
1. Implement blue/green deployments
2. Set up advanced monitoring

### Success Criteria

- [ ] All requirements from Infrastructure Design Exercise satisfied
- [ ] Zero security findings in production
- [ ] Automated deployments with <5 minute deployment time
- [ ] Zero downtime deployments
- [ ] 100% documentation coverage
- [ ] Team trained on all processes

---

## Next Steps

1. **Review this roadmap** with stakeholders
2. **Assign owners** to each phase
3. **Schedule kickoff** for Phase 1
4. **Set up weekly check-ins** to track progress
5. **Create Jira/GitHub issues** for each task
6. **Begin Phase 1 immediately** (security is critical)
