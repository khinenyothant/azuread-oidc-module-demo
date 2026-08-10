resource "azuread_service_principal" "this" {
  client_id                    = azuread_application.this.client_id
  app_role_assignment_required = var.require_role_to_signin
}

resource "azuread_app_role_assignment" "this" {
  for_each = local.assignments_by_key

  app_role_id         = azuread_service_principal.this.app_role_ids[each.value.role_name]
  principal_object_id = each.value.principal_object_id
  resource_object_id  = azuread_service_principal.this.object_id
}
