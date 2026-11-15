variable "groups" {
  type = map(object({
    description = string
    members     = optional(list(string), []) # Entra object IDs
  }))
}

variable "role_assignments" {
  type = list(object({
    group = string
    role  = string
    scope = string
  }))
  default = []
}

variable "pim_eligible_assignments" {
  type = list(object({
    group = string
    role  = string
    scope = string
  }))
  default = []
}

variable "enable_conditional_access" {
  type    = bool
  default = false
}

variable "conditional_access_state" {
  type    = string
  default = "enabledForReportingButNotEnforced"
  validation {
    condition     = contains(["enabled", "disabled", "enabledForReportingButNotEnforced"], var.conditional_access_state)
    error_message = "Invalid state."
  }
}

variable "mfa_required_groups" {
  type    = list(string)
  default = []
}

variable "break_glass_group_ids" {
  type        = list(string)
  default     = []
  description = "Emergency-access accounts MUST be excluded from CA policies or you can lock yourself out."
}
