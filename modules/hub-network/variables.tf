variable "name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "address_space" { type = list(string) }
variable "shared_subnet_prefix" { type = string }
variable "log_analytics_workspace_id" { type = string }

variable "deploy_firewall" {
  type        = bool
  default     = false
  description = "COSTS MONEY (~US$1.25/hr Standard). Flip on for lessons 3-4, destroy afterward."
}

variable "firewall_subnet_prefix" {
  type    = string
  default = null
}

variable "firewall_sku_tier" {
  type    = string
  default = "Standard"
}

variable "spoke_cidrs" {
  type        = list(string)
  description = "Spoke address spaces allowed egress through the firewall."
}

variable "allowed_egress_fqdns" {
  type    = list(string)
  default = ["*.microsoft.com", "*.windows.net", "*.ubuntu.com", "*.github.com"]
}

variable "firewall_network_rules" {
  type = list(object({
    name                  = string
    protocols             = list(string)
    source_addresses      = list(string)
    destination_addresses = list(string)
    destination_ports     = list(string)
  }))
  default = []
}

variable "private_dns_zones" {
  type    = list(string)
  default = ["privatelink.blob.core.windows.net", "privatelink.vaultcore.azure.net"]
}
