# ----------------------------------------------------------------
# EKS Node Group Module Test Suite
#
# Tests the EKS node group module for security defaults (IMDSv2,
# encryption, monitoring), IAM configuration, launch template
# settings, conditional policies, and multi-AZ deployment.
# ----------------------------------------------------------------

variables {
  # Mock cluster and networking
  test_cluster_name     = "test-cluster"
  test_cluster_version  = "1.31"
  test_cluster_endpoint = "https://test-cluster.eks.us-east-1.amazonaws.com"
  test_cluster_ca       = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t" # Base64 mock
  test_cluster_sg_id    = "sg-cluster12345"
  test_vpc_id           = "vpc-12345678"
  test_subnet_ids       = ["subnet-11111111", "subnet-22222222", "subnet-33333333"]
  test_alb_sg_id        = "sg-alb12345"
  test_kms_key_id       = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  test_ami_id           = "ami-12345678" # Mock AMI to avoid SSM data source lookup
}

# ----------------------------------------------------------------
# Security defaults are enforced
# Expected: IMDSv2 required, EBS encrypted, monitoring enabled
# ----------------------------------------------------------------
run "security_defaults" {
  command = plan

  variables {
    cluster_name                       = var.test_cluster_name
    node_group_name                    = "test-nodes"
    cluster_version                    = var.test_cluster_version
    cluster_endpoint                   = var.test_cluster_endpoint
    cluster_certificate_authority_data = var.test_cluster_ca
    cluster_security_group_id          = var.test_cluster_sg_id
    vpc_id                             = var.test_vpc_id
    subnet_ids                         = var.test_subnet_ids
    ami_id                             = var.test_ami_id
    desired_size                       = 2
    min_size                           = 1
    max_size                           = 3
  }

  # Assert IMDSv2 is REQUIRED (not optional)
  assert {
    condition     = aws_launch_template.node.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be required for security"
  }

  # Assert IMDS hop limit is 2 for EKS (pods need to access IMDS)
  assert {
    condition     = tonumber(aws_launch_template.node.metadata_options[0].http_put_response_hop_limit) == 2
    error_message = "IMDS hop limit should be 2 for EKS pods to access IMDS"
  }

  # Assert EBS encryption is ENABLED by default
  assert {
    condition     = tobool(aws_launch_template.node.block_device_mappings[0].ebs[0].encrypted) == true
    error_message = "EBS volumes must be encrypted"
  }

  # Assert EBS delete on termination
  assert {
    condition     = tobool(aws_launch_template.node.block_device_mappings[0].ebs[0].delete_on_termination) == true
    error_message = "EBS volumes should be deleted on termination"
  }
}

# ----------------------------------------------------------------
# IAM role has required EKS node policies
# Expected: Worker, CNI, and ECR policies attached
# ----------------------------------------------------------------
run "iam_policies" {
  command = plan

  variables {
    cluster_name                       = var.test_cluster_name
    node_group_name                    = "test-nodes"
    cluster_version                    = var.test_cluster_version
    cluster_endpoint                   = var.test_cluster_endpoint
    cluster_certificate_authority_data = var.test_cluster_ca
    cluster_security_group_id          = var.test_cluster_sg_id
    vpc_id                             = var.test_vpc_id
    subnet_ids                         = var.test_subnet_ids
    ami_id                             = var.test_ami_id
    desired_size                       = 2
    min_size                           = 1
    max_size                           = 3
  }

  # Assert EKS Worker Node Policy is attached
  assert {
    condition     = aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy.policy_arn == "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    error_message = "Node role must have AmazonEKSWorkerNodePolicy"
  }

  # Assert CNI Policy is attached
  assert {
    condition     = aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy.policy_arn == "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    error_message = "Node role must have AmazonEKS_CNI_Policy"
  }

  # Assert ECR Read Only Policy is attached
  assert {
    condition     = aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly.policy_arn == "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    error_message = "Node role must have AmazonEC2ContainerRegistryReadOnly"
  }
}

# ----------------------------------------------------------------
# SSM access policy is conditional
# Expected: SSM policy attached only when enabled
# ----------------------------------------------------------------
run "ssm_access_enabled" {
  command = plan

  variables {
    cluster_name                       = var.test_cluster_name
    node_group_name                    = "test-nodes"
    cluster_version                    = var.test_cluster_version
    cluster_endpoint                   = var.test_cluster_endpoint
    cluster_certificate_authority_data = var.test_cluster_ca
    cluster_security_group_id          = var.test_cluster_sg_id
    vpc_id                             = var.test_vpc_id
    subnet_ids                         = var.test_subnet_ids
    ami_id                             = var.test_ami_id
    enable_ssm_access                  = true
    desired_size                       = 1
    min_size                           = 1
    max_size                           = 1
  }

  # Assert SSM policy is attached when enabled
  assert {
    condition     = length(aws_iam_role_policy_attachment.node_AmazonSSMManagedInstanceCore) == 1
    error_message = "SSM policy should be attached when enable_ssm_access is true"
  }
}

run "ssm_access_disabled" {
  command = plan

  variables {
    cluster_name                       = var.test_cluster_name
    node_group_name                    = "test-nodes"
    cluster_version                    = var.test_cluster_version
    cluster_endpoint                   = var.test_cluster_endpoint
    cluster_certificate_authority_data = var.test_cluster_ca
    cluster_security_group_id          = var.test_cluster_sg_id
    vpc_id                             = var.test_vpc_id
    subnet_ids                         = var.test_subnet_ids
    ami_id                             = var.test_ami_id
    enable_ssm_access                  = false
    desired_size                       = 1
    min_size                           = 1
    max_size                           = 1
  }

  # Assert SSM policy is NOT attached when disabled
  assert {
    condition     = length(aws_iam_role_policy_attachment.node_AmazonSSMManagedInstanceCore) == 0
    error_message = "SSM policy should not be attached when enable_ssm_access is false"
  }
}

# ----------------------------------------------------------------
# CloudWatch agent policy is conditional
# Expected: CloudWatch policy attached only when enabled
# ----------------------------------------------------------------
run "cloudwatch_agent_enabled" {
  command = plan

  variables {
    cluster_name                       = var.test_cluster_name
    node_group_name                    = "test-nodes"
    cluster_version                    = var.test_cluster_version
    cluster_endpoint                   = var.test_cluster_endpoint
    cluster_certificate_authority_data = var.test_cluster_ca
    cluster_security_group_id          = var.test_cluster_sg_id
    vpc_id                             = var.test_vpc_id
    subnet_ids                         = var.test_subnet_ids
    ami_id                             = var.test_ami_id
    enable_cloudwatch_agent            = true
    desired_size                       = 1
    min_size                           = 1
    max_size                           = 1
  }

  # Assert CloudWatch policy is attached when enabled
  assert {
    condition     = length(aws_iam_role_policy_attachment.node_CloudWatchAgentServerPolicy) == 1
    error_message = "CloudWatch policy should be attached when enable_cloudwatch_agent is true"
  }
}

# ----------------------------------------------------------------
# Security group rules for cluster communication
# Expected: Ingress from cluster, egress to cluster and internet
# ----------------------------------------------------------------
run "security_group_rules" {
  command = plan

  variables {
    cluster_name                       = var.test_cluster_name
    node_group_name                    = "test-nodes"
    cluster_version                    = var.test_cluster_version
    cluster_endpoint                   = var.test_cluster_endpoint
    cluster_certificate_authority_data = var.test_cluster_ca
    cluster_security_group_id          = var.test_cluster_sg_id
    vpc_id                             = var.test_vpc_id
    subnet_ids                         = var.test_subnet_ids
    ami_id                             = var.test_ami_id
    desired_size                       = 1
    min_size                           = 1
    max_size                           = 1
  }

  # Assert security group is created in correct VPC
  assert {
    condition     = aws_security_group.node.vpc_id == var.test_vpc_id
    error_message = "Node security group should be in correct VPC"
  }

  # Assert nodes can communicate with each other
  assert {
    condition     = aws_security_group_rule.node_ingress_self.self == true
    error_message = "Nodes should be able to communicate with each other"
  }

  # Assert nodes can receive traffic from cluster control plane
  assert {
    condition     = aws_security_group_rule.node_ingress_cluster.source_security_group_id == var.test_cluster_sg_id
    error_message = "Nodes should accept traffic from cluster control plane"
  }

  # Assert nodes can communicate with cluster API
  assert {
    condition     = aws_security_group_rule.node_egress_cluster.to_port == 443
    error_message = "Nodes should be able to communicate with cluster API on port 443"
  }

  # Assert nodes have internet access for updates and image pulls
  assert {
    condition     = aws_security_group_rule.node_egress_internet.cidr_blocks[0] == "0.0.0.0/0"
    error_message = "Nodes need internet access for package updates and container image pulls"
  }
}

# ----------------------------------------------------------------
# ALB ingress rule is conditional
# Expected: ALB can reach pods only when ALB SG provided
# ----------------------------------------------------------------
run "alb_ingress_enabled" {
  command = plan

  variables {
    cluster_name                       = var.test_cluster_name
    node_group_name                    = "test-nodes"
    cluster_version                    = var.test_cluster_version
    cluster_endpoint                   = var.test_cluster_endpoint
    cluster_certificate_authority_data = var.test_cluster_ca
    cluster_security_group_id          = var.test_cluster_sg_id
    vpc_id                             = var.test_vpc_id
    subnet_ids                         = var.test_subnet_ids
    ami_id                             = var.test_ami_id
    alb_security_group_id              = var.test_alb_sg_id
    desired_size                       = 1
    min_size                           = 1
    max_size                           = 1
  }

  # Assert ALB ingress rule is created when ALB SG provided
  assert {
    condition     = length(aws_security_group_rule.node_ingress_alb) == 1
    error_message = "ALB ingress rule should be created when ALB security group provided"
  }

  # Assert rule has correct source security group
  assert {
    condition     = aws_security_group_rule.node_ingress_alb[0].source_security_group_id == var.test_alb_sg_id
    error_message = "ALB ingress rule should reference correct ALB security group"
  }
}

run "alb_ingress_disabled" {
  command = plan

  variables {
    cluster_name                       = var.test_cluster_name
    node_group_name                    = "test-nodes"
    cluster_version                    = var.test_cluster_version
    cluster_endpoint                   = var.test_cluster_endpoint
    cluster_certificate_authority_data = var.test_cluster_ca
    cluster_security_group_id          = var.test_cluster_sg_id
    vpc_id                             = var.test_vpc_id
    subnet_ids                         = var.test_subnet_ids
    ami_id                             = var.test_ami_id
    alb_security_group_id              = ""  # Empty string = no ALB
    desired_size                       = 1
    min_size                           = 1
    max_size                           = 1
  }

  # Assert ALB ingress rule is NOT created when no ALB SG provided
  assert {
    condition     = length(aws_security_group_rule.node_ingress_alb) == 0
    error_message = "ALB ingress rule should not be created when ALB security group not provided"
  }
}

# ----------------------------------------------------------------
# Launch template uses latest version
# Expected: Node group always uses $Latest launch template
# ----------------------------------------------------------------
run "launch_template_versioning" {
  command = plan

  variables {
    cluster_name                       = var.test_cluster_name
    node_group_name                    = "test-nodes"
    cluster_version                    = var.test_cluster_version
    cluster_endpoint                   = var.test_cluster_endpoint
    cluster_certificate_authority_data = var.test_cluster_ca
    cluster_security_group_id          = var.test_cluster_sg_id
    vpc_id                             = var.test_vpc_id
    subnet_ids                         = var.test_subnet_ids
    ami_id                             = var.test_ami_id
    desired_size                       = 1
    min_size                           = 1
    max_size                           = 1
  }

  # Assert node group uses $Latest launch template version
  assert {
    condition     = aws_eks_node_group.this.launch_template[0].version == "$Latest"
    error_message = "Node group must use $Latest launch template version for updates"
  }
}

# ----------------------------------------------------------------
# Naming conventions
# Expected: Resources follow predictable naming pattern
# ----------------------------------------------------------------
run "naming_conventions" {
  command = plan

  variables {
    cluster_name                       = "my-cluster"
    node_group_name                    = "my-nodes"
    cluster_version                    = var.test_cluster_version
    cluster_endpoint                   = var.test_cluster_endpoint
    cluster_certificate_authority_data = var.test_cluster_ca
    cluster_security_group_id          = var.test_cluster_sg_id
    vpc_id                             = var.test_vpc_id
    subnet_ids                         = var.test_subnet_ids
    ami_id                             = var.test_ami_id
    desired_size                       = 1
    min_size                           = 1
    max_size                           = 1
  }

  # Assert IAM role naming
  assert {
    condition     = aws_iam_role.node.name == "my-cluster-my-nodes-role"
    error_message = "IAM role should follow {cluster_name}-{node_group_name}-role pattern"
  }

  # Assert instance profile naming
  assert {
    condition     = aws_iam_instance_profile.node.name == "my-cluster-my-nodes-profile"
    error_message = "Instance profile should follow {cluster_name}-{node_group_name}-profile pattern"
  }

  # Assert security group naming
  assert {
    condition     = aws_security_group.node.name == "my-cluster-my-nodes-sg"
    error_message = "Security group should follow {cluster_name}-{node_group_name}-sg pattern"
  }
}

# ----------------------------------------------------------------
# Disk encryption with custom KMS key
# Expected: EBS volumes use provided KMS key
# ----------------------------------------------------------------
run "disk_encryption_custom_kms" {
  command = plan

  variables {
    cluster_name                       = var.test_cluster_name
    node_group_name                    = "test-nodes"
    cluster_version                    = var.test_cluster_version
    cluster_endpoint                   = var.test_cluster_endpoint
    cluster_certificate_authority_data = var.test_cluster_ca
    cluster_security_group_id          = var.test_cluster_sg_id
    vpc_id                             = var.test_vpc_id
    subnet_ids                         = var.test_subnet_ids
    ami_id                             = var.test_ami_id
    disk_encryption_key_id             = var.test_kms_key_id
    desired_size                       = 1
    min_size                           = 1
    max_size                           = 1
  }

  # Assert custom KMS key is used for disk encryption
  assert {
    condition     = aws_launch_template.node.block_device_mappings[0].ebs[0].kms_key_id == var.test_kms_key_id
    error_message = "Disk encryption should use provided KMS key"
  }
}

# ----------------------------------------------------------------
# Multi-subnet deployment for HA
# Expected: Node group spans all provided subnets
# ----------------------------------------------------------------
run "multi_subnet_deployment" {
  command = plan

  variables {
    cluster_name                       = var.test_cluster_name
    node_group_name                    = "test-nodes"
    cluster_version                    = var.test_cluster_version
    cluster_endpoint                   = var.test_cluster_endpoint
    cluster_certificate_authority_data = var.test_cluster_ca
    cluster_security_group_id          = var.test_cluster_sg_id
    vpc_id                             = var.test_vpc_id
    subnet_ids                         = var.test_subnet_ids
    ami_id                             = var.test_ami_id
    desired_size                       = 3
    min_size                           = 1
    max_size                           = 6
  }

  # Assert all subnets are used
  assert {
    condition     = length(aws_eks_node_group.this.subnet_ids) == 3
    error_message = "Node group should span all provided subnets for high availability"
  }
}

# ----------------------------------------------------------------
# Scaling configuration
# Expected: Min/max/desired sizes are configurable
# ----------------------------------------------------------------
run "scaling_configuration" {
  command = plan

  variables {
    cluster_name                       = var.test_cluster_name
    node_group_name                    = "test-nodes"
    cluster_version                    = var.test_cluster_version
    cluster_endpoint                   = var.test_cluster_endpoint
    cluster_certificate_authority_data = var.test_cluster_ca
    cluster_security_group_id          = var.test_cluster_sg_id
    vpc_id                             = var.test_vpc_id
    subnet_ids                         = var.test_subnet_ids
    ami_id                             = var.test_ami_id
    desired_size                       = 5
    min_size                           = 2
    max_size                           = 10
  }

  # Assert desired size is set correctly
  assert {
    condition     = tonumber(aws_eks_node_group.this.scaling_config[0].desired_size) == 5
    error_message = "Desired size should be configurable"
  }

  # Assert min size is set correctly
  assert {
    condition     = tonumber(aws_eks_node_group.this.scaling_config[0].min_size) == 2
    error_message = "Min size should be configurable"
  }

  # Assert max size is set correctly
  assert {
    condition     = tonumber(aws_eks_node_group.this.scaling_config[0].max_size) == 10
    error_message = "Max size should be configurable"
  }
}

# ----------------------------------------------------------------
# Tag specifications for resources
# Expected: Tags propagate to instances and volumes
# ----------------------------------------------------------------
run "tag_propagation" {
  command = plan

  variables {
    cluster_name                       = var.test_cluster_name
    node_group_name                    = "test-nodes"
    cluster_version                    = var.test_cluster_version
    cluster_endpoint                   = var.test_cluster_endpoint
    cluster_certificate_authority_data = var.test_cluster_ca
    cluster_security_group_id          = var.test_cluster_sg_id
    vpc_id                             = var.test_vpc_id
    subnet_ids                         = var.test_subnet_ids
    ami_id                             = var.test_ami_id
    desired_size                       = 1
    min_size                           = 1
    max_size                           = 1
    tags = {
      Environment = "test"
    }
  }

  # Assert instance tag specification exists
  assert {
    condition = length([
      for spec in aws_launch_template.node.tag_specifications : spec
      if spec.resource_type == "instance"
    ]) == 1
    error_message = "Launch template must include tag specifications for instances"
  }

  # Assert volume tag specification exists
  assert {
    condition = length([
      for spec in aws_launch_template.node.tag_specifications : spec
      if spec.resource_type == "volume"
    ]) == 1
    error_message = "Launch template must include tag specifications for volumes"
  }
}

# ----------------------------------------------------------------
# Kubernetes taints and labels
# Expected: Custom taints and labels applied to nodes
# Note: AWS expects taint effects in uppercase with underscores
#       (NO_SCHEDULE, NO_EXECUTE, PREFER_NO_SCHEDULE)
# Note: taint is a set type, use tolist() to convert before indexing
# ----------------------------------------------------------------
run "kubernetes_taints_labels" {
  command = plan

  variables {
    cluster_name                       = var.test_cluster_name
    node_group_name                    = "test-nodes"
    cluster_version                    = var.test_cluster_version
    cluster_endpoint                   = var.test_cluster_endpoint
    cluster_certificate_authority_data = var.test_cluster_ca
    cluster_security_group_id          = var.test_cluster_sg_id
    vpc_id                             = var.test_vpc_id
    subnet_ids                         = var.test_subnet_ids
    ami_id                             = var.test_ami_id
    desired_size                       = 1
    min_size                           = 1
    max_size                           = 1
    labels = {
      workload-type = "compute"
      team          = "platform"
    }
    taints = [
      {
        key    = "dedicated"
        value  = "gpu"
        effect = "NO_SCHEDULE"  # AWS uses uppercase with underscores
      }
    ]
  }

  # Assert labels are set
  assert {
    condition     = aws_eks_node_group.this.labels["workload-type"] == "compute"
    error_message = "Kubernetes labels should be configurable"
  }

  # Assert taints are configured (taint is a set, so check length)
  assert {
    condition     = length(aws_eks_node_group.this.taint) == 1
    error_message = "Kubernetes taints should be configurable"
  }

  # Assert taint key is correct (convert set to list to access)
  assert {
    condition     = tolist(aws_eks_node_group.this.taint)[0].key == "dedicated"
    error_message = "Taint key should be configurable"
  }

  # Assert taint value is correct
  assert {
    condition     = tolist(aws_eks_node_group.this.taint)[0].value == "gpu"
    error_message = "Taint value should be configurable"
  }

  # Assert taint effect is correct (AWS format)
  assert {
    condition     = tolist(aws_eks_node_group.this.taint)[0].effect == "NO_SCHEDULE"
    error_message = "Taint effect should be in AWS format (NO_SCHEDULE)"
  }
}

# ----------------------------------------------------------------
# Instance metadata tags enabled
# Expected: Instance metadata tags are enabled for pods
# ----------------------------------------------------------------
run "instance_metadata_tags" {
  command = plan

  variables {
    cluster_name                       = var.test_cluster_name
    node_group_name                    = "test-nodes"
    cluster_version                    = var.test_cluster_version
    cluster_endpoint                   = var.test_cluster_endpoint
    cluster_certificate_authority_data = var.test_cluster_ca
    cluster_security_group_id          = var.test_cluster_sg_id
    vpc_id                             = var.test_vpc_id
    subnet_ids                         = var.test_subnet_ids
    ami_id                             = var.test_ami_id
    desired_size                       = 1
    min_size                           = 1
    max_size                           = 1
  }

  # Assert instance metadata tags are enabled
  assert {
    condition     = aws_launch_template.node.metadata_options[0].instance_metadata_tags == "enabled"
    error_message = "Instance metadata tags should be enabled for pods to access"
  }
}
