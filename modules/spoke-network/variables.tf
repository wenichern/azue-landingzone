variable "name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "address_space" { type = list(string) }
variable "log_analytics_workspace_id" { type = string }

variable "subnets" {
  type = map(object({
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
}

variable "hub_vnet_id" { type = string }
variable "hub_vnet_name" { type = string }
variable "hub_rg_name" { type = string }

variable "route_via_firewall" {
  type    = bool
  default = false
}

variable "firewall_private_ip" {
  type    = string
  default = null
}

variable "private_dns_zone_names" {
  type    = list(string)
  default = []
}
