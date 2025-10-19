output "domain_id" {
  description = "Unique identifier for the domain"
  value       = aws_opensearch_domain.this.domain_id
}

output "domain_name" {
  description = "Name of the OpenSearch domain"
  value       = aws_opensearch_domain.this.domain_name
}

output "domain_arn" {
  description = "ARN of the domain"
  value       = aws_opensearch_domain.this.arn
}

output "endpoint" {
  description = "Domain-specific endpoint used to submit index, search, and data upload requests"
  value       = aws_opensearch_domain.this.endpoint
}

output "dashboard_endpoint" {
  description = "Domain-specific endpoint for Dashboard/Kibana"
  value       = aws_opensearch_domain.this.dashboard_endpoint
}

output "index_slow_logs_log_group_name" {
  description = "CloudWatch log group name for index slow logs"
  value       = aws_cloudwatch_log_group.index_slow_logs.name
}

output "search_slow_logs_log_group_name" {
  description = "CloudWatch log group name for search slow logs"
  value       = aws_cloudwatch_log_group.search_slow_logs.name
}

output "application_logs_log_group_name" {
  description = "CloudWatch log group name for application logs"
  value       = aws_cloudwatch_log_group.es_application_logs.name
}

output "audit_logs_log_group_name" {
  description = "CloudWatch log group name for audit logs"
  value       = var.enable_audit_logs ? aws_cloudwatch_log_group.audit_logs[0].name : null
}
