resource "azuread_application" "this" {
  display_name             = var.app_display_name
  owners                    = var.owners
  group_membership_claims   = ["SecurityGroup", "ApplicationGroup"]

  web {
    redirect_uris = var.redirect_uris
  }

  dynamic "app_role" {
    for_each = var.roles
    content {
      id                    = local.role_ids[app_role.value.name]
      value                 = app_role.value.name
      display_name          = app_role.value.name
      description           = coalesce(app_role.value.description, app_role.value.name)
      allowed_member_types  = ["User"]
      enabled               = true
    }
  }
}

resource "time_rotating" "secret_rotation" {
  rotation_days = var.rotate_secret_days
}

resource "azuread_application_password" "this" {
  display_name   = "${var.app_display_name}-secret"
  application_id = azuread_application.this.id

  rotate_when_changed = {
    rotation = time_rotating.secret_rotation.id
  }

  # Mint the replacement secret before the old one is destroyed, so the
  # app never briefly loses a valid client secret during rotation.
  lifecycle {
    create_before_destroy = true
  }
}
