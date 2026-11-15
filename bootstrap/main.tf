###############################################################################
# BOOTSTRAP — run ONCE, locally, with `az login`.
# Creates (1) remote-state storage and (2) an Entra app registration that
# GitHub Actions uses via OIDC workload identity federation (no secrets!).
###############################################################################
terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    azuread = { source = "hashicorp/azuread", version = "~> 3.0" }
    random  = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azuread" {}

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

# ---------------------------------------------------------------- state store
resource "azurerm_resource_group" "state" {
  name     = "rg-${var.prefix}-tfstate"
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "state" {
  name                            = "st${var.prefix}tf${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.state.name
  location                        = azurerm_resource_group.state.location
  account_tier                    = "Standard"
  account_replication_type        = "GRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  default_to_oauth_authentication = true
  # HARDENING TODO (prod): set shared_access_key_enabled = false and create the
  # container with storage_use_azuread = true once your deployer has data-plane RBAC.

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 14
    }
  }
  tags = var.tags
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"
}

# ------------------------------------------- GitHub -> Entra OIDC federation
resource "azuread_application" "cicd" {
  display_name = "${var.prefix}-github-terraform"
}

resource "azuread_service_principal" "cicd" {
  client_id = azuread_application.cicd.client_id
}

# One federated credential per GitHub *environment* + one for pull requests.
# The `subject` claim is what Entra trusts. Be exact — it is your security boundary.
resource "azuread_application_federated_identity_credential" "env" {
  for_each       = toset(var.github_environments)
  application_id = azuread_application.cicd.id
  display_name   = "github-env-${each.value}"
  description    = "GitHub Actions - environment ${each.value}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:environment:${each.value}"
}

resource "azuread_application_federated_identity_credential" "pr" {
  application_id = azuread_application.cicd.id
  display_name   = "github-pull-request"
  description    = "GitHub Actions - pull_request (plan only)"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:pull_request"
}

# ------------------------------------------------------------------ Azure RBAC
resource "azurerm_role_assignment" "sub_contributor" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.cicd.object_id
}

resource "azurerm_role_assignment" "state_blob" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.cicd.object_id
}

# Management groups, policy and RBAC all live ABOVE the subscription, so the
# pipeline needs rights at the tenant root group. This is broad — see docs/01.
# Your own account needs "Elevate access" (User Access Administrator at "/") to apply this.
locals {
  tenant_root_roles = var.grant_tenant_root_access ? toset([
    "Management Group Contributor",
    "Resource Policy Contributor",
    "Role Based Access Control Administrator",
  ]) : toset([])
}

resource "azurerm_role_assignment" "tenant_root" {
  for_each             = local.tenant_root_roles
  scope                = "/providers/Microsoft.Management/managementGroups/${data.azurerm_client_config.current.tenant_id}"
  role_definition_name = each.value
  principal_id         = azuread_service_principal.cicd.object_id
}

# ------------------------------------------------- Microsoft Graph app roles
# Needed so the pipeline can manage Entra groups / Conditional Access.
# Requires you to be Privileged Role Administrator or Global Administrator.
data "azuread_application_published_app_ids" "well_known" {}

resource "azuread_service_principal" "msgraph" {
  client_id    = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
  use_existing = true
}

resource "azuread_app_role_assignment" "graph" {
  for_each            = toset(var.graph_app_roles)
  app_role_id         = azuread_service_principal.msgraph.app_role_ids[each.value]
  principal_object_id = azuread_service_principal.cicd.object_id
  resource_object_id  = azuread_service_principal.msgraph.object_id
}
