terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}

# ------------------------------------------------------------ built-in lookups
data "azurerm_policy_definition" "allowed_locations" {
  display_name = "Allowed locations"
}

data "azurerm_policy_definition" "require_rg_tag" {
  display_name = "Require a tag on resource groups"
}

data "azurerm_policy_definition" "inherit_tag" {
  display_name = "Inherit a tag from the resource group if missing"
}

data "azurerm_policy_definition" "storage_https" {
  display_name = "Secure transfer to storage accounts should be enabled"
}

data "azurerm_policy_definition" "subnet_nsg" {
  display_name = "Subnets should be associated with a Network Security Group"
}

locals {
  effect = var.enforce ? "Deny" : "Audit"
}

# ------------------------------------------------- custom policy definition
# Example of authoring your own rule: block Public IPs in the Corp landing zone.
resource "azurerm_policy_definition" "deny_public_ip" {
  name                = "lz-deny-public-ip"
  policy_type         = "Custom"
  mode                = "All"
  display_name        = "Landing Zone: public IP addresses are not allowed"
  description         = "Corp workloads must be private. Ingress/egress goes through the hub."
  management_group_id = var.root_mg_id

  metadata = jsonencode({ category = "Network", version = "1.0.0" })

  parameters = jsonencode({
    effect = {
      type          = "String"
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue  = "Deny"
      metadata      = { displayName = "Effect" }
    }
  })

  policy_rule = jsonencode({
    if = {
      field  = "type"
      equals = "Microsoft.Network/publicIPAddresses"
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })
}

# ------------------------------------------------- custom initiative (baseline)
resource "azurerm_policy_set_definition" "baseline" {
  name                = "lz-baseline"
  policy_type         = "Custom"
  display_name        = "Landing Zone Baseline"
  description         = "Locations, tagging and basic network/storage hygiene for every subscription."
  management_group_id = var.root_mg_id

  metadata = jsonencode({ category = "Landing Zone", version = "1.0.0" })

  policy_definition_reference {
    policy_definition_id = data.azurerm_policy_definition.allowed_locations.id
    reference_id         = "allowed-locations"
    parameter_values = jsonencode({
      listOfAllowedLocations = { value = var.allowed_locations }
    })
  }

  policy_definition_reference {
    policy_definition_id = data.azurerm_policy_definition.require_rg_tag.id
    reference_id         = "require-costcenter-on-rg"
    parameter_values = jsonencode({
      tagName = { value = var.required_tag }
    })
  }

  policy_definition_reference {
    policy_definition_id = data.azurerm_policy_definition.storage_https.id
    reference_id         = "storage-https-only"
    parameter_values = jsonencode({
      effect = { value = local.effect }
    })
  }

  policy_definition_reference {
    policy_definition_id = data.azurerm_policy_definition.subnet_nsg.id
    reference_id         = "subnets-need-nsg"
  }
}

# ---------------------------------------------------------------- assignments
# Name max length for MG assignments is 24 chars.
resource "azurerm_management_group_policy_assignment" "baseline" {
  name                 = "lz-baseline"
  display_name         = "Landing Zone Baseline"
  management_group_id  = var.root_mg_id
  policy_definition_id = azurerm_policy_set_definition.baseline.id
  enforce              = var.enforce
}

resource "azurerm_management_group_policy_assignment" "deny_public_ip" {
  name                 = "lz-corp-no-pip"
  display_name         = "Corp: deny public IPs"
  management_group_id  = var.corp_mg_id
  policy_definition_id = azurerm_policy_definition.deny_public_ip.id
  enforce              = var.enforce
  parameters = jsonencode({
    effect = { value = local.effect }
  })
}

# Tag inheritance needs a managed identity because it MODIFIES resources.
resource "azurerm_management_group_policy_assignment" "inherit_tag" {
  name                 = "lz-inherit-tag"
  display_name         = "Inherit ${var.required_tag} tag from resource group"
  management_group_id  = var.root_mg_id
  policy_definition_id = data.azurerm_policy_definition.inherit_tag.id
  location             = var.location
  enforce              = var.enforce
  parameters = jsonencode({
    tagName = { value = var.required_tag }
  })

  identity {
    type = "SystemAssigned"
  }
}

# The Modify effect's identity needs Tag Contributor to do its job.
resource "azurerm_role_assignment" "inherit_tag" {
  scope                = var.root_mg_id
  role_definition_name = "Tag Contributor"
  principal_id         = azurerm_management_group_policy_assignment.inherit_tag.identity[0].principal_id
}
