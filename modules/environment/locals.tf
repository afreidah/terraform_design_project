# environments/production/locals.tf

locals {
  # Common tags for all resources
  common_tags = {
    Environment = var.environment
    Project     = "infrastructure-exercise"
    ManagedBy   = "Terraform"
  }
}
