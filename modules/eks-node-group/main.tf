# -----------------------------------------------------------------------------
# EKS NODE GROUP MODULE
# -----------------------------------------------------------------------------
#
# This module creates an EKS Managed Node Group with Launch Template for
# running Kubernetes workloads. It provides worker nodes that join the EKS
# cluster with proper security hardening, IAM permissions, and network
# configuration.
#
# Components Created:
#   - EKS Managed Node Group: Self-healing worker nodes for Kubernetes
#   - IAM Role & Instance Profile: Permissions for nodes to join cluster
#   - Security Group: Network access control for pod networking
#   - Launch Template: Node configuration with security best practices
#
# Features:
#   - Auto Scaling: Dynamic node scaling based on min/max/desired capacity
#   - EKS-Optimized AMI: Automatically retrieves latest AMI via SSM Parameter
#   - IMDSv2 Enforcement: Enhanced metadata security for pods
#   - EBS Encryption: Encrypted volumes with optional KMS key
#   - SSM Session Manager: Optional secure shell access without SSH keys
#   - CloudWatch Monitoring: Optional detailed instance monitoring
#   - Taints & Labels: Kubernetes scheduling controls
#   - Rolling Updates: Controlled node replacement during updates
#
# Security Model:
#   - IMDSv2 Required: Prevents SSRF attacks on instance metadata
#   - EBS Encryption: All node volumes encrypted at rest
#   - Minimal IAM Permissions: Only required EKS and ECR access
#   - Pod Security Groups: Support for security groups per pod
#   - Network Isolation: Security group rules limit blast radius
#
# IMPORTANT:
#   - Launch template uses name_prefix for blue-green deployments
#   - Node group ignores desired_size changes to prevent drift
#   - IMDSv2 hop limit set to 2 for pod access to instance metadata
#   - Custom AMI optional; defaults to latest EKS-optimized AMI
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# EKS-OPTIMIZED AMI LOOKUP
# -----------------------------------------------------------------------------

# Retrieve latest EKS-optimized Amazon Linux 2 AMI from SSM Parameter Store
# Only used when custom ami_id is not provided
data "aws_ssm_parameter" "eks_ami" {
  count = var.ami_id == null ? 1 : 0

  name = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2/recommended/image_id"
}

# -----------------------------------------------------------------------------
# NODE IAM ROLE
# -----------------------------------------------------------------------------

# IAM role for EKS worker nodes
# Allows EC2 instances to assume role and join EKS cluster
resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-${var.node_group_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# -------------------------------------------------------------------------
# REQUIRED NODE IAM POLICY ATTACHMENTS
# -------------------------------------------------------------------------

# Core EKS worker node policy for cluster operations
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

# VPC CNI policy for pod networking (may be moved to IRSA in production)
resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

# ECR read-only access for pulling container images
resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

# -------------------------------------------------------------------------
# OPTIONAL NODE IAM POLICY ATTACHMENTS
# -------------------------------------------------------------------------

# SSM Session Manager for secure shell access without SSH keys
resource "aws_iam_role_policy_attachment" "node_AmazonSSMManagedInstanceCore" {
  for_each = var.enable_ssm_access ? toset(["enabled"]) : toset([])

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.node.name
}

# CloudWatch agent for custom metrics and log collection
resource "aws_iam_role_policy_attachment" "node_CloudWatchAgentServerPolicy" {
  for_each = var.enable_cloudwatch_agent ? toset(["enabled"]) : toset([])

  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.node.name
}

# -----------------------------------------------------------------------------
# IAM INSTANCE PROFILE
# -----------------------------------------------------------------------------

# Instance profile for attaching IAM role to EC2 instances
resource "aws_iam_instance_profile" "node" {
  name = "${var.cluster_name}-${var.node_group_name}-profile"
  role = aws_iam_role.node.name

  tags = var.tags
}

# -----------------------------------------------------------------------------
# NODE SECURITY GROUP
# -----------------------------------------------------------------------------

# Security group for EKS worker nodes
# Controls network access for pod-to-pod and cluster communication
resource "aws_security_group" "node" {
  name        = "${var.cluster_name}-${var.node_group_name}-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name                                        = "${var.cluster_name}-${var.node_group_name}-sg"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
}

# -------------------------------------------------------------------------
# NODE INGRESS RULES
# -------------------------------------------------------------------------

# Allow nodes to communicate with each other for pod networking
resource "aws_security_group_rule" "node_ingress_self" {
  description       = "Allow nodes to communicate with each other"
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  security_group_id = aws_security_group.node.id
  self              = true
}

# Allow nodes to receive communication from cluster control plane
# Required for kubelet and pod communication
resource "aws_security_group_rule" "node_ingress_cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from cluster control plane"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = var.cluster_security_group_id
}

# Allow nodes to receive HTTPS from control plane for webhook servers
# Required for admission controllers and extension API servers
resource "aws_security_group_rule" "node_ingress_cluster_https" {
  description              = "Allow pods running extension API servers to receive communication from cluster control plane"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = var.cluster_security_group_id
}

# Allow ALB to reach pods directly (when using AWS Load Balancer Controller)
resource "aws_security_group_rule" "node_ingress_alb" {
  count = var.alb_security_group_id != "" ? 1 : 0

  description              = "Allow ALB to reach pods"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = var.alb_security_group_id
}

# -------------------------------------------------------------------------
# NODE EGRESS RULES
# -------------------------------------------------------------------------

# Allow nodes to communicate with cluster API server
resource "aws_security_group_rule" "node_egress_cluster" {
  description              = "Allow nodes to communicate with the cluster API server"
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = var.cluster_security_group_id
}

# Allow nodes internet access for pulling images, updates, and AWS APIs
resource "aws_security_group_rule" "node_egress_internet" {
  description       = "Allow nodes to communicate with internet"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.node.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# -----------------------------------------------------------------------------
# LAUNCH TEMPLATE
# -----------------------------------------------------------------------------

# Launch template for EKS node group instances
# Defines instance configuration with security hardening
resource "aws_launch_template" "node" {
  name_prefix = "${var.cluster_name}-${var.node_group_name}-"
  description = "Launch template for EKS node group ${var.node_group_name}"

  image_id      = var.ami_id != null ? var.ami_id : one(data.aws_ssm_parameter.eks_ami[*].value)
  instance_type = var.instance_types[0] # Default instance type

  # -------------------------------------------------------------------------
  # NETWORK CONFIGURATION
  # -------------------------------------------------------------------------
  # Attach node security group and any additional security groups
  vpc_security_group_ids = concat(
    [aws_security_group.node.id],
    var.additional_security_group_ids
  )

  # -------------------------------------------------------------------------
  # IAM INSTANCE PROFILE
  # -------------------------------------------------------------------------
  # Grants nodes permissions to join cluster and access AWS services
  iam_instance_profile {
    arn = aws_iam_instance_profile.node.arn
  }

  # -------------------------------------------------------------------------
  # ROOT VOLUME CONFIGURATION
  # -------------------------------------------------------------------------
  # EBS volume with encryption for container storage
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.disk_size
      volume_type           = var.disk_type
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = var.disk_encryption_key_id
    }
  }

  # -------------------------------------------------------------------------
  # INSTANCE METADATA SERVICE (IMDSv2)
  # -------------------------------------------------------------------------
  # Enforces IMDSv2 with hop limit 2 for pod access to instance metadata
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2 # Required for pods to access IMDS
    instance_metadata_tags      = "enabled"
  }

  # -------------------------------------------------------------------------
  # MONITORING
  # -------------------------------------------------------------------------
  # Optional detailed CloudWatch monitoring (1-minute intervals)
  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  # -------------------------------------------------------------------------
  # USER DATA BOOTSTRAP SCRIPT
  # -------------------------------------------------------------------------
  # Configures node to join EKS cluster with custom bootstrap arguments
  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    cluster_name        = var.cluster_name
    cluster_endpoint    = var.cluster_endpoint
    cluster_ca          = var.cluster_certificate_authority_data
    bootstrap_arguments = var.bootstrap_extra_args
  }))

  # -------------------------------------------------------------------------
  # INSTANCE TAGGING
  # -------------------------------------------------------------------------
  # Tags applied to launched instances
  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.tags,
      {
        Name = "${var.cluster_name}-${var.node_group_name}"
      }
    )
  }

  # -------------------------------------------------------------------------
  # VOLUME TAGGING
  # -------------------------------------------------------------------------
  # Tags applied to EBS volumes
  tag_specifications {
    resource_type = "volume"
    tags = merge(
      var.tags,
      {
        Name = "${var.cluster_name}-${var.node_group_name}-volume"
      }
    )
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# EKS MANAGED NODE GROUP
# -----------------------------------------------------------------------------

# EKS managed node group for running Kubernetes workloads
# Provides self-healing worker nodes with automated updates
resource "aws_eks_node_group" "this" {
  cluster_name    = var.cluster_name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  version         = var.cluster_version

  # -------------------------------------------------------------------------
  # SCALING CONFIGURATION
  # -------------------------------------------------------------------------
  # Auto Scaling Group sizing for the node group
  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  # -------------------------------------------------------------------------
  # UPDATE CONFIGURATION
  # -------------------------------------------------------------------------
  # Control how many nodes can be unavailable during updates
  update_config {
    max_unavailable_percentage = var.max_unavailable_percentage
  }

  # -------------------------------------------------------------------------
  # LAUNCH TEMPLATE
  # -------------------------------------------------------------------------
  # Use custom launch template for additional configuration
  launch_template {
    id      = aws_launch_template.node.id
    version = "$Latest"
  }

  # -------------------------------------------------------------------------
  # INSTANCE CONFIGURATION
  # -------------------------------------------------------------------------
  instance_types = var.instance_types
  capacity_type  = var.capacity_type

  # -------------------------------------------------------------------------
  # KUBERNETES LABELS
  # -------------------------------------------------------------------------
  # Custom labels for pod scheduling and node selection
  labels = var.labels

  # -------------------------------------------------------------------------
  # KUBERNETES TAINTS
  # -------------------------------------------------------------------------
  # Taints for controlling which pods can schedule on these nodes
  dynamic "taint" {
    for_each = var.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-${var.node_group_name}"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }
}
