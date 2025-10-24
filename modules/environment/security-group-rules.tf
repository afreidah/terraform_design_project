# modules/environment/security-group-rules.tf

# -----------------------------------------------------------------------------
# CROSS-MODULE SECURITY GROUP RULES
# -----------------------------------------------------------------------------
#
# Security group rules that reference resources from multiple modules.
# These must be created at the environment level to avoid Terraform's
# "known only after apply" errors with count/for_each.
#
# These rules are created here instead of in the individual modules because
# they reference security groups from different modules (ALB + EKS), and
# Terraform cannot determine count/for_each values when they depend on
# resources that don't exist yet during planning.
# -----------------------------------------------------------------------------

# Allow public ALB to communicate with EKS worker nodes
# Required when using AWS Load Balancer Controller with target type: ip
# This enables the ALB to route traffic directly to pods running on the nodes
resource "aws_security_group_rule" "alb_public_to_eks_nodes" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = module.eks_node_group.security_group_id
  source_security_group_id = module.security_groups["alb_public"].security_group_id
  description              = "Allow traffic from public ALB to EKS nodes for pod access"

  depends_on = [
    module.eks_node_group,
    module.security_groups
  ]
}

# Allow internal ALB to communicate with EKS worker nodes
# Required if you have Kubernetes services exposed via the internal ALB
resource "aws_security_group_rule" "alb_internal_to_eks_nodes" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = module.eks_node_group.security_group_id
  source_security_group_id = module.security_groups["alb_internal"].security_group_id
  description              = "Allow traffic from internal ALB to EKS nodes for pod access"

  depends_on = [
    module.eks_node_group,
    module.security_groups
  ]
}
