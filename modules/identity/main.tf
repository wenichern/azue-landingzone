terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    azuread = { source = "hashicorp/azuread", version = "~> 3.0" }
  }
}

###############################################################################
# Identity model: NEVER assign Azure roles to individual users.
#   Entra ID user  ->  Entra security GROUP  ->  Azure RBAC role at a MG scope
# Joiners/movers/leavers then happen in Entra (HR-driven, or via SSO federation),
# not in Azure.
###############################################################################
resource "azuread_group" "this" {
  for_each         = var.groups
  display_name     = each.key
  description      = each.value.description
  security_enabled = true
  members          = each.value.members
}

locals {
  active = { for i, ra in var.role_assignments : "${ra.group}:${ra.role}:${i}" => ra }
  pim    = { for i, ra in var.pim_eligible_assignments : "${ra.group}:${ra.role}:${i}" => ra }
}

# --- Always-on (least-privilege, read/operate roles) ------------------------
resource "azurerm_role_assignment" "active" {
  for_each             = local.active
  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azuread_group.this[each.value.group].object_id
}

# --- Just-in-time (privileged roles) via Entra PIM — requires Entra ID P2 ----
data "azurerm_role_definition" "pim" {
  for_each = local.pim
  name     = each.value.role
  scope    = each.value.scope
}

resource "azurerm_pim_eligible_role_assignment" "this" {
  for_each           = local.pim
  scope              = each.value.scope
  role_definition_id = data.azurerm_role_definition.pim[each.key].id
  principal_id       = azuread_group.this[each.value.group].object_id
  justification      = "Managed by Terraform: eligible, must be activated with MFA + justification."

  schedule {
    expiration {
      duration_days = 365
    }
  }
}

# --- Conditional Access: require MFA for the privileged groups ---------------
# Starts in REPORT-ONLY so you can inspect impact in Entra sign-in logs first.
resource "azuread_conditional_access_policy" "mfa_admins" {
  count        = var.enable_conditional_access ? 1 : 0
  display_name = "LZ - Require MFA for platform admins"
  state        = var.conditional_access_state

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_groups = [for g in var.mfa_required_groups : azuread_group.this[g].object_id]
      excluded_groups = var.break_glass_group_ids
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}
