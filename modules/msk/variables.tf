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

variable "subnet_ids" {
  description = "List of subnet IDs for broker nodes"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

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

variable "enhanced_monitoring" {
  description = "Enhanced monitoring level (DEFAULT, PER_BROKER, PER_TOPIC_PER_BROKER, PER_TOPIC_PER_PARTITION)"
  type        = string
  default     = "PER_BROKER"
}

variable "cloudwatch_logs_enabled" {
  description = "Enable CloudWatch logs"
  type        = bool
  default     = true
}

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

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
