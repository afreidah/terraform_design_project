# -----------------------------------------------------------------------------
# MSK (Managed Kafka)
# -----------------------------------------------------------------------------

module "msk" {
  source = "../../modules/msk"

  cluster_name           = "${var.environment}-kafka"
  kafka_version          = "3.5.1"
  number_of_broker_nodes = 3 # One per AZ

  broker_node_instance_type   = "kafka.t3.small"
  broker_node_ebs_volume_size = 100

  subnet_ids         = module.networking.private_data_subnet_ids
  security_group_ids = [module.security_groups["msk"].security_group_id]

  encryption_in_transit_client_broker = "TLS"
  encryption_in_transit_in_cluster    = true
  encryption_at_rest_kms_key_arn      = var.kms_key_id

  enhanced_monitoring     = "PER_BROKER"
  cloudwatch_logs_enabled = true

  tags = {
    Environment = var.environment
  }
}
