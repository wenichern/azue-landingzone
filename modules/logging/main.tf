terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name}-logging"
  location = var.location
  tags     = var.tags
}

# Central Log Analytics workspace: the single place every diagnostic stream lands.
resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.name}-central"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_days
  daily_quota_gb      = var.daily_quota_gb # cost guardrail; -1 = unlimited
  tags                = var.tags
}

# Subscription Activity Log (control-plane audit: who created/deleted what).
resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  name                       = "activity-log-to-law"
  target_resource_id         = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  dynamic "enabled_log" {
    for_each = ["Administrative", "Security", "ServiceHealth", "Alert", "Recommendation", "Policy", "Autoscale", "ResourceHealth"]
    content {
      category = enabled_log.value
    }
  }
}

# Entra ID sign-in & audit logs (needs Entra ID P1/P2 + Security/Global Admin).
resource "azurerm_monitor_aad_diagnostic_setting" "entra" {
  count                      = var.enable_entra_logs ? 1 : 0
  name                       = "entra-to-law"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  dynamic "enabled_log" {
    for_each = ["AuditLogs", "SignInLogs", "NonInteractiveUserSignInLogs", "ServicePrincipalSignInLogs", "ManagedIdentitySignInLogs"]
    content {
      category = enabled_log.value
      retention_policy {
        enabled = false
        days    = 0
      }
    }
  }
}

# Saved KQL so learners have something to click on.
resource "azurerm_log_analytics_saved_search" "policy_denies" {
  name                       = "PolicyDenies"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  category                   = "LandingZone"
  display_name               = "Policy denials (last 24h)"
  query                      = <<-KQL
    AzureActivity
    | where TimeGenerated > ago(24h)
    | where CategoryValue == "Policy" and ActivityStatusValue == "Failure"
    | project TimeGenerated, Caller, OperationNameValue, ResourceGroup, Properties
    | order by TimeGenerated desc
  KQL
}
