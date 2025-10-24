# -----------------------------------------------------------------------------
# SSM PARAMETER STORE MODULE VARIABLES
# -----------------------------------------------------------------------------

variable "parameters" {
  description = "Map of parameters to create with keys as parameter names and values containing parameter configuration"
  type = map(object({
    description = optional(string)
    type        = optional(string, "SecureString")
    value       = string
    tier        = optional(string, "Standard")
    key_id      = optional(string)
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to all parameters"
  type        = map(string)
  default     = {}
}
