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
