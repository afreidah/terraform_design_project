# SSM Parameters
resource "aws_ssm_parameter" "this" {
  for_each = var.parameters

  name        = each.key
  description = each.value.description
  type        = each.value.type
  value       = each.value.value
  tier        = each.value.tier
  key_id      = each.value.key_id

  tags = merge(
    var.tags,
    {
      Name = each.key
    }
  )
}
