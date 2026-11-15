terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}

data "azurerm_client_config" "current" {}

locals {
  sub_scope = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name}-monitoring"
  location = var.location
  tags     = var.tags
}

resource "azurerm_monitor_action_group" "platform" {
  name                = "ag-${var.name}-platform"
  resource_group_name = azurerm_resource_group.this.name
  short_name          = "platform"
  tags                = var.tags

  email_receiver {
    name                    = "platform-team"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

# --- Control-plane alerts: someone changed RBAC or network security rules ----
resource "azurerm_monitor_activity_log_alert" "rbac_change" {
  name                = "alert-${var.name}-rbac-change"
  resource_group_name = azurerm_resource_group.this.name
  scopes              = [local.sub_scope]
  description         = "A role assignment was created or changed."
  tags                = var.tags

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Authorization/roleAssignments/write"
  }

  action {
    action_group_id = azurerm_monitor_action_group.platform.id
  }
}

resource "azurerm_monitor_activity_log_alert" "nsg_change" {
  name                = "alert-${var.name}-nsg-rule-change"
  resource_group_name = azurerm_resource_group.this.name
  scopes              = [local.sub_scope]
  description         = "An NSG security rule was created or changed."
  tags                = var.tags

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Network/networkSecurityGroups/securityRules/write"
  }

  action {
    action_group_id = azurerm_monitor_action_group.platform.id
  }
}

resource "azurerm_monitor_activity_log_alert" "service_health" {
  name                = "alert-${var.name}-service-health"
  resource_group_name = azurerm_resource_group.this.name
  scopes              = [local.sub_scope]
  description         = "Azure service incidents or planned maintenance affecting this subscription."
  tags                = var.tags

  criteria {
    category = "ServiceHealth"
    service_health {
      events = ["Incident", "Maintenance"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.platform.id
  }
}

# --- Data-plane alert: spike of firewall denies (log query alert) ------------
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "firewall_denies" {
  count               = var.enable_firewall_alert ? 1 : 0
  name                = "alert-${var.name}-firewall-deny-spike"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  description         = "More than 100 denied network flows in 5 minutes."
  severity            = 2
  enabled             = true
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"
  scopes               = [var.log_analytics_workspace_id]
  tags                 = var.tags

  criteria {
    query                   = <<-KQL
      AZFWNetworkRule
      | where Action == "Deny"
    KQL
    time_aggregation_method = "Count"
    threshold               = 100
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.platform.id]
  }
}
