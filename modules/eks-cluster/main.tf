# -----------------------------------------------------------------------------
# EKS CLUSTER
# -----------------------------------------------------------------------------

# EKS Cluster IAM Role
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# Attach required policies to cluster role
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# Security Group for EKS Cluster
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-cluster-sg"
    }
  )
}

# Allow cluster to communicate with worker nodes
resource "aws_security_group_rule" "cluster_egress_to_nodes" {
  count = var.node_security_group_id != null ? 1 : 0

  description              = "Allow cluster to communicate with worker nodes"
  type                     = "egress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = var.node_security_group_id
}

# Allow cluster to communicate with pods (if using security groups for pods)
resource "aws_security_group_rule" "cluster_egress_to_internet" {
  description       = "Allow cluster to communicate with internet for add-ons"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.cluster.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# CloudWatch Log Group for EKS
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = var.cloudwatch_kms_key_id

  tags = var.tags
}

# EKS Cluster
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
    security_group_ids      = [aws_security_group.cluster.id]
  }

  encryption_config {
    provider {
      key_arn = var.cluster_encryption_key_arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.cluster_vpc_resource_controller,
    aws_cloudwatch_log_group.cluster
  ]
}

# -----------------------------------------------------------------------------
# EKS ADD-ONS
# -----------------------------------------------------------------------------

# Around line 120-130, replace the three addon blocks with:

# VPC CNI Add-on (required for pod networking)
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  addon_version               = var.vpc_cni_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  service_account_role_arn    = aws_iam_role.vpc_cni.arn

  tags = var.tags
}

# CoreDNS Add-on
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  addon_version               = var.coredns_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = var.tags

  depends_on = [
    aws_eks_addon.vpc_cni
  ]
}

# kube-proxy Add-on
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  addon_version               = var.kube_proxy_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = var.tags
}

# -----------------------------------------------------------------------------
# VPC CNI IAM ROLE (IRSA)
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "vpc_cni_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.cluster.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vpc_cni" {
  name               = "${var.cluster_name}-vpc-cni-role"
  assume_role_policy = data.aws_iam_policy_document.vpc_cni_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni.name
}

# -----------------------------------------------------------------------------
# OIDC PROVIDER (for IRSA - IAM Roles for Service Accounts)
# -----------------------------------------------------------------------------

data "tls_certificate" "cluster" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = var.tags
}

# -----------------------------------------------------------------------------
# AWS-AUTH CONFIGMAP (IAM to K8s RBAC mapping)
# -----------------------------------------------------------------------------

# Data source to get current AWS account
data "aws_caller_identity" "current" {}

# Create aws-auth ConfigMap
resource "kubernetes_config_map_v1_data" "aws_auth" {
  count = var.manage_aws_auth_configmap ? 1 : 0

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(concat(
      # Node role (required for nodes to join cluster)
      var.node_iam_role_arn != null ? [
        {
          rolearn  = var.node_iam_role_arn
          username = "system:node:{{EC2PrivateDNSName}}"
          groups   = ["system:bootstrappers", "system:nodes"]
        }
      ] : [],
      # Additional roles (DevOps, Developers, etc.)
      var.aws_auth_roles
    ))

    mapUsers = yamlencode(var.aws_auth_users)
  }

  force = true

  depends_on = [
    aws_eks_cluster.this
  ]
}
