# -----------------------------------------------------------------------------
# ELASTICACHE REDIS MODULE - INPUT VARIABLES
# -----------------------------------------------------------------------------
#
# This file defines all configurable parameters for the ElastiCache Redis
# module, including cluster configuration, node sizing, security settings,
# high availability, backup, and notification options.
#
# Variable Categories:
#   - Core Configuration: Cluster ID, engine, version, node type
#   - Network Configuration: Subnets, security groups, port
#   - High Availability: Failover, Multi-AZ settings
#   - Security & Encryption: At-rest, in-transit, AUTH token, KMS
#   - Backup & Maintenance: Snapshots, maintenance windows
#   - Notifications: SNS topic integration
#   - Tagging: Resource tags for organization
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# CORE CONFIGURATION
# -----------------------------------------------------------------------------

variable "cluster_id" {
  description = "ID for the Elasticache cluster"
  type        = string
}

variable "engine" {
  description = "Cache engine (redis or memcached)"
  type        = string
  default     = "redis"
}

variable "engine_version" {
  description = "Cache engine version"
  type        = string
  default     = "7.0"
}

variable "node_type" {
  description = "Node type for cache nodes"
  type        = string
  default     = "cache.t3.medium"
}

variable "num_cache_nodes" {
  description = "Number of cache nodes (for Redis non-cluster mode)"
  type        = number
  default     = 2
}

variable "parameter_group_family" {
  description = "Parameter group family"
  type        = string
  default     = "redis7"
}

# -----------------------------------------------------------------------------
# NETWORK CONFIGURATION
# -----------------------------------------------------------------------------

variable "port" {
  description = "Port for cache cluster"
  type        = number
  default     = 6379
}

variable "subnet_ids" {
  description = "List of subnet IDs for cache subnet group"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

# -----------------------------------------------------------------------------
# HIGH AVAILABILITY CONFIGURATION
# -----------------------------------------------------------------------------

variable "automatic_failover_enabled" {
  description = "Enable automatic failover (requires at least 2 nodes)"
  type        = bool
  default     = true
}

variable "multi_az_enabled" {
  description = "Enable Multi-AZ"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# SECURITY & ENCRYPTION CONFIGURATION
# -----------------------------------------------------------------------------

variable "at_rest_encryption_enabled" {
  description = "Enable encryption at rest"
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "Enable encryption in transit"
  type        = bool
  default     = true
}

variable "auth_token_enabled" {
  description = "Enable Redis AUTH token"
  type        = bool
  default     = true
}

variable "auth_token" {
  description = "Redis AUTH token (must be 16-128 alphanumeric characters)"
  type        = string
  default     = null
  sensitive   = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption at rest"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# BACKUP & MAINTENANCE CONFIGURATION
# -----------------------------------------------------------------------------

variable "snapshot_retention_limit" {
  description = "Number of days to retain snapshots"
  type        = number
  default     = 7
}

variable "snapshot_window" {
  description = "Daily time range for snapshots"
  type        = string
  default     = "03:00-05:00"
}

variable "maintenance_window" {
  description = "Weekly time range for maintenance"
  type        = string
  default     = "sun:05:00-sun:07:00"
}

# -----------------------------------------------------------------------------
# NOTIFICATION CONFIGURATION
# -----------------------------------------------------------------------------

variable "notification_topic_arn" {
  description = "SNS topic ARN for notifications"
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
