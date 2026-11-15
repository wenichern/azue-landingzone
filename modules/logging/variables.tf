variable "name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }

variable "retention_days" {
  type    = number
  default = 30
}

variable "daily_quota_gb" {
  type        = number
  default     = 1
  description = "Daily ingestion cap in GB. Protects the lab budget. Use -1 for none."
}

variable "enable_entra_logs" {
  type    = bool
  default = false
}
