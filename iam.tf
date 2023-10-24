data azurerm_subscription "current" { }

resource "azurerm_role_definition" "restartonly" {
  name = "restartonly"

  scope = data.azurerm_subscription.current.id

  permissions {
    actions     = [
			"Microsoft.Compute/*/read",
			"Microsoft.Compute/virtualMachineScaleSets/restart/action",
		]
    not_actions = []
  }
	assignable_scopes = [data.azurerm_subscription.current.id]
}

resource "azurerm_role_assignment" "restartonly" {
	scope = azurerm_linux_virtual_machine_scale_set.vmss.id
  role_definition_name = azurerm_role_definition.restartonly.name
	principal_id         = azuread_user.users.id
}

provider "azuread" {}

data "azuread_domains" "default" {
  only_initial = true
}
locals {
  domain_name = data.azuread_domains.default.domains.0.domain_name
}

# Create users
resource "azuread_user" "users" {
	user_principal_name = "restart@${local.domain_name}"
	password            = "SecretP@sswd99!"
  force_password_change = true

  display_name = "RestartOnly VM"
  department   = "DevOps"
  job_title    = "VM Operator"
}