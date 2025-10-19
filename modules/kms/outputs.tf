output "key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.this.id
}

output "key_arn" {
  description = "KMS key ARN"
  value       = aws_kms_key.this.arn
}

output "alias_arn" {
  description = "KMS alias ARN"
  value       = try(aws_kms_alias.this[0].arn, null)
}

output "alias_name" {
  description = "KMS alias name"
  value       = try(aws_kms_alias.this[0].name, null)
}
