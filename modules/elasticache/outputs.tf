# -----------------------------------------------------------------------------
# ELASTICACHE REDIS MODULE - OUTPUT VALUES
# -----------------------------------------------------------------------------
#
# This file exposes attributes of the created ElastiCache Redis replication
# group for use by parent modules, application configuration, and monitoring
# systems.
#
# Output Categories:
#   - Replication Group: Cluster identifiers for management
#   - Endpoints: Connection strings for application configuration
#   - Member Clusters: Individual cache node identifiers
#
# Usage:
#   - primary_endpoint_address: Write operations and read-after-write consistency
#   - reader_endpoint_address: Read operations distributed across replicas
#   - configuration_endpoint_address: Cluster mode configuration endpoint
#   - member_clusters: Individual node management and monitoring
#   - replication_group_arn: CloudWatch alarms and resource policies
#
# Connection Patterns:
#   - Non-cluster mode: Use primary_endpoint for writes, reader_endpoint for reads
#   - Cluster mode: Use configuration_endpoint for cluster-aware clients
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# REPLICATION GROUP OUTPUTS
# -----------------------------------------------------------------------------

output "replication_group_id" {
  description = "ID of the replication group"
  value       = aws_elasticache_replication_group.this.id
}

output "replication_group_arn" {
  description = "ARN of the replication group"
  value       = aws_elasticache_replication_group.this.arn
}

# -----------------------------------------------------------------------------
# ENDPOINT OUTPUTS
# -----------------------------------------------------------------------------

output "primary_endpoint_address" {
  description = "Address of the primary endpoint"
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "reader_endpoint_address" {
  description = "Address of the reader endpoint"
  value       = aws_elasticache_replication_group.this.reader_endpoint_address
}

output "configuration_endpoint_address" {
  description = "Address of the configuration endpoint"
  value       = aws_elasticache_replication_group.this.configuration_endpoint_address
}

# -----------------------------------------------------------------------------
# MEMBER CLUSTER OUTPUTS
# -----------------------------------------------------------------------------

output "member_clusters" {
  description = "List of member cluster IDs"
  value       = aws_elasticache_replication_group.this.member_clusters
}
