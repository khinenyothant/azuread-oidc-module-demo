variable "app_display_name" {
  type        = string
  description = "Display name of the Azure AD application"
  default     = "app-my-oidc-app"
}

variable "redirect_uris" {
  type        = list(string)
  description = "OIDC redirect URIs for the application"
  default     = ["https://my-app.example.com/auth/callback"]
}

variable "require_role_to_signin" {
  type        = bool
  description = "Require an assigned role to sign in (recommended for prod)"
  default     = false
}

variable "keyvault_id" {
  type        = string
  description = "Resource ID of the Key Vault to publish credentials to"
}

variable "azuread_group_owners" {
  type        = list(string)
  description = "Object IDs of the AAD group owners for the app registration"
}

variable "app_admins" {
  type        = string
  description = "Object ID of the AAD group for Admin role"
}

variable "app_users" {
  type        = string
  description = "Object ID of the AAD group for User role"
}

output "application_client_id" {
  value = module.oidc_app.application_client_id
}

output "role_ids" {
  value = module.oidc_app.role_ids
}
