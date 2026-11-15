terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name}-hub"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.name}-hub"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.address_space
  tags                = var.tags
}

# Shared services (DNS resolvers, jump hosts, etc.)
resource "azurerm_subnet" "shared" {
  name                 = "snet-shared"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.shared_subnet_prefix]
}

# Azure Firewall demands this exact subnet name and /26 or larger.
resource "azurerm_subnet" "firewall" {
  count                = var.deploy_firewall ? 1 : 0
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.firewall_subnet_prefix]
}

resource "azurerm_public_ip" "firewall" {
  count               = var.deploy_firewall ? 1 : 0
  name                = "pip-${var.name}-fw"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall_policy" "this" {
  count               = var.deploy_firewall ? 1 : 0
  name                = "fwp-${var.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = var.firewall_sku_tier
  # Default behaviour of Azure Firewall is DENY. Only rules below open anything.
  threat_intelligence_mode = "Alert"
  tags                     = var.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "main" {
  count              = var.deploy_firewall ? 1 : 0
  name               = "rcg-landing-zone"
  firewall_policy_id = azurerm_firewall_policy.this[0].id
  priority           = 200

  application_rule_collection {
    name     = "allow-web-egress"
    priority = 500
    action   = "Allow"
    rule {
      name = "microsoft-and-package-repos"
      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
      source_addresses  = var.spoke_cidrs
      destination_fqdns = var.allowed_egress_fqdns
    }
  }

  # East-west rules: spoke-to-spoke is DENIED until you add it here.
  dynamic "network_rule_collection" {
    for_each = length(var.firewall_network_rules) > 0 ? [1] : []
    content {
      name     = "allow-east-west"
      priority = 400
      action   = "Allow"
      dynamic "rule" {
        for_each = var.firewall_network_rules
        content {
          name                  = rule.value.name
          protocols             = rule.value.protocols
          source_addresses      = rule.value.source_addresses
          destination_addresses = rule.value.destination_addresses
          destination_ports     = rule.value.destination_ports
        }
      }
    }
  }
}

resource "azurerm_firewall" "this" {
  count               = var.deploy_firewall ? 1 : 0
  name                = "afw-${var.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku_tier
  firewall_policy_id  = azurerm_firewall_policy.this[0].id
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.firewall[0].id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }

  depends_on = [azurerm_firewall_policy_rule_collection_group.main]
}

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  count                          = var.deploy_firewall ? 1 : 0
  name                           = "fw-to-law"
  target_resource_id             = azurerm_firewall.this[0].id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated" # resource-specific tables (AZFWNetworkRule, ...)

  enabled_log {
    category_group = "allLogs"
  }
}

# Private DNS zones live in the hub and are linked to every VNet,
# so Private Endpoints resolve consistently everywhere.
resource "azurerm_private_dns_zone" "this" {
  for_each            = toset(var.private_dns_zones)
  name                = each.value
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  for_each              = toset(var.private_dns_zones)
  name                  = "link-hub"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.value].name
  virtual_network_id    = azurerm_virtual_network.hub.id
}
