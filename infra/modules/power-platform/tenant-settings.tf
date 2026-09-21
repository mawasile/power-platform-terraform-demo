resource "powerplatform_tenant_settings" "governance" {
  count = var.tenant_settings == null ? 0 : 1

  disable_environment_creation_by_non_admin_users       = var.tenant_settings.disable_environment_creation_by_non_admin_users
  disable_trial_environment_creation_by_non_admin_users = var.tenant_settings.disable_trial_environment_creation_by_non_admin_users

  # Leave unrelated tenant settings unconfigured, including AI and licensing.
  power_platform = {
    governance = {
      disable_developer_environment_creation_by_non_admin_users = var.tenant_settings.disable_developer_environment_creation_by_non_admin_users
    }
    power_apps = {
      disable_share_with_everyone              = var.tenant_settings.disable_share_with_everyone
      disable_connection_sharing_with_everyone = var.tenant_settings.disable_connection_sharing_with_everyone
    }
  }

  # The provider's delete operation can restore pre-management settings.
  lifecycle {
    prevent_destroy = true
  }
}