locals {
  name = "${var.prefix}-lab"
  spoke_cidrs = flatten([for s in values(var.spokes) : s.address_space])
}

# 1 ── Management group hierarchy -------------------------------------------------
module "management_groups" {
  source = "../../modules/management-groups"
  prefix = var.prefix

  subscription_associations = {
    (var.subscription_mg) = [var.subscription_id]
  }
}

# 2 ── Central logging (everything else sends here) -------------------------------
module "logging" {
  source            = "../../modules/logging"
  name              = local.name
  location          = var.location
  tags              = var.tags
  enable_entra_logs = var.enable_entra_logs

  depends_on = [module.management_groups]
}

# 3 ── Hub network (+ optional firewall) ------------------------------------------
module "hub" {
  source = "../../modules/hub-network"

  name                       = local.name
  location                   = var.location
  tags                       = var.tags
  address_space              = var.hub_address_space
  shared_subnet_prefix       = var.hub_shared_subnet_prefix
  firewall_subnet_prefix     = var.hub_firewall_subnet_prefix
  deploy_firewall            = var.deploy_firewall
  spoke_cidrs                = local.spoke_cidrs
  private_dns_zones          = var.private_dns_zones
  log_analytics_workspace_id = module.logging.workspace_id

  # Lesson 4 exercise: uncomment to allow app1 web tier -> app2 workload on 443.
  # firewall_network_rules = [{
  #   name                  = "app1-web-to-app2"
  #   protocols             = ["TCP"]
  #   source_addresses      = ["10.10.0.0/24"]
  #   destination_addresses = ["10.20.0.0/24"]
  #   destination_ports     = ["443"]
  # }]
}

# 4 ── Spokes ---------------------------------------------------------------------
module "spoke" {
  source   = "../../modules/spoke-network"
  for_each = var.spokes

  name                       = each.key
  location                   = var.location
  tags                       = var.tags
  address_space              = each.value.address_space
  subnets                    = each.value.subnets
  hub_vnet_id                = module.hub.vnet_id
  hub_vnet_name              = module.hub.vnet_name
  hub_rg_name                = module.hub.resource_group_name
  route_via_firewall         = var.deploy_firewall
  firewall_private_ip        = module.hub.firewall_private_ip
  private_dns_zone_names     = var.private_dns_zones
  log_analytics_workspace_id = module.logging.workspace_id

  depends_on = [module.hub]
}

# 5 ── Policy (after network so first apply isn't blocked by its own guardrails) --
module "policy" {
  source            = "../../modules/policy"
  root_mg_id        = module.management_groups.ids["root"]
  corp_mg_id        = module.management_groups.ids["corp"]
  location          = var.location
  allowed_locations = var.allowed_locations
  enforce           = var.enforce_policy

  depends_on = [module.spoke]
}

# 6 ── Monitoring -----------------------------------------------------------------
module "monitoring" {
  source                     = "../../modules/monitoring"
  name                       = local.name
  location                   = var.location
  tags                       = var.tags
  alert_email                = var.alert_email
  log_analytics_workspace_id = module.logging.workspace_id
  enable_firewall_alert      = var.deploy_firewall
}

# 7 ── Cost governance ------------------------------------------------------------
module "cost" {
  source            = "../../modules/cost"
  name              = local.name
  monthly_amount    = var.monthly_budget
  budget_start_date = var.budget_start_date
  contact_emails    = [var.alert_email]
}

# 8 ── Identity: Entra groups + RBAC ----------------------------------------------
module "identity" {
  count  = var.enable_identity ? 1 : 0
  source = "../../modules/identity"

  groups = {
    "lz-platform-admins"  = { description = "Operate platform resources (use PIM for elevation)" }
    "lz-network-admins"   = { description = "Manage hub/spoke networking" }
    "lz-security-readers" = { description = "Read security posture everywhere" }
    "lz-corp-contributors" = { description = "Build workloads in Corp landing zones" }
    "lz-finops"           = { description = "View and analyse cost" }
  }

  role_assignments = [
    { group = "lz-security-readers", role = "Security Reader", scope = module.management_groups.ids["root"] },
    { group = "lz-security-readers", role = "Monitoring Reader", scope = module.management_groups.ids["root"] },
    { group = "lz-finops", role = "Cost Management Reader", scope = module.management_groups.ids["root"] },
    { group = "lz-network-admins", role = "Network Contributor", scope = module.management_groups.ids["platform"] },
    { group = "lz-corp-contributors", role = "Contributor", scope = module.management_groups.ids["corp"] },
  ]

  # Privileged role: eligible only; user must activate with MFA + justification.
  pim_eligible_assignments = var.enable_pim ? [
    { group = "lz-platform-admins", role = "Contributor", scope = module.management_groups.ids["platform"] },
  ] : []

  enable_conditional_access = var.enable_conditional_access
  mfa_required_groups       = ["lz-platform-admins", "lz-network-admins"]
  break_glass_group_ids     = var.break_glass_group_ids
}
