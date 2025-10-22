# -----------------------------------------------------------------------------
# VPC FLOW LOGS
# -----------------------------------------------------------------------------
#
# This file configures VPC Flow Logs for network traffic monitoring and analysis.
#
# Purpose:
#   - Security Monitoring: Detect suspicious network activity and traffic patterns
#   - Troubleshooting: Diagnose connectivity issues and application problems
#   - Compliance: Meet audit requirements for network traffic logging
#   - Forensics: Investigate security incidents with detailed network logs
#
# Architecture:
#   - Log Destination: CloudWatch Logs (alternative: S3)
#   - Traffic Type: ALL (accepts, rejects, and all traffic)
#   - Encryption: Logs encrypted with KMS at rest
#   - Retention: 365 days for compliance and audit trail
#
# IAM Role:
#   - Trust Policy: VPC Flow Logs service can assume role
#   - Permissions: Write logs to specific CloudWatch Log Group only (least privilege)
#   - Scope: Limited to VPC Flow Logs actions only
#
# Log Format:
#   - Default AWS format includes: srcaddr, dstaddr, srcport, dstport, protocol, etc.
#   - Custom format can be configured for additional fields
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# CLOUDWATCH LOG GROUP
# -----------------------------------------------------------------------------

# Log group for storing VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.environment}-flow-logs"
  retention_in_days = 365                                # 1 year retention for compliance
  kms_key_id        = module.kms_cloudwatch_logs.key_arn # Encrypt logs at rest

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-vpc-flow-logs"
    }
  )
}

# -----------------------------------------------------------------------------
# IAM ROLE FOR VPC FLOW LOGS
# -----------------------------------------------------------------------------

# IAM role that VPC Flow Logs service assumes to write logs
resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.environment}-vpc-flow-logs-role"

  # Trust policy: Allow VPC Flow Logs service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "VPCFlowLogsAssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# IAM POLICY FOR CLOUDWATCH LOGS ACCESS
# -----------------------------------------------------------------------------

# Policy granting VPC Flow Logs permission to write to CloudWatch Logs
# IMPORTANT: Scoped to specific log group only (not wildcard)
resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${var.environment}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",   # Create log streams within log group
          "logs:PutLogEvents",      # Write log events to log stream
          "logs:DescribeLogGroups", # Describe log groups (read-only)
          "logs:DescribeLogStreams" # Describe log streams (read-only)
        ]
        # Permissions scoped to specific log group only
        Resource = [
          aws_cloudwatch_log_group.vpc_flow_logs.arn,
          "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# VPC FLOW LOG
# -----------------------------------------------------------------------------

# Enable VPC Flow Logs for the VPC
resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL" # Log all traffic (accept + reject)
  vpc_id          = module.networking.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-vpc-flow-log"
    }
  )
}

# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------

output "vpc_flow_log_id" {
  description = "ID of the VPC Flow Log"
  value       = aws_flow_log.main.id
}

output "vpc_flow_log_group_name" {
  description = "CloudWatch Log Group name for VPC Flow Logs"
  value       = aws_cloudwatch_log_group.vpc_flow_logs.name
}
