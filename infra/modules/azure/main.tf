data "azuread_client_config" "current" {}

resource "azuread_group" "environment_access" {
  for_each = var.security_groups

  display_name     = each.value.display_name
  description      = "Access group for the ${each.key} Power Platform environment. Managed by Terraform."
  security_enabled = true
  mail_enabled     = false

  # Retain the Terraform principal as an owner so it can manage the group.
  owners  = setunion([data.azuread_client_config.current.object_id], each.value.owner_ids)
  members = each.value.member_ids
}