# -----------------------------------------------------------------------------
# SECURITY GROUPS
# -----------------------------------------------------------------------------

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
