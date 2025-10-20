# environments/production/main.tf

module "infrastructure" {
  source = "../../modules/environment"

  region                    = var.region
  environment               = var.environment
  vpc_cidr                  = var.vpc_cidr
  availability_zones        = var.availability_zones
  public_subnet_cidrs       = var.public_subnet_cidrs
  private_app_subnet_cidrs  = var.private_app_subnet_cidrs
  private_data_subnet_cidrs = var.private_data_subnet_cidrs
  ec2_ami_id                = var.ec2_ami_id
  ec2_instance_type         = var.ec2_instance_type
  kms_key_id                = var.kms_key_id
  ssl_certificate_arn       = var.ssl_certificate_arn
  eks_public_access_cidrs   = var.eks_public_access_cidrs
  devops_ip_ranges          = var.devops_ip_ranges
}
