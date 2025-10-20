# EKS Cluster Module

Creates an Amazon EKS (Elastic Kubernetes Service) cluster with best practices for security, networking, and RBAC.

## Features

- **Managed Control Plane** - AWS-managed Kubernetes control plane across multiple AZs
- **Encryption** - KMS encryption for secrets at rest
- **Logging** - CloudWatch logs for API, audit, authenticator, controller manager, and scheduler
- **IRSA Support** - IAM Roles for Service Accounts via OIDC provider
- **Managed Add-ons** - VPC CNI, CoreDNS, and kube-proxy
- **AWS Auth ConfigMap** - IAM to Kubernetes RBAC mapping
- **Flexible Access** - Public and/or private API endpoint access

## Architecture

```
┌─────────────────────────────────────────────────┐
│  EKS Control Plane (AWS Managed)                │
│  - API Server                                   │
│  - etcd                                         │
│  - Controller Manager                           │
│  - Scheduler                                    │
└────────────────┬────────────────────────────────┘
                 │
                 │ (Secure Communication)
                 │
┌────────────────┴────────────────────────────────┐
│  Worker Nodes (Your VPC)                        │
│  - Kubelet                                      │
│  - kube-proxy                                   │
│  - Container Runtime                            │
│  - Your Pods                                    │
└─────────────────────────────────────────────────┘
```

## Usage

### Basic Example

```hcl
module "eks_cluster" {
  source = "../../modules/eks-cluster"

  cluster_name               = "production-eks"
  vpc_id                     = module.networking.vpc_id
  subnet_ids                 = module.networking.private_app_subnet_ids
  cluster_encryption_key_arn = module.kms_eks.key_arn

  # Kubernetes version
  kubernetes_version = "1.31"

  # API endpoint access
  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = ["0.0.0.0/0"] # Restrict in production

  # Logging
  enabled_cluster_log_types = ["api", "audit", "authenticator"]
  cloudwatch_retention_days = 90
  cloudwatch_kms_key_id     = module.kms_cloudwatch_logs.key_arn

  # Node security group (created by node group module)
  node_security_group_id = module.eks_node_group.security_group_id

  # IAM mappings
  manage_aws_auth_configmap = true
  node_iam_role_arn         = module.eks_node_group.iam_role_arn

  aws_auth_roles = [
    # DevOps - Full admin access
    {
      rolearn  = aws_iam_role.devops.arn
      username = "devops"
      groups   = ["system:masters"]
    },
    # Developers - Read-only access
    {
      rolearn  = aws_iam_role.developers.arn
      username = "developers"
      groups   = ["view-only"]
    }
  ]

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

### With Custom IAM Roles

```hcl
# Create DevOps role
resource "aws_iam_role" "devops" {
  name = "eks-devops-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Create Developers role
resource "aws_iam_role" "developers" {
  name = "eks-developers-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Create read-only ClusterRole (apply with kubectl after cluster creation)
# See examples/rbac/read-only-clusterrole.yaml
```

## Access Control

### IAM to Kubernetes Mapping

The module manages the `aws-auth` ConfigMap which maps IAM identities to Kubernetes RBAC groups:

**IAM Role → K8s Groups → Permissions**

Example:
```
DevOps IAM Role
  └─> system:masters group
       └─> Full cluster admin permissions

Developers IAM Role
  └─> view-only group
       └─> Read-only permissions (ClusterRole must be created separately)
```

### Accessing the Cluster

After cluster creation:

```bash
# Update kubeconfig
aws eks update-kubeconfig --name production-eks --region us-east-1

# Verify access
kubectl get nodes
kubectl get pods -A

# Assume DevOps role
aws sts assume-role --role-arn arn:aws:iam::ACCOUNT:role/eks-devops-role --role-session-name devops-session

# Export credentials and access cluster
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...

kubectl get nodes  # Full access
```

## Security Best Practices

1. **Private Subnets** - Place cluster in private subnets
2. **Restrict Public Access** - Limit `public_access_cidrs` to specific IPs/VPNs
3. **Enable Logging** - Monitor API and audit logs
4. **KMS Encryption** - Encrypt secrets at rest
5. **IRSA** - Use IAM Roles for Service Accounts instead of node IAM roles
6. **Network Policies** - Implement Kubernetes NetworkPolicies for pod-to-pod security
7. **Security Groups for Pods** - Use EKS security groups for pod-level control

## Add-ons

The module installs essential add-ons:

- **VPC CNI** - Pod networking (pods get VPC IPs)
- **CoreDNS** - DNS resolution within cluster
- **kube-proxy** - Network proxy on each node

Additional add-ons (install separately):
- AWS Load Balancer Controller (for Ingress)
- External Secrets Operator (for secrets management)
- Cluster Autoscaler or Karpenter (for node scaling)
- EBS CSI Driver (for persistent volumes)

## Requirements

- VPC with private subnets across multiple AZs
- KMS key for cluster encryption
- Kubernetes provider configured (see example below)

### Kubernetes Provider Configuration

```hcl
# Configure Kubernetes provider after cluster creation
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks_cluster.cluster_id
}

provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}
```

## Troubleshooting

### Cannot connect to cluster
- Verify `endpoint_public_access` is `true` or you're connecting from within VPC
- Check security group rules
- Ensure IAM role is mapped in aws-auth ConfigMap

### Nodes not joining cluster
- Verify node IAM role is in aws-auth ConfigMap
- Check node security group allows communication with cluster
- Review node launch template user data

### Add-on installation fails
- Check VPC has proper DNS settings
- Ensure subnets are properly tagged for EKS
- Verify KMS key permissions

## Inputs

See `variables.tf` for complete list.

## Outputs

See `outputs.tf` for complete list.

## License

Internal use only.
