# -----------------------------------------------------------------------------
# MANAGED STREAMING FOR APACHE KAFKA (MSK)
# -----------------------------------------------------------------------------
#
# This file defines an MSK Kafka cluster for event streaming and message queuing.
#
# Architecture:
#   - Kafka Version: 3.5.1 (AWS managed version)
#   - Brokers: 3 brokers (1 per AZ) for high availability
#   - Instance Type: kafka.t3.small (2 vCPU, 4 GiB RAM per broker)
#   - Storage: 100 GB EBS per broker (auto-expandable)
#   - Network: Private data subnets (no direct internet access)
#
# Topology:
#   - Broker Distribution: One broker per availability zone
#   - Zookeeper: 3-node Zookeeper ensemble (AWS managed)
#   - Replication: Configurable replication factor (recommend 3 for HA)
#   - Partitions: Distributed across brokers for parallelism
#
# Security:
#   - Encryption in Transit (Client-Broker): TLS only (no plaintext)
#   - Encryption in Transit (Inter-Broker): TLS for replication
#   - Encryption at Rest: KMS encryption for EBS volumes
#   - Network: Security group allows VPC access only on ports 9092/9094
#
# Monitoring:
#   - Enhanced Monitoring: PER_BROKER granularity for detailed metrics
#   - CloudWatch Logs: Enabled for broker logs
#   - Metrics: Broker, topic, and partition metrics in CloudWatch
#
# IMPORTANT:
#   - MSK requires egress rules for inter-broker communication (see security_groups.tf)
#   - Brokers use private DNS names for bootstrap servers
#   - Zookeeper managed by AWS (automatic failover and patching)
#   - Port 2181 required for Zookeeper coordination
#   - Port 9092 for plaintext, 9094 for TLS client connections
# -----------------------------------------------------------------------------

module "msk" {
  source = "../../modules/msk"

  # -------------------------------------------------------------------------
  # CLUSTER IDENTIFICATION
  # -------------------------------------------------------------------------
  cluster_name           = "${var.environment}-kafka"
  kafka_version          = "3.5.1" # AWS managed Kafka version
  number_of_broker_nodes = 3       # One per AZ for high availability

  # -------------------------------------------------------------------------
  # COMPUTE & STORAGE
  # -------------------------------------------------------------------------
  broker_node_instance_type   = "kafka.t3.small" # 2 vCPU, 4 GiB RAM
  broker_node_ebs_volume_size = 100              # GB per broker

  # -------------------------------------------------------------------------
  # NETWORK CONFIGURATION
  # -------------------------------------------------------------------------
  subnet_ids         = module.networking.private_data_subnet_ids
  security_group_ids = [module.security_groups["msk"].security_group_id]

  # -------------------------------------------------------------------------
  # ENCRYPTION
  # -------------------------------------------------------------------------
  # In-transit encryption (TLS) required for both client and inter-broker
  encryption_in_transit_client_broker = "TLS"          # Client connections must use TLS
  encryption_in_transit_in_cluster    = true           # Inter-broker replication uses TLS
  encryption_at_rest_kms_key_arn      = var.kms_key_id # KMS encryption for EBS

  # -------------------------------------------------------------------------
  # MONITORING
  # -------------------------------------------------------------------------
  enhanced_monitoring     = "PER_BROKER" # Detailed broker-level metrics
  cloudwatch_logs_enabled = true         # Send broker logs to CloudWatch

  tags = {
    Environment = var.environment
  }
}
