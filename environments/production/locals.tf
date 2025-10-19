# environments/production/locals.tf

locals {
  security_groups = {
    alb_public = {
      description = "Security group for public-facing ALB"
      ingress_rules = [
        {
          from_port   = 443
          to_port     = 443
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
          description = "Allow HTTPS from internet"
        },
        {
          from_port   = 80
          to_port     = 80
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
          description = "Allow HTTP from internet"
        }
      ]
      egress_rules = [
        {
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
          description = "Allow all outbound"
        }
      ]
    }

    alb_internal = {
      description = "Security group for internal ALB"
      ingress_rules = [
        {
          from_port   = 443
          to_port     = 443
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
          description = "Allow HTTPS from VPC"
        },
        {
          from_port   = 80
          to_port     = 80
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
          description = "Allow HTTP from VPC"
        }
      ]
      egress_rules = [
        {
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
          description = "Allow all outbound"
        }
      ]
    }

    ec2_app = {
      description = "Security group for EC2 application instances"
      ingress_rules = [
        {
          from_port   = 80
          to_port     = 80
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
          description = "Allow HTTP from VPC"
        },
        {
          from_port   = 8080
          to_port     = 8080
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
          description = "Allow app port from VPC"
        }
      ]
      egress_rules = [
        {
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
          description = "Allow all outbound"
        }
      ]
    }

    rds = {
      description = "Security group for RDS databases"
      ingress_rules = [
        {
          from_port   = 5432
          to_port     = 5432
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
          description = "Allow PostgreSQL from VPC"
        }
      ]
      egress_rules = []
    }

    msk = {
      description = "Security group for MSK (Kafka)"
      ingress_rules = [
        {
          from_port   = 9092
          to_port     = 9092
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
          description = "Allow Kafka from VPC"
        }
      ]
      egress_rules = []
    }

    elasticache = {
      description = "Security group for Elasticache (Redis)"
      ingress_rules = [
        {
          from_port   = 6379
          to_port     = 6379
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
          description = "Allow Redis from VPC"
        }
      ]
      egress_rules = []
    }

    elasticsearch = {
      description = "Security group for Elasticsearch"
      ingress_rules = [
        {
          from_port   = 443
          to_port     = 443
          protocol    = "tcp"
          cidr_blocks = [var.vpc_cidr]
          description = "Allow HTTPS from VPC"
        }
      ]
      egress_rules = []
    }
  }
}
