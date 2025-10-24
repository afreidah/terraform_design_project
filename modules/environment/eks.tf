# -----------------------------------------------------------------------------
# ELASTIC KUBERNETES SERVICE (EKS) CLUSTER
# -----------------------------------------------------------------------------
#
# This file defines an EKS cluster with managed node groups for container
# workload orchestration.
#
# Architecture:
#   - Control Plane: AWS-managed Kubernetes control plane across 3 AZs
#   - Node Groups: Self-managed EC2 instances running kubelet
#   - Networking: Nodes in private app subnets, control plane in AWS VPC
#   - RBAC: Role-based access control with DevOps (admin) and Developer (read-only)
#
# Security:
#   - Encryption: Secrets encrypted with KMS at rest
#   - Network: Private endpoint + optional public endpoint with CIDR restrictions
#   - Logging: All control plane logs sent to CloudWatch
#   - IAM: IRSA (IAM Roles for Service Accounts) enabled via OIDC provider
#
# Access Patterns:
#   - DevOps: Full cluster-admin via IAM role (system:masters group)
#   - Developers: Read-only via IAM role (view-only group)
#   - CI/CD: Can assume roles via OIDC federation
#
# Node Management:
#   - AMI: Amazon EKS-optimized (auto-updated with cluster version)
#   - Scaling: Auto Scaling Group with configurable min/max
#   - Access: SSM Session Manager (no SSH keys required)
#   - Monitoring: CloudWatch Container Insights available
#
# IMPORTANT:
#   - aws-auth ConfigMap must be configured for nodes to join cluster
#   - Security group rules required between cluster and nodes
#   - OIDC provider enables IAM roles for Kubernetes service accounts (IRSA)
#   - Cluster version upgrades require node group AMI updates
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# CLUSTER ENCRYPTION KEY
# -----------------------------------------------------------------------------

# KMS key for encrypting Kubernetes secrets at rest in etcd
module "kms_eks" {
  source = "../kms"

  description = "KMS key for EKS cluster encryption"
  alias_name  = "${var.environment}-eks"

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.environment}-eks-key"
      Purpose = "eks"
    }
  )
}

# -----------------------------------------------------------------------------
# EKS CONTROL PLANE
# -----------------------------------------------------------------------------

module "eks_cluster" {
  source = "../eks-cluster"

  cluster_name               = "${var.environment}-eks"
  vpc_id                     = module.networking.vpc_id
  subnet_ids                 = module.networking.private_app_subnet_ids
  cluster_encryption_key_arn = module.kms_eks.key_arn

  kubernetes_version = var.kubernetes_version

  # -------------------------------------------------------------------------
  # API ENDPOINT ACCESS
  # -------------------------------------------------------------------------
  # Private: VPC-only access (required for nodes)
  # Public: Internet access for kubectl/CI/CD (restrict CIDR in production)
  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = var.eks_public_access_cidrs # TODO: Restrict in production

  # -------------------------------------------------------------------------
  # CONTROL PLANE LOGGING
  # -------------------------------------------------------------------------
  # All log types sent to CloudWatch for audit and troubleshooting
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_retention_days = 90                                 # 3 months retention
  cloudwatch_kms_key_id     = module.kms_cloudwatch_logs.key_arn # Encrypted logs

  # -------------------------------------------------------------------------
  # SECURITY GROUP CONFIGURATION
  # -------------------------------------------------------------------------
  # Set to null to avoid circular dependency
  # Security group rules added separately after node group creation
  node_security_group_id = null

  # -------------------------------------------------------------------------
  # AWS AUTH CONFIGMAP
  # -------------------------------------------------------------------------
  # Don't manage aws-auth here - updated after node group creation
  # This avoids circular dependency between cluster and nodes
  manage_aws_auth_configmap = false
  node_iam_role_arn         = null

  aws_auth_roles = []

  tags = local.common_tags

  depends_on = [
    module.networking,
    module.kms_eks
  ]
}

# -----------------------------------------------------------------------------
# EKS NODE GROUP
# -----------------------------------------------------------------------------

module "eks_node_group" {
  source = "../eks-node-group"

  cluster_name                       = module.eks_cluster.cluster_id
  node_group_name                    = "${var.environment}-nodes"
  cluster_version                    = var.kubernetes_version
  cluster_endpoint                   = module.eks_cluster.cluster_endpoint
  cluster_certificate_authority_data = module.eks_cluster.cluster_certificate_authority_data
  cluster_security_group_id          = module.eks_cluster.cluster_security_group_id

  vpc_id     = module.networking.vpc_id
  subnet_ids = module.networking.private_app_subnet_ids

  # -------------------------------------------------------------------------
  # SCALING CONFIGURATION
  # -------------------------------------------------------------------------
  # Cluster Autoscaler can adjust between min and max based on pod demands
  desired_size = var.eks_node_desired_size # Initial node count
  min_size     = var.eks_node_min_size     # Minimum for availability
  max_size     = var.eks_node_max_size     # Maximum for cost control

  # -------------------------------------------------------------------------
  # INSTANCE CONFIGURATION
  # -------------------------------------------------------------------------
  instance_types = var.eks_node_instance_types # Instance types for node pool
  capacity_type  = var.eks_node_capacity_type  # ON_DEMAND or SPOT
  disk_size      = var.eks_node_disk_size      # GB per node (for pods/images)

  # -------------------------------------------------------------------------
  # SECURITY & MONITORING
  # -------------------------------------------------------------------------
  enable_ssm_access          = true                   # SSM Session Manager access
  disk_encryption_key_id     = module.kms_eks.key_arn # Encrypt EBS volumes
  enable_detailed_monitoring = false                  # CloudWatch detailed monitoring

  tags = local.common_tags

  depends_on = [
    module.eks_cluster
  ]
}

# -----------------------------------------------------------------------------
# SECURITY GROUP RULES
# -----------------------------------------------------------------------------

# Allow nodes to communicate with cluster API server
# IMPORTANT: Created separately to avoid circular dependency
resource "aws_security_group_rule" "cluster_ingress_nodes" {
  description              = "Allow nodes to communicate with cluster API"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks_cluster.cluster_security_group_id
  source_security_group_id = module.eks_node_group.security_group_id

  depends_on = [
    module.eks_cluster,
    module.eks_node_group
  ]
}

# -----------------------------------------------------------------------------
# AWS AUTH CONFIGMAP
# -----------------------------------------------------------------------------

# Update aws-auth ConfigMap to allow nodes and IAM roles to access cluster
# CRITICAL: Without this, nodes cannot join cluster and IAM users cannot kubectl
resource "kubernetes_config_map_v1_data" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(concat(
      # -----------------------------------------------------------------------
      # NODE ROLE (REQUIRED)
      # -----------------------------------------------------------------------
      # Allows EC2 nodes to join cluster and register with control plane
      [
        {
          rolearn  = module.eks_node_group.iam_role_arn
          username = "system:node:{{EC2PrivateDNSName}}"
          groups   = ["system:bootstrappers", "system:nodes"]
        }
      ],
      # -----------------------------------------------------------------------
      # DEVOPS ROLE (FULL ADMIN)
      # -----------------------------------------------------------------------
      # Full cluster-admin access via system:masters group
      [
        {
          rolearn  = aws_iam_role.eks_devops.arn
          username = "devops"
          groups   = ["system:masters"] # Full cluster-admin
        }
      ],
      # -----------------------------------------------------------------------
      # DEVELOPERS ROLE (READ-ONLY)
      # -----------------------------------------------------------------------
      # Read-only access via view-only group
      [
        {
          rolearn  = aws_iam_role.eks_developers.arn
          username = "developers"
          groups   = ["view-only"] # Read-only access
        }
      ],
      # -----------------------------------------------------------------------
      # ADDITIONAL ROLES (FROM VARIABLES)
      # -----------------------------------------------------------------------
      var.eks_aws_auth_roles
    ))
  }

  force = true # Force update if ConfigMap already exists

  depends_on = [
    module.eks_cluster,
    module.eks_node_group
  ]
}

# -----------------------------------------------------------------------------
# IAM ROLES FOR EKS ACCESS
# -----------------------------------------------------------------------------

# DevOps Role - Full admin access to cluster
resource "aws_iam_role" "eks_devops" {
  name = "${var.environment}-eks-devops-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.environment
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Developers Role - Read-only access to cluster
resource "aws_iam_role" "eks_developers" {
  name = "${var.environment}-eks-developers-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.environment
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# ASSUME ROLE POLICIES
# -----------------------------------------------------------------------------

# Policy to allow DevOps IAM users/groups to assume DevOps role
resource "aws_iam_policy" "assume_eks_devops" {
  name        = "${var.environment}-assume-eks-devops"
  description = "Allow assuming EKS DevOps role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = aws_iam_role.eks_devops.arn
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.environment
          }
        }
      }
    ]
  })
}

# Policy to allow Developers IAM users/groups to assume Developers role
resource "aws_iam_policy" "assume_eks_developers" {
  name        = "${var.environment}-assume-eks-developers"
  description = "Allow assuming EKS Developers role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = aws_iam_role.eks_developers.arn
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.environment
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------

output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks_cluster.cluster_id
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks_cluster.cluster_endpoint
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks_cluster.cluster_arn
}

output "eks_cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks_cluster.cluster_version
}

output "eks_oidc_provider_arn" {
  description = "ARN of the OIDC Provider for IRSA"
  value       = module.eks_cluster.oidc_provider_arn
}

output "eks_devops_role_arn" {
  description = "ARN of the EKS DevOps IAM role"
  value       = aws_iam_role.eks_devops.arn
}

output "eks_developers_role_arn" {
  description = "ARN of the EKS Developers IAM role"
  value       = aws_iam_role.eks_developers.arn
}

output "eks_node_group_id" {
  description = "ID of the EKS node group"
  value       = module.eks_node_group.node_group_id
}

output "eks_node_group_status" {
  description = "Status of the EKS node group"
  value       = module.eks_node_group.node_group_status
}

output "eks_node_iam_role_arn" {
  description = "ARN of the node IAM role"
  value       = module.eks_node_group.iam_role_arn
}

output "eks_node_security_group_id" {
  description = "Security group ID for EKS nodes"
  value       = module.eks_node_group.security_group_id
}
