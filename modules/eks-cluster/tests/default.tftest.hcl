# ----------------------------------------------------------------
# EKS Cluster Module Test Suite
#
# Tests the EKS cluster module for security defaults, encryption,
# logging configurations, OIDC provider setup, add-on creation,
# and conditional endpoint access configurations.
# ----------------------------------------------------------------

variables {
  # Mock VPC and networking
  vpc_id     = "vpc-12345678"
  subnet_ids = ["subnet-11111111", "subnet-22222222", "subnet-33333333"]

  # Mock KMS key
  test_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"

  # Mock node security group
  test_node_sg_id = "sg-nodes12345"
}

# ----------------------------------------------------------------
# Security defaults are enforced
# Expected: Encryption enabled, private endpoint enabled
# ----------------------------------------------------------------
run "security_defaults" {
  command = plan

  variables {
    cluster_name               = "test-cluster"
    vpc_id                     = var.vpc_id
    subnet_ids                 = var.subnet_ids
    cluster_encryption_key_arn = var.test_kms_key_arn
  }

  # Assert cluster encryption is configured
  assert {
    condition     = length(aws_eks_cluster.this.encryption_config) > 0
    error_message = "EKS cluster must have encryption configured"
  }

  # Assert encryption uses provided KMS key
  assert {
    condition     = aws_eks_cluster.this.encryption_config[0].provider[0].key_arn == var.test_kms_key_arn
    error_message = "EKS cluster must use provided KMS key for encryption"
  }

  # Assert secrets are encrypted
  assert {
    condition     = contains(aws_eks_cluster.this.encryption_config[0].resources, "secrets")
    error_message = "Kubernetes secrets must be encrypted at rest"
  }

  # Assert private endpoint is enabled by default
  assert {
    condition     = tobool(aws_eks_cluster.this.vpc_config[0].endpoint_private_access) == true
    error_message = "Private API endpoint should be enabled by default"
  }

  # Assert public endpoint is enabled by default
  assert {
    condition     = tobool(aws_eks_cluster.this.vpc_config[0].endpoint_public_access) == true
    error_message = "Public API endpoint should be enabled by default"
  }
}

# ----------------------------------------------------------------
# CloudWatch log group naming convention
# Expected: Log group follows /aws/eks/{cluster_name}/cluster pattern
# ----------------------------------------------------------------
run "cloudwatch_log_group_naming" {
  command = plan

  variables {
    cluster_name               = "my-eks-cluster"
    vpc_id                     = var.vpc_id
    subnet_ids                 = var.subnet_ids
    cluster_encryption_key_arn = var.test_kms_key_arn
  }

  # Assert log group follows naming convention
  assert {
    condition     = aws_cloudwatch_log_group.cluster.name == "/aws/eks/my-eks-cluster/cluster"
    error_message = "CloudWatch log group should follow /aws/eks/{cluster_name}/cluster naming convention"
  }
}

# ----------------------------------------------------------------
# Control plane logging is configurable
# Expected: Only specified log types are enabled
# ----------------------------------------------------------------
run "control_plane_logging" {
  command = plan

  variables {
    cluster_name               = "test-cluster"
    vpc_id                     = var.vpc_id
    subnet_ids                 = var.subnet_ids
    cluster_encryption_key_arn = var.test_kms_key_arn
    enabled_cluster_log_types  = ["api", "audit"]
  }

  # Assert only specified log types are enabled
  assert {
    condition     = length(aws_eks_cluster.this.enabled_cluster_log_types) == 2
    error_message = "Should enable exactly the specified log types"
  }

  # Assert API logs are enabled
  assert {
    condition     = contains(aws_eks_cluster.this.enabled_cluster_log_types, "api")
    error_message = "API logs should be enabled when specified"
  }

  # Assert audit logs are enabled
  assert {
    condition     = contains(aws_eks_cluster.this.enabled_cluster_log_types, "audit")
    error_message = "Audit logs should be enabled when specified"
  }
}

# ----------------------------------------------------------------
# Endpoint access combinations work
# Expected: Public and private can be toggled independently
# ----------------------------------------------------------------
run "endpoint_private_only" {
  command = plan

  variables {
    cluster_name               = "test-cluster"
    vpc_id                     = var.vpc_id
    subnet_ids                 = var.subnet_ids
    cluster_encryption_key_arn = var.test_kms_key_arn
    endpoint_private_access    = true
    endpoint_public_access     = false
  }

  # Assert private is enabled
  assert {
    condition     = tobool(aws_eks_cluster.this.vpc_config[0].endpoint_private_access) == true
    error_message = "Private endpoint should be enabled"
  }

  # Assert public is disabled
  assert {
    condition     = tobool(aws_eks_cluster.this.vpc_config[0].endpoint_public_access) == false
    error_message = "Public endpoint should be disabled"
  }
}

# ----------------------------------------------------------------
# Public access CIDRs are configurable
# Expected: CIDR restrictions apply when public access enabled
# ----------------------------------------------------------------
run "public_access_cidrs" {
  command = plan

  variables {
    cluster_name               = "test-cluster"
    vpc_id                     = var.vpc_id
    subnet_ids                 = var.subnet_ids
    cluster_encryption_key_arn = var.test_kms_key_arn
    endpoint_public_access     = true
    public_access_cidrs        = ["10.0.0.0/8", "172.16.0.0/12"]
  }

  # Assert CIDR restrictions are applied
  assert {
    condition     = length(aws_eks_cluster.this.vpc_config[0].public_access_cidrs) == 2
    error_message = "Should apply specified CIDR restrictions"
  }

  # Assert specific CIDR is present
  assert {
    condition     = contains(aws_eks_cluster.this.vpc_config[0].public_access_cidrs, "10.0.0.0/8")
    error_message = "Should include specified CIDR blocks"
  }
}

# ----------------------------------------------------------------
# OIDC provider is created
# Expected: OIDC provider configured for IRSA
# ----------------------------------------------------------------
run "oidc_provider_creation" {
  command = plan

  variables {
    cluster_name               = "test-cluster"
    vpc_id                     = var.vpc_id
    subnet_ids                 = var.subnet_ids
    cluster_encryption_key_arn = var.test_kms_key_arn
  }

  # Assert OIDC provider is configured for STS (client_id_list is a set, use contains)
  assert {
    condition     = contains(aws_iam_openid_connect_provider.cluster.client_id_list, "sts.amazonaws.com")
    error_message = "OIDC provider should be configured for STS"
  }
}

# ----------------------------------------------------------------
# VPC CNI add-on with IRSA
# Expected: VPC CNI has service account IAM role
# ----------------------------------------------------------------
run "vpc_cni_addon_irsa" {
  command = plan

  variables {
    cluster_name               = "test-cluster"
    vpc_id                     = var.vpc_id
    subnet_ids                 = var.subnet_ids
    cluster_encryption_key_arn = var.test_kms_key_arn
  }

  # Assert VPC CNI add-on is created
  assert {
    condition     = aws_eks_addon.vpc_cni.addon_name == "vpc-cni"
    error_message = "VPC CNI add-on should be installed"
  }

  # Assert VPC CNI IAM role is created for IRSA
  assert {
    condition     = length(aws_iam_role.vpc_cni.name) > 0
    error_message = "VPC CNI should have dedicated IAM role for IRSA"
  }

  # Assert IAM role has CNI policy attached
  assert {
    condition     = aws_iam_role_policy_attachment.vpc_cni.policy_arn == "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    error_message = "VPC CNI role should have AmazonEKS_CNI_Policy attached"
  }
}

# ----------------------------------------------------------------
# CoreDNS add-on is created
# Expected: CoreDNS add-on installed with correct dependencies
# ----------------------------------------------------------------
run "coredns_addon" {
  command = plan

  variables {
    cluster_name               = "test-cluster"
    vpc_id                     = var.vpc_id
    subnet_ids                 = var.subnet_ids
    cluster_encryption_key_arn = var.test_kms_key_arn
  }

  # Assert CoreDNS add-on is created
  assert {
    condition     = aws_eks_addon.coredns.addon_name == "coredns"
    error_message = "CoreDNS add-on should be installed"
  }

  # Assert CoreDNS has conflict resolution strategy
  assert {
    condition     = aws_eks_addon.coredns.resolve_conflicts_on_create == "OVERWRITE"
    error_message = "CoreDNS should use OVERWRITE conflict resolution"
  }
}

# ----------------------------------------------------------------
# Kube-proxy add-on is created
# Expected: Kube-proxy add-on installed
# ----------------------------------------------------------------
run "kube_proxy_addon" {
  command = plan

  variables {
    cluster_name               = "test-cluster"
    vpc_id                     = var.vpc_id
    subnet_ids                 = var.subnet_ids
    cluster_encryption_key_arn = var.test_kms_key_arn
  }

  # Assert kube-proxy add-on is created
  assert {
    condition     = aws_eks_addon.kube_proxy.addon_name == "kube-proxy"
    error_message = "Kube-proxy add-on should be installed"
  }
}

# ----------------------------------------------------------------
# Cluster security group is created
# Expected: Security group for control plane communication
# ----------------------------------------------------------------
run "cluster_security_group" {
  command = plan

  variables {
    cluster_name               = "test-cluster"
    vpc_id                     = var.vpc_id
    subnet_ids                 = var.subnet_ids
    cluster_encryption_key_arn = var.test_kms_key_arn
  }

  # Assert cluster security group is created
  assert {
    condition     = aws_security_group.cluster.vpc_id == var.vpc_id
    error_message = "Cluster security group should be in correct VPC"
  }

  # Assert security group has descriptive name
  assert {
    condition     = aws_security_group.cluster.name == "test-cluster-cluster-sg"
    error_message = "Cluster security group should follow naming convention"
  }
}

# ----------------------------------------------------------------
# Cluster security group egress to nodes
# Expected: Security group rule created when node SG provided
# ----------------------------------------------------------------
run "cluster_sg_egress_to_nodes" {
  command = plan

  variables {
    cluster_name               = "test-cluster"
    vpc_id                     = var.vpc_id
    subnet_ids                 = var.subnet_ids
    cluster_encryption_key_arn = var.test_kms_key_arn
    node_security_group_id     = var.test_node_sg_id
  }

  # Assert egress rule is created
  assert {
    condition     = length(aws_security_group_rule.cluster_egress_to_nodes) == 1
    error_message = "Should create egress rule to nodes when node SG provided"
  }

  # Assert rule allows all protocols
  assert {
    condition     = aws_security_group_rule.cluster_egress_to_nodes[0].protocol == "-1"
    error_message = "Cluster should be able to communicate with nodes on all protocols"
  }
}

# ----------------------------------------------------------------
# Cluster IAM role has correct policies
# Expected: Required EKS policies attached
# ----------------------------------------------------------------
run "cluster_iam_role" {
  command = plan

  variables {
    cluster_name               = "test-cluster"
    vpc_id                     = var.vpc_id
    subnet_ids                 = var.subnet_ids
    cluster_encryption_key_arn = var.test_kms_key_arn
  }

  # Assert cluster policy is attached
  assert {
    condition     = aws_iam_role_policy_attachment.cluster_policy.policy_arn == "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    error_message = "Cluster role should have AmazonEKSClusterPolicy"
  }

  # Assert VPC resource controller policy is attached
  assert {
    condition     = aws_iam_role_policy_attachment.cluster_vpc_resource_controller.policy_arn == "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
    error_message = "Cluster role should have VPC resource controller policy"
  }
}

# ----------------------------------------------------------------
# CloudWatch log retention is configurable
# Expected: Custom retention period applied
# ----------------------------------------------------------------
run "cloudwatch_retention" {
  command = plan

  variables {
    cluster_name               = "test-cluster"
    vpc_id                     = var.vpc_id
    subnet_ids                 = var.subnet_ids
    cluster_encryption_key_arn = var.test_kms_key_arn
    cloudwatch_retention_days  = 30
  }

  # Assert retention period is set correctly
  assert {
    condition     = tonumber(aws_cloudwatch_log_group.cluster.retention_in_days) == 30
    error_message = "CloudWatch log retention should be configurable"
  }
}

# ----------------------------------------------------------------
# Multi-subnet deployment
# Expected: Cluster spans all provided subnets for HA
# ----------------------------------------------------------------
run "multi_subnet_deployment" {
  command = plan

  variables {
    cluster_name               = "test-cluster"
    vpc_id                     = var.vpc_id
    subnet_ids                 = var.subnet_ids
    cluster_encryption_key_arn = var.test_kms_key_arn
  }

  # Assert all subnets are used
  assert {
    condition     = length(aws_eks_cluster.this.vpc_config[0].subnet_ids) == 3
    error_message = "EKS cluster should span all provided subnets for high availability"
  }
}
