# -----------------------------------------------------------------------------
# EKS CLUSTER MODULE - OUTPUT VALUES
# -----------------------------------------------------------------------------
#
# This file exposes attributes of the created EKS cluster and related
# resources for use by parent modules, node groups, and external integrations.
#
# Output Categories:
#   - Cluster Core: Basic cluster identifiers and endpoints
#   - Authentication: Certificate and OIDC provider information
#   - Security: IAM roles and security groups
#   - Add-ons: Installed add-on versions
#   - Logging: CloudWatch log group information
#
# Usage:
#   - cluster_endpoint: Configure kubectl and CI/CD pipelines
#   - oidc_provider_arn: Create IRSA roles for workloads
#   - cluster_certificate_authority_data: Authenticate to cluster
#   - cluster_security_group_id: Configure node security groups
#   - Add-on versions: Verify installed component versions
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# CLUSTER CORE OUTPUTS
# -----------------------------------------------------------------------------

output "cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = aws_eks_cluster.this.id
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "The Kubernetes server version for the cluster"
  value       = aws_eks_cluster.this.version
}

output "cluster_platform_version" {
  description = "The platform version for the cluster"
  value       = aws_eks_cluster.this.platform_version
}

# -----------------------------------------------------------------------------
# AUTHENTICATION OUTPUTS
# -----------------------------------------------------------------------------

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

# -----------------------------------------------------------------------------
# OIDC PROVIDER OUTPUTS (FOR IRSA)
# -----------------------------------------------------------------------------

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC Provider for EKS"
  value       = aws_iam_openid_connect_provider.cluster.url
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = try(aws_eks_cluster.this.identity[0].oidc[0].issuer, null)
}

# -----------------------------------------------------------------------------
# SECURITY OUTPUTS
# -----------------------------------------------------------------------------

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.cluster.id
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "cluster_iam_role_name" {
  description = "IAM role name of the EKS cluster"
  value       = aws_iam_role.cluster.name
}

# -----------------------------------------------------------------------------
# ADD-ON OUTPUTS
# -----------------------------------------------------------------------------

output "vpc_cni_addon_version" {
  description = "Version of VPC CNI add-on"
  value       = aws_eks_addon.vpc_cni.addon_version
}

output "coredns_addon_version" {
  description = "Version of CoreDNS add-on"
  value       = aws_eks_addon.coredns.addon_version
}

output "kube_proxy_addon_version" {
  description = "Version of kube-proxy add-on"
  value       = aws_eks_addon.kube_proxy.addon_version
}

# -----------------------------------------------------------------------------
# CLOUDWATCH LOGGING OUTPUTS
# -----------------------------------------------------------------------------

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for EKS cluster logs"
  value       = aws_cloudwatch_log_group.cluster.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for EKS cluster logs"
  value       = aws_cloudwatch_log_group.cluster.arn
}
