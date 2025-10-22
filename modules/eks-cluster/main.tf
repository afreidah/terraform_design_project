# -----------------------------------------------------------------------------
# EKS CLUSTER MODULE
# -----------------------------------------------------------------------------
#
# This module creates a production-ready Amazon Elastic Kubernetes Service
# (EKS) cluster with security hardening, encryption, logging, and IAM Roles
# for Service Accounts (IRSA) support.
#
# Components Created:
#   - EKS Cluster: Managed Kubernetes control plane
#   - IAM Roles: Cluster role and VPC CNI service account role
#   - Security Groups: Network access control for control plane
#   - CloudWatch Logs: Control plane audit and diagnostic logging
#   - OIDC Provider: IAM Roles for Service Accounts (IRSA) integration
#   - EKS Add-ons: VPC CNI, CoreDNS, kube-proxy
#   - AWS Auth ConfigMap: IAM to Kubernetes RBAC mapping
#
# Features:
#   - Secrets encryption at rest using KMS
#   - Control plane logging to CloudWatch
#   - Private and/or public API endpoint access
#   - IRSA support for pod-level IAM permissions
#   - Automated add-on management with version control
#   - IAM-to-Kubernetes authentication via aws-auth ConfigMap
#
# Security Model:
#   - Secrets Encryption: KMS encryption for Kubernetes secrets
#   - Network Isolation: Security groups control control plane access
#   - Audit Logging: CloudWatch logs for compliance and security analysis
#   - Least Privilege IAM: Separate roles for cluster and service accounts
#   - IRSA: Pod-level IAM permissions without node-level credentials
#
# IMPORTANT:
#   - Cluster encryption key must be provided via cluster_encryption_key_arn
#   - OIDC provider enables IRSA for secure pod authentication
#   - aws-auth ConfigMap management requires kubernetes provider configuration
#   - Add-on versions should be compatible with kubernetes_version
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# EKS CLUSTER IAM ROLE
# -----------------------------------------------------------------------------

# IAM role for EKS cluster control plane
# Allows EKS service to manage AWS resources on behalf of the cluster
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

# -------------------------------------------------------------------------
# CLUSTER IAM POLICY ATTACHMENTS
# -------------------------------------------------------------------------

# Core EKS cluster policy for managing cluster resources
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# VPC resource controller policy for managing ENIs and IP addresses
resource "aws_iam_role_policy_attachment" "cluster_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# -----------------------------------------------------------------------------
# EKS CLUSTER SECURITY GROUP
# -----------------------------------------------------------------------------

# Security group for EKS control plane
# Controls network access to the Kubernetes API server
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

# -------------------------------------------------------------------------
# CLUSTER SECURITY GROUP RULES
# -------------------------------------------------------------------------

# Allow cluster control plane to communicate with worker nodes
# Required for kubelet and pod communication
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

# Allow cluster to reach internet for EKS add-ons and AWS services
# Required for add-on installation and updates
resource "aws_security_group_rule" "cluster_egress_to_internet" {
  description       = "Allow cluster to communicate with internet for add-ons"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.cluster.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# -----------------------------------------------------------------------------
# CLOUDWATCH LOG GROUP
# -----------------------------------------------------------------------------

# CloudWatch log group for EKS control plane logs
# Stores audit logs, API server logs, and other control plane diagnostics
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = var.cloudwatch_kms_key_id

  tags = var.tags
}

# -----------------------------------------------------------------------------
# EKS CLUSTER
# -----------------------------------------------------------------------------

# Amazon EKS managed Kubernetes cluster
# Provides managed control plane with optional encryption and logging
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  # -------------------------------------------------------------------------
  # VPC CONFIGURATION
  # -------------------------------------------------------------------------
  # Network settings for control plane placement and API endpoint access
  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
    security_group_ids      = [aws_security_group.cluster.id]
  }

  # -------------------------------------------------------------------------
  # ENCRYPTION CONFIGURATION
  # -------------------------------------------------------------------------
  # Encrypts Kubernetes secrets at rest using KMS
  encryption_config {
    provider {
      key_arn = var.cluster_encryption_key_arn
    }
    resources = ["secrets"]
  }

  # -------------------------------------------------------------------------
  # CONTROL PLANE LOGGING
  # -------------------------------------------------------------------------
  # Enable control plane logs for audit and diagnostics
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

# -------------------------------------------------------------------------
# VPC CNI ADD-ON
# -------------------------------------------------------------------------
# AWS VPC CNI plugin for Kubernetes pod networking
# Assigns VPC IP addresses to pods and manages ENIs
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  addon_version               = var.vpc_cni_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  service_account_role_arn    = aws_iam_role.vpc_cni.arn

  tags = var.tags
}

# -------------------------------------------------------------------------
# COREDNS ADD-ON
# -------------------------------------------------------------------------
# CoreDNS for Kubernetes DNS resolution
# Provides service discovery within the cluster
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

# -------------------------------------------------------------------------
# KUBE-PROXY ADD-ON
# -------------------------------------------------------------------------
# kube-proxy for Kubernetes networking and service load balancing
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

# Trust policy for VPC CNI service account to assume IAM role
# Uses OIDC provider for secure authentication
data "aws_iam_policy_document" "vpc_cni_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.cluster.arn]
    }

    # Verify the service account is aws-node in kube-system namespace
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    # Verify the audience is AWS STS
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# IAM role for VPC CNI plugin with IRSA
resource "aws_iam_role" "vpc_cni" {
  name               = "${var.cluster_name}-vpc-cni-role"
  assume_role_policy = data.aws_iam_policy_document.vpc_cni_assume_role.json

  tags = var.tags
}

# Attach AWS managed VPC CNI policy to the role
resource "aws_iam_role_policy_attachment" "vpc_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni.name
}

# -----------------------------------------------------------------------------
# OIDC PROVIDER (IAM ROLES FOR SERVICE ACCOUNTS)
# -----------------------------------------------------------------------------

# Retrieve TLS certificate from EKS OIDC issuer
# Used to establish trust between EKS and AWS IAM
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# OIDC provider for IAM Roles for Service Accounts (IRSA)
# Enables Kubernetes service accounts to assume IAM roles
resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = var.tags
}

# -----------------------------------------------------------------------------
# AWS-AUTH CONFIGMAP (IAM TO KUBERNETES RBAC MAPPING)
# -----------------------------------------------------------------------------

# Get current AWS account information
data "aws_caller_identity" "current" {}

# aws-auth ConfigMap for mapping IAM roles/users to Kubernetes RBAC
# Enables AWS IAM entities to authenticate to the Kubernetes cluster
resource "kubernetes_config_map_v1_data" "aws_auth" {
  count = var.manage_aws_auth_configmap ? 1 : 0

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    # Map IAM roles to Kubernetes groups
    mapRoles = yamlencode(concat(
      # Node role (required for worker nodes to join cluster)
      var.node_iam_role_arn != null ? [
        {
          rolearn  = var.node_iam_role_arn
          username = "system:node:{{EC2PrivateDNSName}}"
          groups   = ["system:bootstrappers", "system:nodes"]
        }
      ] : [],
      # Additional IAM roles (DevOps, Developers, etc.)
      var.aws_auth_roles
    ))

    # Map IAM users to Kubernetes groups
    mapUsers = yamlencode(var.aws_auth_users)
  }

  force = true

  depends_on = [
    aws_eks_cluster.this
  ]
}
