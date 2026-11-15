output "management_group_ids" {
  value = module.management_groups.ids
}

output "log_analytics_workspace" {
  value = module.logging.workspace_name
}

output "hub_vnet" {
  value = module.hub.vnet_name
}

output "firewall_private_ip" {
  value = module.hub.firewall_private_ip
}

output "spoke_vnets" {
  value = { for k, s in module.spoke : k => s.vnet_id }
}

output "entra_group_ids" {
  value = try(module.identity[0].group_object_ids, {})
}
