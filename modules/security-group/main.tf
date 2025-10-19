# Security Group
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

# Ingress Rules
resource "aws_security_group_rule" "ingress" {
  count = length(var.ingress_rules)

  type                     = "ingress"
  from_port                = var.ingress_rules[count.index].from_port
  to_port                  = var.ingress_rules[count.index].to_port
  protocol                 = var.ingress_rules[count.index].protocol
  cidr_blocks              = var.ingress_rules[count.index].cidr_blocks
  source_security_group_id = var.ingress_rules[count.index].source_security_group_id
  description              = var.ingress_rules[count.index].description
  security_group_id        = aws_security_group.this.id
}

# Egress Rules
resource "aws_security_group_rule" "egress" {
  count = length(var.egress_rules)

  type                     = "egress"
  from_port                = var.egress_rules[count.index].from_port
  to_port                  = var.egress_rules[count.index].to_port
  protocol                 = var.egress_rules[count.index].protocol
  cidr_blocks              = var.egress_rules[count.index].cidr_blocks
  source_security_group_id = var.egress_rules[count.index].source_security_group_id
  description              = var.egress_rules[count.index].description
  security_group_id        = aws_security_group.this.id
}
