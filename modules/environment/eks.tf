# -----------------------------------------------------------------------------
# EKS CLUSTER
# -----------------------------------------------------------------------------

# KMS key for EKS cluster encryption
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

# EKS Cluster
module "eks_cluster" {
  source = "../eks-cluster"

  cluster_name               = "${var.environment}-eks"
  vpc_id                     = module.networking.vpc_id
  subnet_ids                 = module.networking.private_app_subnet_ids
  cluster_encryption_key_arn = module.kms_eks.key_arn

  kubernetes_version = var.kubernetes_version

  # API endpoint access
  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = var.eks_public_access_cidrs

  # Logging
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_retention_days = 90
  cloudwatch_kms_key_id     = module.kms_cloudwatch_logs.key_arn

  # Don't reference node security group (circular dependency)
  node_security_group_id = null

  # Don't manage aws-auth here (we'll do it after node group)
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

  # Scaling
  desired_size = var.eks_node_desired_size
  min_size     = var.eks_node_min_size
  max_size     = var.eks_node_max_size

  # Instance configuration
  instance_types = var.eks_node_instance_types
  capacity_type  = var.eks_node_capacity_type
  disk_size      = var.eks_node_disk_size

  # Security
  enable_ssm_access          = true
  alb_security_group_id      = module.security_groups["alb_public"].security_group_id
  disk_encryption_key_id     = module.kms_eks.key_arn
  enable_detailed_monitoring = false

  tags = local.common_tags

  depends_on = [
    module.eks_cluster
  ]
}

# Update cluster security group to allow traffic from nodes
resource "aws_security_group_rule" "cluster_ingress_nodes" {
  description              = "Allow nodes to communicate with cluster API"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks_cluster.cluster_security_group_id
  source_security_group_id = module.eks_node_group.security_group_id
}

# Update aws-auth ConfigMap to allow nodes to join
resource "kubernetes_config_map_v1_data" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(concat(
      # Node role (required for nodes to join cluster)
      [
        {
          rolearn  = module.eks_node_group.iam_role_arn
          username = "system:node:{{EC2PrivateDNSName}}"
          groups   = ["system:bootstrappers", "system:nodes"]
        }
      ],
      # DevOps - Full admin
      [
        {
          rolearn  = aws_iam_role.eks_devops.arn
          username = "devops"
          groups   = ["system:masters"]
        }
      ],
      # Developers - Read-only
      [
        {
          rolearn  = aws_iam_role.eks_developers.arn
          username = "developers"
          groups   = ["view-only"]
        }
      ],
      # Additional roles from variables
      var.eks_aws_auth_roles
    ))
  }

  force = true

  depends_on = [
    module.eks_cluster,
    module.eks_node_group
  ]
}

# -----------------------------------------------------------------------------
# IAM ROLES FOR EKS ACCESS
# -----------------------------------------------------------------------------

# DevOps Role - Full admin access
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

# Developers Role - Read-only access
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

# Policy to allow assuming the DevOps role (attach to DevOps IAM users/groups)
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

# Policy to allow assuming the Developers role
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
