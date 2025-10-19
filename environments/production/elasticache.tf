# =============================================================================
# ELASTICACHE (Redis)
# =============================================================================

module "elasticache" {
  source = "../../modules/elasticache"

  cluster_id             = "${var.environment}-redis"
  engine                 = "redis"
  engine_version         = "7.0"
  node_type              = "cache.t3.medium"
  num_cache_nodes        = 3 # One per AZ
  parameter_group_family = "redis7"

  subnet_ids         = module.networking.private_data_subnet_ids
  security_group_ids = [module.security_groups["elasticache"].security_group_id]

  automatic_failover_enabled = true
  multi_az_enabled           = true

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token_enabled         = true
  auth_token                 = data.aws_ssm_parameter.redis_auth_token.value
  kms_key_id                 = var.kms_key_id

  snapshot_retention_limit = 7
  snapshot_window          = "03:00-05:00"
  maintenance_window       = "sun:05:00-sun:07:00"

  tags = {
    Environment = var.environment
  }
}
