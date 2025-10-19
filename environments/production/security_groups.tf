# -----------------------------------------------------------------------------
# SECURITY GROUPS
# -----------------------------------------------------------------------------

# Security Groups Configuration
module "security_groups" {
  source = "../../modules/security-group"

  for_each = {
    # Public ALB - Needs internet egress to reach target instances
    alb_public = {
      description = "Security group for public-facing ALB"
      ingress_rules = [
        {
          description = "Allow HTTPS from internet"
          from_port   = 443
          to_port     = 443
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        },
        {
          description = "Allow HTTP from internet (redirects to HTTPS)"
          from_port   = 80
          to_port     = 80
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]
      egress_rules = [
        {
          description = "Allow traffic to application instances"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = [var.vpc_cidr] # RESTRICTED to VPC only
        }
      ]
    }

    # Internal ALB - Only VPC traffic
    alb_internal = {
      description = "Security group for internal ALB"
      ingress_rules = [
        {
          description = "Allow HTTPS from VPC"
          from_port   = 443
          to_port     = 443
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
        },
        {
          description = "Allow HTTP from VPC"
          from_port   = 80
          to_port     = 80
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
        }
      ]
      egress_rules = [
        {
          description = "Allow traffic to application instances"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = [var.vpc_cidr] # RESTRICTED to VPC only
        }
      ]
    }

    # EC2 Application instances
    ec2_app = {
      description = "Security group for EC2 application instances"
      ingress_rules = [
        {
          description = "Allow app port from VPC"
          from_port   = 8080
          to_port     = 8080
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
        },
        {
          description = "Allow HTTP from VPC"
          from_port   = 80
          to_port     = 80
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
        }
      ]
      egress_rules = [
        {
          description = "Allow HTTPS for package updates and API calls"
          from_port   = 443
          to_port     = 443
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"] # Needed for yum/apt, AWS APIs
        },
        {
          description = "Allow HTTP for package updates"
          from_port   = 80
          to_port     = 80
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"] # Needed for yum/apt repositories
        },
        {
          description = "Allow PostgreSQL to RDS"
          from_port   = 5432
          to_port     = 5432
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
        },
        {
          description = "Allow Redis to ElastiCache"
          from_port   = 6379
          to_port     = 6379
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
        },
        {
          description = "Allow OpenSearch access"
          from_port   = 443
          to_port     = 443
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
        },
        {
          description = "Allow Kafka access"
          from_port   = 9092
          to_port     = 9092
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
        }
      ]
    }

    # RDS PostgreSQL
    rds = {
      description = "Security group for RDS databases"
      ingress_rules = [
        {
          description = "Allow PostgreSQL from VPC"
          from_port   = 5432
          to_port     = 5432
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
        }
      ]
      egress_rules = [] # RDS doesn't need outbound
    }

    # ElastiCache Redis
    elasticache = {
      description = "Security group for ElastiCache (Redis)"
      ingress_rules = [
        {
          description = "Allow Redis from VPC"
          from_port   = 6379
          to_port     = 6379
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
        }
      ]
      egress_rules = [] # Redis doesn't need outbound
    }

    # OpenSearch
    elasticsearch = {
      description = "Security group for OpenSearch"
      ingress_rules = [
        {
          description = "Allow HTTPS from VPC"
          from_port   = 443
          to_port     = 443
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
        }
      ]
      egress_rules = [] # OpenSearch doesn't need outbound
    }

    # MSK Kafka
    msk = {
      description = "Security group for MSK (Kafka)"
      ingress_rules = [
        {
          description = "Allow Kafka from VPC"
          from_port   = 9092
          to_port     = 9092
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
        },
        {
          description = "Allow Kafka TLS from VPC"
          from_port   = 9094
          to_port     = 9094
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
        },
        {
          description = "Allow Zookeeper from VPC"
          from_port   = 2181
          to_port     = 2181
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
        }
      ]
      egress_rules = [] # MSK doesn't need outbound
    }
  }

  name   = "${var.environment}-${each.key}-sg"
  vpc_id = module.networking.vpc_id

  ingress_rules = each.value.ingress_rules
  egress_rules  = each.value.egress_rules

  tags = merge(
    local.common_tags,
    {
      Purpose = each.key
    }
  )
}
