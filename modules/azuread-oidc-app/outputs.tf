output "application_client_id" {
  description = "Client ID of the created Azure AD application"
  value       = azuread_application.this.client_id
}

output "application_object_id" {
  description = "Object ID of the Azure AD application"
  value       = azuread_application.this.object_id
}

output "service_principal_object_id" {
  description = "Object ID of the service principal"
  value       = azuread_service_principal.this.object_id
}

output "role_ids" {
  description = "Map of role name -> app role ID, as registered on the service principal"
  value       = azuread_service_principal.this.app_role_ids
}

output "key_vault_secret_names" {
  description = "Names of the secrets written to Key Vault (empty list if publishing is disabled)"
  value = var.publish_secrets_to_keyvault ? [
    azurerm_key_vault_secret.client_secret[0].name,
    azurerm_key_vault_secret.client_id[0].name,
    azurerm_key_vault_secret.allowed_principals[0].name,
  ] : []
}
