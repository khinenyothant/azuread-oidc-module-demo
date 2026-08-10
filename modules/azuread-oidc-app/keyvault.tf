resource "azurerm_key_vault_secret" "client_secret" {
  count = var.publish_secrets_to_keyvault ? 1 : 0

  name         = "${local.secret_name_prefix}-client-secret"
  value        = azuread_application_password.this.value
  key_vault_id = var.keyvault_id
  content_type = "password"
  tags         = var.tags
}

resource "azurerm_key_vault_secret" "client_id" {
  count = var.publish_secrets_to_keyvault ? 1 : 0

  name         = "${local.secret_name_prefix}-client-id"
  value        = azuread_application.this.client_id
  key_vault_id = var.keyvault_id
  content_type = "text/plain"
  tags         = var.tags
}

# Note: this reflects the *variables* passed in, not the live
# azuread_app_role_assignment resources — keep the two in sync yourself
# if you rely on this secret for downstream authorization logic.
resource "azurerm_key_vault_secret" "allowed_principals" {
  count = var.publish_secrets_to_keyvault ? 1 : 0

  name         = "${local.secret_name_prefix}-allowed-principals"
  value        = join(",", local.all_assigned_principals)
  key_vault_id = var.keyvault_id
  content_type = "text/plain"
  tags         = var.tags
}
