variable "description" {
  description = "Description of the KMS key"
  type        = string
}

variable "deletion_window_in_days" {
  description = "Duration in days before key deletion"
  type        = number
  default     = 30
}

variable "enable_key_rotation" {
  description = "Enable automatic key rotation"
  type        = bool
  default     = true
}

variable "policy" {
  description = "KMS key policy (JSON)"
  type        = string
  default     = null
}

variable "alias_name" {
  description = "KMS key alias name (without 'alias/' prefix)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags for the KMS key"
  type        = map(string)
  default     = {}
}
