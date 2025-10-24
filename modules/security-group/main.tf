# -----------------------------------------------------------------------------
# SECURITY GROUP MODULE
# -----------------------------------------------------------------------------
#
# This module creates an AWS VPC security group with configurable ingress and
# egress rules for network traffic control. Rules are created as separate
# resources to enable granular management and avoid the limitations of inline
# rule definitions.
#
# The security group supports create-before-destroy lifecycle to ensure safe
# updates during rule modifications. Rules can reference CIDR blocks or other
# security groups as sources. Multiple protocols including TCP, UDP, and ICMP
# are supported with configurable port ranges.
#
# IMPORTANT: Security scanner suppressions are included for common patterns
# like public ALB ingress and EC2 egress to internet. Review and adjust
# suppressions based on specific security requirements and organizational
# policies.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# SECURITY GROUP
# -----------------------------------------------------------------------------

# VPC security group for network access control
# Uses create-before-destroy to prevent connectivity disruption during updates
resource "aws_security_group" "this" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# INGRESS RULES
# -----------------------------------------------------------------------------

# Inbound traffic rules for the security group
# Created as separate resources for granular management
resource "aws_security_group_rule" "ingress" {
  #tfsec:ignore:aws-ec2-no-public-ingress-sgr Public ALB requires internet access on 80/443
  #checkov:skip=CKV_AWS_260:Public ALB security group intentionally allows internet traffic
  count = length(var.ingress_rules)

  type              = "ingress"
  from_port         = var.ingress_rules[count.index].from_port
  to_port           = var.ingress_rules[count.index].to_port
  protocol          = var.ingress_rules[count.index].protocol
  cidr_blocks       = var.ingress_rules[count.index].cidr_blocks
  security_group_id = aws_security_group.this.id
  description       = var.ingress_rules[count.index].description
}

# -----------------------------------------------------------------------------
# EGRESS RULES
# -----------------------------------------------------------------------------

# Outbound traffic rules for the security group
# Created as separate resources for granular management
resource "aws_security_group_rule" "egress" {
  #tfsec:ignore:aws-ec2-no-public-egress-sgr EC2 instances need internet access for package updates and AWS APIs
  #checkov:skip=CKV_AWS_23:Egress to internet required for package updates and AWS service access
  #trivy:ignore:AVD-AWS-0104
  count = length(var.egress_rules)

  type              = "egress"
  from_port         = var.egress_rules[count.index].from_port
  to_port           = var.egress_rules[count.index].to_port
  protocol          = var.egress_rules[count.index].protocol
  cidr_blocks       = var.egress_rules[count.index].cidr_blocks
  security_group_id = aws_security_group.this.id
  description       = var.egress_rules[count.index].description
}
