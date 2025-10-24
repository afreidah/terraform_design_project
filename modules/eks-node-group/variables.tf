# -----------------------------------------------------------------------------
# EKS NODE GROUP MODULE VARIABLES
# -----------------------------------------------------------------------------
#
# This file defines input variables for the EKS Node Group module,
# including cluster integration, instance configuration, scaling parameters,
# security settings, and Kubernetes-specific options.
#
# Variable Categories:
#   - Required Variables: Essential cluster integration parameters
#   - Instance Configuration: Instance types, capacity, and AMI
#   - Scaling Configuration: Auto Scaling Group sizing
#   - Storage Configuration: EBS volume settings
#   - Security & Access: IAM policies, security groups, monitoring
#   - Network Configuration: Additional security groups, ALB integration
#   - Kubernetes Configuration: Labels, taints, bootstrap arguments
#   - Tagging: Resource tags for organization
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# REQUIRED VARIABLES
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "node_group_name" {
  description = "Name of the node group"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version of the cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for the cluster"
  type        = string
}

variable "cluster_security_group_id" {
  description = "Security group ID of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where nodes will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the node group"
  type        = list(string)
}

# -----------------------------------------------------------------------------
# INSTANCE CONFIGURATION
# -----------------------------------------------------------------------------

variable "instance_types" {
  description = "List of instance types for the node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "capacity_type" {
  description = "Type of capacity (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "ami_id" {
  description = "AMI ID for worker nodes (uses EKS-optimized AMI if not specified)"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# SCALING CONFIGURATION
# -----------------------------------------------------------------------------

variable "desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 10
}

variable "max_unavailable_percentage" {
  description = "Max percentage of nodes unavailable during update"
  type        = number
  default     = 33
}

# -----------------------------------------------------------------------------
# STORAGE CONFIGURATION
# -----------------------------------------------------------------------------

variable "disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 20
}

variable "disk_type" {
  description = "EBS volume type"
  type        = string
  default     = "gp3"
}

variable "disk_encryption_key_id" {
  description = "KMS key ID for EBS encryption"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# SECURITY & ACCESS CONFIGURATION
# -----------------------------------------------------------------------------

variable "enable_ssm_access" {
  description = "Enable SSM Session Manager access to nodes"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_agent" {
  description = "Enable CloudWatch agent on nodes"
  type        = bool
  default     = false
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring (1-minute intervals)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# NETWORK CONFIGURATION
# -----------------------------------------------------------------------------

variable "additional_security_group_ids" {
  description = "Additional security group IDs to attach to nodes"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# KUBERNETES CONFIGURATION
# -----------------------------------------------------------------------------

variable "bootstrap_extra_args" {
  description = "Additional arguments for the bootstrap script"
  type        = string
  default     = ""
}

variable "labels" {
  description = "Key-value map of Kubernetes labels"
  type        = map(string)
  default     = {}
}

variable "taints" {
  description = "List of Kubernetes taints to apply to nodes"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

# -----------------------------------------------------------------------------
# TAGGING
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
