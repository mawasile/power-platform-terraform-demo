mock_provider "powerplatform" {}

variables {
  tenant_settings = {
    disable_environment_creation_by_non_admin_users           = true
    disable_trial_environment_creation_by_non_admin_users     = true
    disable_developer_environment_creation_by_non_admin_users = true
    disable_share_with_everyone                               = true
    disable_connection_sharing_with_everyone                  = true
  }
}

run "governance_disabled" {
  command = plan
  module {
    source = "./modules/power-platform/tenant"
  }
  variables {
    tenant_settings = null
  }
  assert {
    condition     = output.tenant_settings_id == null && length(powerplatform_tenant_settings.governance) == 0
    error_message = "Opting out on a fresh deployment must not manage tenant settings."
  }
}

run "strict_governance" {
  # Only mock providers are used; no tenant settings are changed.
  command = apply
  module {
    source = "./modules/power-platform/tenant"
  }

  assert {
    condition = (
      length(powerplatform_tenant_settings.governance) == 1 &&
      powerplatform_tenant_settings.governance[0].disable_environment_creation_by_non_admin_users &&
      powerplatform_tenant_settings.governance[0].disable_trial_environment_creation_by_non_admin_users &&
      powerplatform_tenant_settings.governance[0].power_platform.governance.disable_developer_environment_creation_by_non_admin_users &&
      powerplatform_tenant_settings.governance[0].power_platform.power_apps.disable_share_with_everyone &&
      powerplatform_tenant_settings.governance[0].power_platform.power_apps.disable_connection_sharing_with_everyone
    )
    error_message = "The selected tenant baseline must enable all five restrictions."
  }
}

run "explicit_false_setting" {
  command = plan
  module {
    source = "./modules/power-platform/tenant"
  }
  variables {
    tenant_settings = {
      disable_environment_creation_by_non_admin_users           = true
      disable_trial_environment_creation_by_non_admin_users     = true
      disable_developer_environment_creation_by_non_admin_users = true
      disable_share_with_everyone                               = false
      disable_connection_sharing_with_everyone                  = true
    }
  }
  assert {
    condition     = powerplatform_tenant_settings.governance[0].power_platform.power_apps.disable_share_with_everyone == false
    error_message = "An explicit false must not be replaced by the baseline default."
  }
}
