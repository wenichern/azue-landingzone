variable "subscription_id" {
  type = string
}

variable "prefix" {
  type        = string
  default     = "lz"
  description = "Also the ID of your top-level management group. Must be unique in the tenant."
}

variable "location" {
  type    = string
  default = "eastus2"
}

variable "allowed_locations" {
  type    = list(string)
  default = ["eastus2", "eastus", "global"]
}

variable "tags" {
  type = map(string)
  default = {
    costCenter  = "learning"
    environment = "lab"
    owner       = "platform-team"
    managedBy   = "terraform"
  }
}

# ---- Module 2: management groups
variable "subscription_mg" {
  type        = string
  default     = "sandbox"
  description = "Which management group this (single) lab subscription sits under. Try \"corp\" in lesson 6."
}

# ---- Module 3/4: network
variable "hub_address_space" {
  type    = list(string)
  default = ["10.0.0.0/22"]
}

variable "hub_shared_subnet_prefix" {
  type    = string
  default = "10.0.0.0/26"
}

variable "hub_firewall_subnet_prefix" {
  type    = string
  default = "10.0.1.0/26"
}

variable "deploy_firewall" {
  type        = bool
  default     = false
  description = "Azure Firewall is the biggest cost item in this lab (~US$1.25/hr)."
}

variable "private_dns_zones" {
  type    = list(string)
  default = ["privatelink.blob.core.windows.net", "privatelink.vaultcore.azure.net"]
}

variable "spokes" {
  type = map(object({
    address_space = list(string)
    subnets = map(object({
      address_prefixes = list(string)
      nsg_rules = optional(list(object({
        name                       = string
        priority                   = number
        direction                  = optional(string, "Inbound")
        access                     = optional(string, "Allow")
        protocol                   = optional(string, "Tcp")
        source_port_range          = optional(string, "*")
        destination_port_range     = string
        source_address_prefix      = string
        destination_address_prefix = optional(string, "*")
      })), [])
    }))
  }))

  default = {
    # Classic 3-tier app: web -> app -> data, nothing else.
    app1 = {
      address_space = ["10.10.0.0/22"]
      subnets = {
        web = {
          address_prefixes = ["10.10.0.0/24"]
          nsg_rules = [
            # Only the hub (where the firewall/App Gateway lives) may reach the web tier.
            { name = "allow-https-from-hub", priority = 100, destination_port_range = "443", source_address_prefix = "10.0.0.0/22" },
          ]
        }
        app = {
          address_prefixes = ["10.10.1.0/24"]
          nsg_rules = [
            { name = "allow-8080-from-web", priority = 100, destination_port_range = "8080", source_address_prefix = "10.10.0.0/24" },
          ]
        }
        data = {
          address_prefixes = ["10.10.2.0/24"]
          nsg_rules = [
            { name = "allow-sql-from-app", priority = 100, destination_port_range = "1433", source_address_prefix = "10.10.1.0/24" },
          ]
        }
      }
    }
    # A second, unrelated workload: spokes can't talk to each other until you allow it.
    app2 = {
      address_space = ["10.20.0.0/24"]
      subnets = {
        workload = { address_prefixes = ["10.20.0.0/24"] }
      }
    }
  }
}

# ---- Module 5: identity
variable "enable_identity" {
  type        = bool
  default     = true
  description = "Creates Entra groups + RBAC. Needs Graph Group.ReadWrite.All."
}

variable "enable_conditional_access" {
  type        = bool
  default     = false
  description = "Needs Entra ID P1 and Policy.ReadWrite.ConditionalAccess."
}

variable "enable_pim" {
  type        = bool
  default     = false
  description = "Needs Entra ID P2 (Governance)."
}

variable "enable_entra_logs" {
  type        = bool
  default     = false
  description = "Send Entra sign-in/audit logs to Log Analytics (needs P1/P2)."
}

variable "break_glass_group_ids" {
  type    = list(string)
  default = []
}

# ---- Module 6: policy
variable "enforce_policy" {
  type        = bool
  default     = true
  description = "false = audit only (safe rollout); true = deny."
}

# ---- Module 7: monitoring
variable "alert_email" {
  type = string
}

# ---- Module 8: cost
variable "monthly_budget" {
  type    = number
  default = 100
}

variable "budget_start_date" {
  type        = string
  default     = "2026-11-01T00:00:00Z"
  description = "Must be the first day of a month."
}
