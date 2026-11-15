variable "subscription_id" {
  type        = string
  description = "Subscription that will host the lab and the state storage."
}

variable "prefix" {
  type        = string
  default     = "lz"
  description = "Short lowercase prefix (max 8 chars) used in names."
  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.prefix))
    error_message = "prefix must be 2-8 lowercase letters/digits."
  }
}

variable "location" {
  type    = string
  default = "eastus2"
}

variable "github_org" {
  type        = string
  description = "GitHub user or org that owns the repo."
}

variable "github_repo" {
  type        = string
  description = "Repository name."
  default     = "azure-landing-zone-lab"
}

variable "github_environments" {
  type    = list(string)
  default = ["production"]
}

variable "grant_tenant_root_access" {
  type        = bool
  default     = true
  description = "Give the pipeline identity MG/Policy/RBAC rights at the tenant root group."
}

variable "graph_app_roles" {
  type        = list(string)
  description = "Microsoft Graph application permissions to grant the pipeline."
  default = [
    "Group.ReadWrite.All",
    "User.Read.All",
    "Policy.Read.All",
    "Policy.ReadWrite.ConditionalAccess",
    "Application.Read.All",
  ]
}

variable "tags" {
  type = map(string)
  default = {
    project    = "azure-landing-zone-lab"
    costCenter = "learning"
    owner      = "platform-team"
  }
}
