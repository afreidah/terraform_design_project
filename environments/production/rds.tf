# RDS Database Instance
# PostgreSQL database for application data

module "rds" {
  source = "../../modules/rds"

  identifier     = "${var.environment}-postgres-db"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_encrypted     = true

  db_name  = "appdb"
  username = "dbadmin"
  password = random_password.db_password.result

  # Network configuration
  vpc_security_group_ids     = [module.security_groups["rds"].security_group_id]
  db_subnet_group_subnet_ids = module.networking.private_data_subnet_ids

  # Backup configuration
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  # High availability
  multi_az            = true
  publicly_accessible = false

  # Deletion protection
  deletion_protection = true

  # Final snapshot
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.environment}-postgres-final-snapshot"

  # CloudWatch logs
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # IAM authentication
  iam_database_authentication_enabled = true

  tags = {
    Environment = var.environment
    Service     = "database"
    ManagedBy   = "terraform"
  }
}

# REMOVED: random_password and module "parameter_store" - already in parameter_store.tf
