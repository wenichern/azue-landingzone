terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}

# Hierarchy (simplified Azure Landing Zone / CAF):
#
#   <root>
#   ├── platform        ── connectivity, identity, management
#   ├── landing-zones   ── corp, online
#   ├── sandbox
#   └── decommissioned
#
# Policy and RBAC assigned high in the tree INHERIT downward.

resource "azurerm_management_group" "root" {
  name         = var.prefix
  display_name = var.root_display_name
}

resource "azurerm_management_group" "platform" {
  name                       = "${var.prefix}-platform"
  display_name               = "Platform"
  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "connectivity" {
  name                       = "${var.prefix}-connectivity"
  display_name               = "Connectivity"
  parent_management_group_id = azurerm_management_group.platform.id
}

resource "azurerm_management_group" "identity" {
  name                       = "${var.prefix}-identity"
  display_name               = "Identity"
  parent_management_group_id = azurerm_management_group.platform.id
}

resource "azurerm_management_group" "management" {
  name                       = "${var.prefix}-management"
  display_name               = "Management"
  parent_management_group_id = azurerm_management_group.platform.id
}

resource "azurerm_management_group" "landing_zones" {
  name                       = "${var.prefix}-landingzones"
  display_name               = "Landing Zones"
  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "corp" {
  name                       = "${var.prefix}-corp"
  display_name               = "Corp (private workloads)"
  parent_management_group_id = azurerm_management_group.landing_zones.id
}

resource "azurerm_management_group" "online" {
  name                       = "${var.prefix}-online"
  display_name               = "Online (internet-facing workloads)"
  parent_management_group_id = azurerm_management_group.landing_zones.id
}

resource "azurerm_management_group" "sandbox" {
  name                       = "${var.prefix}-sandbox"
  display_name               = "Sandbox"
  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "decommissioned" {
  name                       = "${var.prefix}-decom"
  display_name               = "Decommissioned"
  parent_management_group_id = azurerm_management_group.root.id
}

locals {
  ids = {
    root           = azurerm_management_group.root.id
    platform       = azurerm_management_group.platform.id
    connectivity   = azurerm_management_group.connectivity.id
    identity       = azurerm_management_group.identity.id
    management     = azurerm_management_group.management.id
    landing_zones  = azurerm_management_group.landing_zones.id
    corp           = azurerm_management_group.corp.id
    online         = azurerm_management_group.online.id
    sandbox        = azurerm_management_group.sandbox.id
    decommissioned = azurerm_management_group.decommissioned.id
  }

  # { "<mg-key>/<sub-id>" => { mg_key, sub_id } }
  associations = merge([
    for mg_key, subs in var.subscription_associations : {
      for s in subs : "${mg_key}/${s}" => { mg_key = mg_key, sub_id = s }
    }
  ]...)
}

resource "azurerm_management_group_subscription_association" "this" {
  for_each            = local.associations
  management_group_id = local.ids[each.value.mg_key]
  subscription_id     = "/subscriptions/${each.value.sub_id}"
}
