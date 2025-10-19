# =============================================================================
# RDS DATABASE
# =============================================================================

module "rds" {
  source = "../../modules/rds"

  identifier     = "${var.environment}-postgres"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.medium"

  allocated_storage     = 100
  max_allocated_storage = 500
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "appdb"
  username = data.aws_ssm_parameter.db_username.value
  password = data.aws_ssm_parameter.db_password.value
  port     = 5432

  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.private_data_subnet_ids
  security_group_ids = [module.security_groups["rds"].security_group_id]

  multi_az            = true
  publicly_accessible = false

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  deletion_protection = var.environment == "production" ? true : false
  skip_final_snapshot = var.environment != "production"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  performance_insights_kms_key_id       = var.kms_key_id

  iam_database_authentication_enabled = true

  tags = {
    Environment = var.environment
  }
}
