# -----------------------------------------------------------------------------
# REQUIRED VARIABLES
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster (should be private subnets)"
  type        = list(string)
}

variable "cluster_encryption_key_arn" {
  description = "ARN of KMS key for cluster encryption"
  type        = string
}

# -----------------------------------------------------------------------------
# OPTIONAL VARIABLES
# -----------------------------------------------------------------------------

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enabled_cluster_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cloudwatch_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 90
}

variable "cloudwatch_kms_key_id" {
  description = "KMS key ID for CloudWatch log encryption"
  type        = string
  default     = null
}

# Add-on versions
variable "vpc_cni_version" {
  description = "Version of VPC CNI add-on"
  type        = string
  default     = null # Uses latest if not specified
}

variable "coredns_version" {
  description = "Version of CoreDNS add-on"
  type        = string
  default     = null
}

variable "kube_proxy_version" {
  description = "Version of kube-proxy add-on"
  type        = string
  default     = null
}

# Node security group (for cluster-to-node communication)
variable "node_security_group_id" {
  description = "Security group ID for EKS nodes (optional - for cluster-to-node communication)"
  type        = string
  default     = null
}

# AWS Auth ConfigMap
variable "manage_aws_auth_configmap" {
  description = "Whether to manage the aws-auth ConfigMap"
  type        = bool
  default     = true
}

variable "node_iam_role_arn" {
  description = "IAM role ARN for EKS nodes (required if manage_aws_auth_configmap is true)"
  type        = string
  default     = null
}

variable "aws_auth_roles" {
  description = "Additional IAM roles to add to aws-auth ConfigMap"
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable "aws_auth_users" {
  description = "Additional IAM users to add to aws-auth ConfigMap"
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
