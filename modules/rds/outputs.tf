# RDS Module Outputs

output "endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "RDS instance address (hostname)"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "RDS instance port"
  value       = aws_db_instance.this.port
}

output "id" {
  description = "RDS instance ID"
  value       = aws_db_instance.this.id
}

output "arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.this.arn
}

output "username" {
  description = "RDS master username"
  value       = aws_db_instance.this.username
  sensitive   = true
}

output "database_name" {
  description = "Name of the default database"
  value       = aws_db_instance.this.db_name
}

output "resource_id" {
  description = "RDS Resource ID"
  value       = aws_db_instance.this.resource_id
}

output "availability_zone" {
  description = "Availability zone of the RDS instance"
  value       = aws_db_instance.this.availability_zone
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = aws_db_subnet_group.this.name
}

output "db_subnet_group_arn" {
  description = "ARN of the DB subnet group"
  value       = aws_db_subnet_group.this.arn
}
