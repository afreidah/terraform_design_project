# Elasticache Subnet Group
resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.cluster_id}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_id}-subnet-group"
    }
  )
}

# Elasticache Parameter Group
resource "aws_elasticache_parameter_group" "this" {
  name   = "${var.cluster_id}-params"
  family = var.parameter_group_family

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_id}-params"
    }
  )
}

# Elasticache Replication Group (Redis)
resource "aws_elasticache_replication_group" "this" {
  replication_group_id = var.cluster_id
  description          = "Redis replication group for ${var.cluster_id}"

  engine               = var.engine
  engine_version       = var.engine_version
  node_type            = var.node_type
  num_cache_clusters   = var.num_cache_nodes
  parameter_group_name = aws_elasticache_parameter_group.this.name
  port                 = var.port

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = var.security_group_ids

  automatic_failover_enabled = var.automatic_failover_enabled
  multi_az_enabled           = var.multi_az_enabled

  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  auth_token                 = var.auth_token_enabled ? var.auth_token : null
  kms_key_id                 = var.kms_key_id

  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window          = var.snapshot_window
  maintenance_window       = var.maintenance_window

  notification_topic_arn = var.notification_topic_arn

  apply_immediately          = false
  auto_minor_version_upgrade = true

  tags = merge(
    var.tags,
    {
      Name = var.cluster_id
    }
  )

  lifecycle {
    ignore_changes = [auth_token]
  }
}
