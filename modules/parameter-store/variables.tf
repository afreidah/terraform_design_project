variable "parameters" {
  description = "Map of parameters to create"
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
  description = "Tags to apply to parameters"
  type        = map(string)
  default     = {}
}
