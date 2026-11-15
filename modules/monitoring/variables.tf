variable "name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "alert_email" { type = string }
variable "log_analytics_workspace_id" { type = string }

variable "enable_firewall_alert" {
  type        = bool
  default     = false
  description = "Only enable when the firewall (and its resource-specific log tables) exist."
}
