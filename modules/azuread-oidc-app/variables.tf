variable "app_display_name" {
  description = "Display name of the Azure AD application (e.g. \"app-we-prod-grafana\")"
  type        = string
}

variable "owners" {
  description = "Object ID(s) of the owners for the Azure AD application"
  type        = list(string)
}

variable "redirect_uris" {
  description = "OAuth2/OIDC redirect URIs for the app's web platform"
  type        = list(string)
}

variable "roles" {
  description = "App roles to create. \"name\" becomes the role value your app checks against (e.g. \"Admin\")."
  type = list(object({
    name        = string
    description = optional(string)
  }))
}

variable "role_assignments" {
  description = "Map of role name -> list of AAD principal (user or group) object IDs to assign that role to. Keys must match a name in var.roles."
  type        = map(list(string))
  default     = {}
}

variable "require_role_to_signin" {
  description = "If true, a user/group must have an assigned app role to sign in at all. Typically true for prod, false for lower environments."
  type        = bool
  default     = false
}

variable "rotate_secret_days" {
  description = "How often the client secret is automatically rotated"
  type        = number
  default     = 30
}

variable "publish_secrets_to_keyvault" {
  description = "Whether to write the client ID, client secret, and allowed-principals list to Key Vault"
  type        = bool
  default     = true
}

variable "keyvault_id" {
  description = "Resource ID of the Key Vault to publish secrets to. Required if publish_secrets_to_keyvault is true."
  type        = string
  default     = null

  validation {
    condition     = !var.publish_secrets_to_keyvault || var.keyvault_id != null
    error_message = "keyvault_id must be set when publish_secrets_to_keyvault is true."
  }
}

variable "secret_name_prefix" {
  description = "Prefix used for the three Key Vault secret names (e.g. app short name)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to created Key Vault secrets"
  type        = map(string)
  default     = {}
}
