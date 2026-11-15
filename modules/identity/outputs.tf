output "group_object_ids" {
  value = { for k, g in azuread_group.this : k => g.object_id }
}
