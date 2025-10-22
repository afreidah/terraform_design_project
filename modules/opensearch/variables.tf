# -----------------------------------------------------------------------------
# OPENSEARCH MODULE VARIABLES
# -----------------------------------------------------------------------------

variable "domain_name" {
  description = "Name of the OpenSearch domain"
  type        = string
}

variable "engine_version" {
  description = "OpenSearch or Elasticsearch engine version"
  type        = string
  default     = "OpenSearch_2.11"
}

variable "instance_type" {
  description = "Instance type for data nodes"
  type        = string
  default     = "t3.medium.search"
}

variable "instance_count" {
  description = "Number of instances in the cluster"
  type        = number
  default     = 3
}

variable "dedicated_master_enabled" {
  description = "Enable dedicated master nodes"
  type        = bool
  default     = true
}

variable "dedicated_master_type" {
  description = "Instance type for dedicated master nodes"
  type        = string
  default     = "t3.small.search"
}

variable "dedicated_master_count" {
  description = "Number of dedicated master nodes"
  type        = number
  default     = 3
}

variable "zone_awareness_enabled" {
  description = "Enable zone awareness for multi-AZ deployment"
  type        = bool
  default     = true
}

variable "availability_zone_count" {
  description = "Number of availability zones for the domain"
  type        = number
  default     = 3
}

variable "ebs_enabled" {
  description = "Enable EBS volumes for data storage"
  type        = bool
  default     = true
}

variable "volume_type" {
  description = "EBS volume type"
  type        = string
  default     = "gp3"
}

variable "volume_size" {
  description = "EBS volume size in GB"
  type        = number
  default     = 100
}

variable "iops" {
  description = "Baseline IOPS for gp3 volumes"
  type        = number
  default     = 3000
}

variable "throughput" {
  description = "Throughput in MiB/s for gp3 volumes"
  type        = number
  default     = 125
}

variable "encrypt_at_rest_enabled" {
  description = "Enable encryption at rest"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption at rest"
  type        = string
  default     = null
}

variable "node_to_node_encryption_enabled" {
  description = "Enable node-to-node encryption"
  type        = bool
  default     = true
}

variable "domain_endpoint_options" {
  description = "Domain endpoint HTTPS and TLS configuration"
  type = object({
    enforce_https       = bool
    tls_security_policy = string
  })
  default = {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }
}

variable "advanced_security_options" {
  description = "Advanced security options for fine-grained access control"
  type = object({
    enabled                        = bool
    internal_user_database_enabled = bool
    master_user_name               = string
    master_user_password           = string
  })
  default = {
    enabled                        = false
    internal_user_database_enabled = false
    master_user_name               = ""
    master_user_password           = ""
  }
  sensitive = true
}

variable "subnet_ids" {
  description = "List of subnet IDs for the domain"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for the domain"
  type        = list(string)
}

variable "automated_snapshot_start_hour" {
  description = "Hour during which automated snapshots are taken (UTC)"
  type        = number
  default     = 3
}

variable "enable_audit_logs" {
  description = "Enable audit logs"
  type        = bool
  default     = false
}

variable "cloudwatch_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
}

variable "cloudwatch_kms_key_id" {
  description = "KMS key ID for CloudWatch log encryption"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
