output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "pipeline_client_id" {
  value = azuread_application.cicd.client_id
}

output "backend_hcl" {
  description = "Paste into envs/lab/backend.hcl"
  value       = <<-EOT
    resource_group_name  = "${azurerm_resource_group.state.name}"
    storage_account_name = "${azurerm_storage_account.state.name}"
    container_name       = "${azurerm_storage_container.tfstate.name}"
    key                  = "lab.tfstate"
    use_azuread_auth     = true
  EOT
}

output "github_setup_commands" {
  description = "Run these to store (non-secret) identifiers in GitHub."
  value       = <<-EOT
    gh variable set AZURE_CLIENT_ID       --body "${azuread_application.cicd.client_id}"
    gh variable set AZURE_TENANT_ID       --body "${data.azurerm_client_config.current.tenant_id}"
    gh variable set AZURE_SUBSCRIPTION_ID --body "${var.subscription_id}"
    gh variable set TFSTATE_RG            --body "${azurerm_resource_group.state.name}"
    gh variable set TFSTATE_SA            --body "${azurerm_storage_account.state.name}"
    gh variable set ALERT_EMAIL           --body "you@example.com"
  EOT
}
