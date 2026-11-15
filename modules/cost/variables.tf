variable "name" { type = string }

variable "monthly_amount" {
  type        = number
  default     = 100
  description = "Budget in your billing currency."
}

variable "budget_start_date" {
  type        = string
  description = "First day of a month, RFC3339, e.g. 2026-11-01T00:00:00Z"
}

variable "contact_emails" { type = list(string) }

variable "actual_thresholds" {
  type    = list(number)
  default = [50, 80, 100]
}

variable "forecast_threshold" {
  type    = number
  default = 100
}
