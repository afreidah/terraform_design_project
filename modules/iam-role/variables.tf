variable "name" {
  description = "Name of the IAM role"
  type        = string
}

variable "assume_role_policy" {
  description = "IAM policy document for assume role"
  type        = string
}

variable "policy_arns" {
  description = "List of IAM policy ARNs to attach to role"
  type        = list(string)
  default     = []
}

variable "create_instance_profile" {
  description = "Whether to create an instance profile for EC2"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to IAM role"
  type        = map(string)
  default     = {}
}
