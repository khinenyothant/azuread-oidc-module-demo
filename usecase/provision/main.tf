terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azuread = { source = "hashicorp/azuread", version = "~> 2.47" }
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.90" }
    time    = { source = "hashicorp/time", version = "~> 0.10" }
  }
}

provider "azuread" {}
provider "azurerm" {
  features {}
}

module "oidc_app" {
  source = "../../modules/azuread-oidc-app"

  app_display_name = var.app_display_name
  owners           = var.azuread_group_owners
  redirect_uris    = var.redirect_uris

  roles = [
    { name = "Admin", description = "Application admins" },
    { name = "User",  description = "Regular application users" },
  ]

  role_assignments = {
    Admin = [var.app_admins]
    User  = [var.app_users]
  }

  require_role_to_signin = var.require_role_to_signin
  keyvault_id            = var.keyvault_id
  secret_name_prefix     = var.app_display_name
  tags                   = { App = var.app_display_name }
}
