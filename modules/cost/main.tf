terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}

data "azurerm_client_config" "current" {}

# Subscription budget with escalating ACTUAL alerts and a FORECAST alert.
# Budgets ALERT; they do not stop spending. Pair with automation (docs/08).
resource "azurerm_consumption_budget_subscription" "this" {
  name            = "budget-${var.name}-monthly"
  subscription_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  amount          = var.monthly_amount
  time_grain      = "Monthly"

  time_period {
    start_date = var.budget_start_date # must be the 1st of a month
  }

  dynamic "notification" {
    for_each = var.actual_thresholds
    content {
      enabled        = true
      threshold      = notification.value
      operator       = "GreaterThan"
      threshold_type = "Actual"
      contact_emails = var.contact_emails
    }
  }

  notification {
    enabled        = true
    threshold      = var.forecast_threshold
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_emails = var.contact_emails
  }
}
