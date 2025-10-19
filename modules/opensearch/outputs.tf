output "domain_id" {
  description = "ID of the OpenSearch domain"
  value       = aws_opensearch_domain.this.domain_id
}

output "domain_arn" {
  description = "ARN of the OpenSearch domain"
  value       = aws_opensearch_domain.this.arn
}

output "domain_name" {
  description = "Name of the OpenSearch domain"
  value       = aws_opensearch_domain.this.domain_name
}

output "endpoint" {
  description = "Domain-specific endpoint"
  value       = aws_opensearch_domain.this.endpoint
}

output "dashboard_endpoint" {
  description = "OpenSearch Dashboards endpoint"
  value       = aws_opensearch_domain.this.dashboard_endpoint
}

output "vpc_id" {
  description = "VPC ID if the domain is in a VPC"
  value       = try(aws_opensearch_domain.this.vpc_options[0].vpc_id, null)
}
