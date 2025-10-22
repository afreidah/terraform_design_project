# -----------------------------------------------------------------------------
# MSK MODULE - INPUT VARIABLES
# -----------------------------------------------------------------------------
#
# This file defines all configurable parameters for the Amazon MSK cluster
# module, including cluster configuration, broker sizing, networking,
# encryption, monitoring, and logging settings.
#
# Variable Categories:
#   - Core Configuration: Cluster name, Kafka version, broker count
#   - Broker Configuration: Instance type and EBS volume sizing
#   - Network Configuration: Subnets and security groups
#   - Encryption Configuration: At-rest and in-transit encryption
#   - Monitoring Configuration: Enhanced monitoring levels
#   - Logging Configuration: CloudWatch and S3 log delivery
#   - Tagging: Resource tags for organization
#
# Important Notes:
#   - number_of_broker_nodes must be multiple of AZ count
#   - Minimum 3 brokers recommended for production (one per AZ)
#   - Encryption in transit options: TLS, TLS_PLAINTEXT, PLAINTEXT
#   - Enhanced monitoring levels: DEFAULT, PER_BROKER, PER_TOPIC_PER_BROKER,
#     PER_TOPIC_PER_PARTITION
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# CORE CONFIGURATION
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the MSK cluster"
  type        = string
}

variable "kafka_version" {
  description = "Kafka version"
  type        = string
  default     = "3.5.1"
}

variable "number_of_broker_nodes" {
  description = "Number of broker nodes (must be multiple of AZs)"
  type        = number
  default     = 3
}

# -----------------------------------------------------------------------------
# BROKER CONFIGURATION
# -----------------------------------------------------------------------------

variable "broker_node_instance_type" {
  description = "Instance type for broker nodes"
  type        = string
  default     = "kafka.t3.small"
}

variable "broker_node_ebs_volume_size" {
  description = "EBS volume size for broker nodes in GB"
  type        = number
  default     = 100
}

# -----------------------------------------------------------------------------
# NETWORK CONFIGURATION
# -----------------------------------------------------------------------------

variable "subnet_ids" {
  description = "List of subnet IDs for broker nodes"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

# -----------------------------------------------------------------------------
# ENCRYPTION CONFIGURATION
# -----------------------------------------------------------------------------

variable "encryption_in_transit_client_broker" {
  description = "Encryption setting for client-broker communication (TLS, TLS_PLAINTEXT, PLAINTEXT)"
  type        = string
  default     = "TLS"
}

variable "encryption_in_transit_in_cluster" {
  description = "Enable encryption in transit within cluster"
  type        = bool
  default     = true
}

variable "encryption_at_rest_kms_key_arn" {
  description = "KMS key ARN for encryption at rest"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# MONITORING CONFIGURATION
# -----------------------------------------------------------------------------

variable "enhanced_monitoring" {
  description = "Enhanced monitoring level (DEFAULT, PER_BROKER, PER_TOPIC_PER_BROKER, PER_TOPIC_PER_PARTITION)"
  type        = string
  default     = "PER_BROKER"
}

# -----------------------------------------------------------------------------
# CLOUDWATCH LOGGING CONFIGURATION
# -----------------------------------------------------------------------------

variable "cloudwatch_logs_enabled" {
  description = "Enable CloudWatch logs"
  type        = bool
  default     = true
}

variable "cloudwatch_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 365
}

variable "cloudwatch_kms_key_id" {
  description = "KMS key ID for CloudWatch Logs encryption"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# S3 LOGGING CONFIGURATION
# -----------------------------------------------------------------------------

variable "s3_logs_enabled" {
  description = "Enable S3 logs"
  type        = bool
  default     = false
}

variable "s3_logs_bucket" {
  description = "S3 bucket for logs"
  type        = string
  default     = null
}

variable "s3_logs_prefix" {
  description = "S3 prefix for logs"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# TAGGING
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
