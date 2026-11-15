variable "root_mg_id" { type = string }
variable "corp_mg_id" { type = string }
variable "location" { type = string }

variable "allowed_locations" {
  type = list(string)
}

variable "required_tag" {
  type    = string
  default = "costCenter"
}

variable "enforce" {
  type        = bool
  default     = true
  description = "false = Audit/DoNotEnforce (safe roll-out); true = Deny."
}
