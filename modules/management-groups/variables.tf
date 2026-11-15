variable "prefix" {
  type        = string
  description = "Name prefix; also the ID of the top-level management group (tenant-unique)."
}

variable "root_display_name" {
  type    = string
  default = "Landing Zone Lab"
}

variable "subscription_associations" {
  type        = map(list(string))
  default     = {}
  description = "Map of MG key (corp, online, sandbox, connectivity, ...) to subscription IDs to place under it."
  validation {
    condition = alltrue([for k in keys(var.subscription_associations) :
    contains(["root", "platform", "connectivity", "identity", "management", "landing_zones", "corp", "online", "sandbox", "decommissioned"], k)])
    error_message = "Unknown management group key."
  }
}
