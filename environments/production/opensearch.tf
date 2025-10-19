# =============================================================================
# OPENSEARCH (Elasticsearch)
# =============================================================================

module "opensearch" {
  source = "../../modules/opensearch"

  domain_name    = "${var.environment}-search"
  engine_version = "OpenSearch_2.11"

  instance_type  = "t3.medium.search"
  instance_count = 3 # One per AZ

  dedicated_master_enabled = true
  dedicated_master_type    = "t3.small.search"
  dedicated_master_count   = 3

  zone_awareness_enabled  = true
  availability_zone_count = 3

  ebs_enabled     = true
  ebs_volume_type = "gp3"
  ebs_volume_size = 100

  subnet_ids         = module.networking.private_data_subnet_ids
  security_group_ids = [module.security_groups["elasticsearch"].security_group_id]

  encrypt_at_rest_enabled         = true
  kms_key_id                      = var.kms_key_id
  node_to_node_encryption_enabled = true

  enforce_https       = true
  tls_security_policy = "Policy-Min-TLS-1-2-2019-07"

  advanced_security_options_enabled = true
  internal_user_database_enabled    = true
  master_user_name                  = "admin"
  master_user_password              = data.aws_ssm_parameter.opensearch_master_password.value

  automated_snapshot_start_hour = 3

  tags = {
    Environment = var.environment
  }
}
