# -----------------------------------------------------------------------------
# EC2 AUTO SCALING GROUP MODULE - INPUT VARIABLES
# -----------------------------------------------------------------------------
#
# This file defines all configurable parameters for the EC2 Auto Scaling Group
# module, including instance configuration, scaling parameters, networking,
# security, and storage settings.
#
# Variable Categories:
#   - Core Configuration: Name, AMI, instance type
#   - Networking: VPC subnets, security groups
#   - Security & Access: IAM profile, SSH keys, user data
#   - Auto Scaling: Min/max/desired capacity, health checks
#   - Storage: Root volume size and type
#   - Load Balancer: Target group integration
#   - Tagging: Resource tags for organization
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# CORE CONFIGURATION
# -----------------------------------------------------------------------------

variable "name" {
  description = "Name prefix for EC2 instances"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

# -----------------------------------------------------------------------------
# NETWORKING CONFIGURATION
# -----------------------------------------------------------------------------

variable "subnet_ids" {
  description = "List of subnet IDs where instances will be launched"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to instances"
  type        = list(string)
}

# -----------------------------------------------------------------------------
# SECURITY & ACCESS CONFIGURATION
# -----------------------------------------------------------------------------

variable "iam_instance_profile" {
  description = "IAM instance profile name"
  type        = string
  default     = null
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = null
}

variable "user_data" {
  description = "User data script"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# AUTO SCALING CONFIGURATION
# -----------------------------------------------------------------------------

variable "desired_capacity" {
  description = "Desired number of instances in Auto Scaling Group"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of instances in Auto Scaling Group"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances in Auto Scaling Group"
  type        = number
  default     = 4
}

# -----------------------------------------------------------------------------
# HEALTH CHECK CONFIGURATION
# -----------------------------------------------------------------------------

variable "health_check_type" {
  description = "Health check type (EC2 or ELB)"
  type        = string
  default     = "EC2"
}

variable "health_check_grace_period" {
  description = "Time after instance launch before health checks start"
  type        = number
  default     = 300
}

# -----------------------------------------------------------------------------
# LOAD BALANCER INTEGRATION
# -----------------------------------------------------------------------------

variable "target_group_arns" {
  description = "List of target group ARNs to attach to ASG"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# STORAGE CONFIGURATION
# -----------------------------------------------------------------------------

variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Type of root volume"
  type        = string
  default     = "gp3"
}

# -----------------------------------------------------------------------------
# TAGGING
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
