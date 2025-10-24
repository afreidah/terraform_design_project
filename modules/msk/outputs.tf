# -----------------------------------------------------------------------------
# MSK MODULE - OUTPUT VALUES
# -----------------------------------------------------------------------------
#
# This file exposes attributes of the created MSK cluster for use by parent
# modules, Kafka clients, and monitoring systems.
#
# Output Categories:
#   - Cluster Attributes: Identifiers and versioning
#   - Connection Endpoints: Bootstrap broker addresses for clients
#   - Zookeeper: Cluster coordination endpoint
#
# Usage:
#   - bootstrap_brokers: Plaintext connection for clients (port 9092)
#   - bootstrap_brokers_tls: TLS connection for encrypted clients (port 9094)
#   - zookeeper_connect_string: For administrative tools and monitoring
#   - cluster_arn: For IAM policies and resource tagging
#   - current_version: For cluster update operations
#
# Connection Examples:
#   - Kafka Producer: Use bootstrap_brokers_tls for secure production
#   - Kafka Consumer: Use bootstrap_brokers_tls with SSL configuration
#   - Schema Registry: Use bootstrap_brokers_tls for secure connectivity
#   - Kafka Connect: Configure with bootstrap_brokers_tls endpoint
#
# Note:
#   - Bootstrap endpoints include multiple broker addresses
#   - TLS endpoints require proper SSL/TLS client configuration
#   - Zookeeper endpoint should only be used for administrative tasks
#   - current_version required for in-place cluster updates
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# CLUSTER ATTRIBUTES
# -----------------------------------------------------------------------------

output "cluster_arn" {
  description = "ARN of the MSK cluster"
  value       = aws_msk_cluster.this.arn
}

output "cluster_name" {
  description = "Name of the MSK cluster"
  value       = aws_msk_cluster.this.cluster_name
}

output "current_version" {
  description = "Current version of the MSK cluster"
  value       = aws_msk_cluster.this.current_version
}

# -----------------------------------------------------------------------------
# CONNECTION ENDPOINTS
# -----------------------------------------------------------------------------

output "bootstrap_brokers" {
  description = "Plaintext connection host:port pairs"
  value       = aws_msk_cluster.this.bootstrap_brokers
}

output "bootstrap_brokers_tls" {
  description = "TLS connection host:port pairs"
  value       = aws_msk_cluster.this.bootstrap_brokers_tls
}

# -----------------------------------------------------------------------------
# ZOOKEEPER ENDPOINT
# -----------------------------------------------------------------------------

output "zookeeper_connect_string" {
  description = "Zookeeper connection string"
  value       = aws_msk_cluster.this.zookeeper_connect_string
}
