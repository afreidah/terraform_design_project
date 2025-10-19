# environments/production/main.tf

# =============================================================================
# NETWORKING
# =============================================================================

module "networking" {
  source = "../../modules/general-networking"

  vpc_cidr                  = var.vpc_cidr
  vpc_name                  = var.environment
  availability_zones        = var.availability_zones
  public_subnet_cidrs       = var.public_subnet_cidrs
  private_app_subnet_cidrs  = var.private_app_subnet_cidrs
  private_data_subnet_cidrs = var.private_data_subnet_cidrs

  tags = {
    Environment = var.environment
  }
}

# =============================================================================
# SECURITY GROUPS
# =============================================================================

module "security_groups" {
  source   = "../../modules/security-group"
  for_each = local.security_groups

  vpc_id        = module.networking.vpc_id
  name          = "${var.environment}-${each.key}-sg"
  description   = each.value.description
  ingress_rules = each.value.ingress_rules
  egress_rules  = each.value.egress_rules

  tags = {
    Environment = var.environment
    Purpose     = each.key
  }
}

# =============================================================================
# IAM ROLES
# =============================================================================

# EC2 Assume Role Policy
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# IAM Policy for Parameter Store access
data "aws_iam_policy_document" "parameter_store_access" {
  statement {
    sid    = "AllowParameterStoreRead"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:${var.region}:*:parameter/${var.environment}/*"
    ]
  }

  statement {
    sid    = "AllowKMSDecrypt"
    effect = "Allow"
    actions = [
      "kms:Decrypt"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${var.region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "parameter_store_access" {
  name        = "${var.environment}-parameter-store-access"
  description = "Allow reading parameters from Parameter Store"
  policy      = data.aws_iam_policy_document.parameter_store_access.json
}

# EC2 IAM Role
module "ec2_iam_role" {
  source = "../../modules/iam-role"

  name                    = "${var.environment}-ec2-app-role"
  assume_role_policy      = data.aws_iam_policy_document.ec2_assume_role.json
  create_instance_profile = true

  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    aws_iam_policy.parameter_store_access.arn
  ]

  tags = {
    Environment = var.environment
  }
}

# =============================================================================
# WAF
# =============================================================================

module "waf" {
  source = "../../modules/waf"

  name  = "${var.environment}-public-alb-waf"
  scope = "REGIONAL"

  default_action = "allow"

  enable_aws_managed_rules = true
  enable_rate_limiting     = true
  rate_limit               = 2000 # 2000 requests per 5 minutes per IP
  enable_ip_reputation     = true

  # Optional: Enable geo blocking
  # enable_geo_blocking = true
  # blocked_countries   = ["CN", "RU"]  # Example: block China and Russia

  cloudwatch_metrics_enabled = true
  sampled_requests_enabled   = true

  tags = {
    Environment = var.environment
  }
}

# =============================================================================
# LOAD BALANCERS
# =============================================================================

# Public-facing ALB
module "alb_public" {
  source = "../../modules/alb"

  name               = "${var.environment}-public-alb"
  internal           = false
  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.public_subnet_ids
  security_group_ids = [module.security_groups["alb_public"].security_group_id]

  # Certificate ARN for HTTPS (optional - uncomment when you have a cert in ACM)
  # certificate_arn = var.ssl_certificate_arn

  # Attach WAF
  enable_waf  = true
  waf_acl_arn = module.waf.web_acl_arn

  target_groups = {
    ec2 = {
      port        = 8080
      protocol    = "HTTP"
      target_type = "instance"
      health_check = {
        enabled             = true
        healthy_threshold   = 3
        interval            = 30
        matcher             = "200"
        path                = "/health"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 3
      }
    }
  }

  tags = {
    Environment = var.environment
    Type        = "public"
  }
}

# Internal ALB
module "alb_internal" {
  source = "../../modules/alb"

  name               = "${var.environment}-internal-alb"
  internal           = true
  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.private_app_subnet_ids
  security_group_ids = [module.security_groups["alb_internal"].security_group_id]

  target_groups = {
    ec2 = {
      port        = 8080
      protocol    = "HTTP"
      target_type = "instance"
      health_check = {
        enabled             = true
        healthy_threshold   = 3
        interval            = 30
        matcher             = "200"
        path                = "/health"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 3
      }
    }
  }

  tags = {
    Environment = var.environment
    Type        = "internal"
  }
}

# =============================================================================
# EC2 INSTANCES
# =============================================================================

module "ec2_app" {
  source = "../../modules/ec2"

  name                 = "${var.environment}-app"
  ami_id               = var.ec2_ami_id
  instance_type        = var.ec2_instance_type
  subnet_ids           = module.networking.private_app_subnet_ids
  security_group_ids   = [module.security_groups["ec2_app"].security_group_id]
  iam_instance_profile = module.ec2_iam_role.instance_profile_name

  desired_capacity = 2
  min_size         = 1
  max_size         = 4

  # Attach to ALB target groups
  target_group_arns = [
    module.alb_public.target_group_arns["ec2"],
    module.alb_internal.target_group_arns["ec2"]
  ]

  tags = {
    Environment = var.environment
    Purpose     = "application"
  }
}

# =============================================================================
# PARAMETER STORE (Secrets Management)
# =============================================================================

module "parameter_store" {
  source = "../../modules/parameter-store"

  parameters = {
    "/${var.environment}/database/master_username" = {
      description = "RDS master username"
      type        = "SecureString"
      value       = "dbadmin"
    }
    "/${var.environment}/database/master_password" = {
      description = "RDS master password"
      type        = "SecureString"
      value       = "ChangeMe123!"
    }
    "/${var.environment}/redis/auth_token" = {
      description = "Redis AUTH token"
      type        = "SecureString"
      value       = "MyRedisAuthToken1234567890!" # Must be 16-128 alphanumeric
    }
    "/${var.environment}/opensearch/master_password" = {
      description = "OpenSearch master password"
      type        = "SecureString"
      value       = "OpenSearch123!" # Must meet complexity requirements
    }
    "/${var.environment}/app/api_key" = {
      description = "Application API key"
      type        = "SecureString"
      value       = "your-api-key-here"
    }
    "/${var.environment}/app/encryption_key" = {
      description = "Application encryption key"
      type        = "SecureString"
      value       = "your-encryption-key-here"
    }
  }

  tags = {
    Environment = var.environment
  }
}

# =============================================================================
# DATA SOURCES (for reading Parameter Store values)
# =============================================================================

data "aws_ssm_parameter" "db_username" {
  name = "/${var.environment}/database/master_username"

  depends_on = [module.parameter_store]
}

data "aws_ssm_parameter" "db_password" {
  name            = "/${var.environment}/database/master_password"
  with_decryption = true

  depends_on = [module.parameter_store]
}

data "aws_ssm_parameter" "redis_auth_token" {
  name            = "/${var.environment}/redis/auth_token"
  with_decryption = true

  depends_on = [module.parameter_store]
}

data "aws_ssm_parameter" "opensearch_master_password" {
  name            = "/${var.environment}/opensearch/master_password"
  with_decryption = true

  depends_on = [module.parameter_store]
}

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

# =============================================================================
# MSK (Managed Kafka)
# =============================================================================

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
