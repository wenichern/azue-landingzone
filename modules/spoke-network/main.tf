terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name}-spoke"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${var.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.address_space
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  for_each             = var.subnets
  name                 = "snet-${each.key}"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = each.value.address_prefixes
}

###############################################################################
# SEGMENTATION LAYER 1: NSGs (stateful L3/L4 filtering, per subnet)
#
# Azure's default rules allow ALL traffic inside a VNet (AllowVnetInBound, 65000).
# We add a deny at priority 4000 so that anything NOT explicitly allowed by a
# lower-numbered rule (the per-subnet rules you pass in) is blocked.
###############################################################################
locals {
  baseline_rules = [
    {
      name                       = "deny-vnet-inbound-by-default"
      priority                   = 4000
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
    },
    {
      name                       = "deny-internet-inbound"
      priority                   = 4050
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
    },
  ]
}

resource "azurerm_network_security_group" "this" {
  for_each            = var.subnets
  name                = "nsg-${var.name}-${each.key}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  dynamic "security_rule" {
    for_each = concat(each.value.nsg_rules, local.baseline_rules)
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each                  = var.subnets
  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

resource "azurerm_monitor_diagnostic_setting" "nsg" {
  for_each                   = var.subnets
  name                       = "nsg-to-law"
  target_resource_id         = azurerm_network_security_group.this[each.key].id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }
}

###############################################################################
# SEGMENTATION LAYER 2: UDR forcing 0.0.0.0/0 through the hub firewall.
# `route_via_firewall` is a plain bool (known at plan time) so count works even
# though the firewall IP itself is only known after apply.
###############################################################################
resource "azurerm_route_table" "this" {
  count                         = var.route_via_firewall ? 1 : 0
  name                          = "rt-${var.name}"
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  bgp_route_propagation_enabled = false
  tags                          = var.tags

  route {
    name                   = "default-via-hub-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.firewall_private_ip
  }
}

resource "azurerm_subnet_route_table_association" "this" {
  for_each       = var.route_via_firewall ? var.subnets : {}
  subnet_id      = azurerm_subnet.this[each.key].id
  route_table_id = azurerm_route_table.this[0].id
}

###############################################################################
# HUB <-> SPOKE PEERING (must be created in BOTH directions)
###############################################################################
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-${var.name}-to-hub"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false # set true if the hub has a VPN/ER gateway
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "peer-hub-to-${var.name}"
  resource_group_name          = var.hub_rg_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false # set true if the hub has a gateway
}

# Private DNS: link every hub-owned zone to this spoke.
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each              = toset(var.private_dns_zone_names)
  name                  = "link-${var.name}"
  resource_group_name   = var.hub_rg_name
  private_dns_zone_name = each.value
  virtual_network_id    = azurerm_virtual_network.spoke.id
}
