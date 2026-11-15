output "resource_group_name" { value = azurerm_resource_group.this.name }
output "vnet_id" { value = azurerm_virtual_network.hub.id }
output "vnet_name" { value = azurerm_virtual_network.hub.name }
output "firewall_private_ip" {
  value = try(azurerm_firewall.this[0].ip_configuration[0].private_ip_address, null)
}
output "private_dns_zone_names" { value = [for z in azurerm_private_dns_zone.this : z.name] }
