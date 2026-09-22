# No variable overrides: validate all three committed configuration files offline.
# Pass infrastructure.tfvars, config/environments.tfvars, and config/tenant.tfvars.
mock_provider "powerplatform" {}

mock_provider "azuread" {
  mock_data "azuread_client_config" {
    defaults = {
      object_id = "11111111-1111-1111-1111-111111111111"
    }
  }
}

override_resource {
  target = module.azure.azuread_group.environment_access["dev"]
  values = { object_id = "22222222-2222-2222-2222-222222222222" }
}

override_resource {
  target = module.azure.azuread_group.environment_access["test"]
  values = { object_id = "33333333-3333-3333-3333-333333333333" }
}

override_resource {
  target = module.azure.azuread_group.environment_access["prod"]
  values = { object_id = "44444444-4444-4444-4444-444444444444" }
}

override_resource {
  target = module.power_platform.powerplatform_environment.environments["dev"]
  values = { id = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" }
}

override_resource {
  target = module.power_platform.powerplatform_environment.environments["test"]
  values = { id = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb" }
}

override_resource {
  target = module.power_platform.powerplatform_environment.environments["prod"]
  values = { id = "cccccccc-cccc-cccc-cccc-cccccccccccc" }
}

run "committed_configuration" {
  # Mock apply resolves IDs so governance-to-environment wiring is tested too.
  command = apply

  assert {
    condition = (
      length(output.environment_ids) == 3 &&
      toset(keys(output.environment_ids)) == toset(keys(output.security_group_ids))
    )
    error_message = "The committed configuration must plan three environments with matching security groups."
  }

  assert {
    condition = (
      toset(keys(module.power_platform.managed_environments)) == toset(["test", "prod"]) &&
      module.power_platform.managed_environments["test"].solution_checker_mode == "Warn" &&
      module.power_platform.managed_environments["prod"].solution_checker_mode == "Block" &&
      module.power_platform.managed_environments["test"].max_limit_user_sharing == 20 &&
      module.power_platform.managed_environments["prod"].max_limit_user_sharing == 5 &&
      !module.power_platform.managed_environments["test"].power_automate_is_sharing_disabled &&
      module.power_platform.managed_environments["prod"].power_automate_is_sharing_disabled &&
      !module.power_platform.managed_environments["prod"].copilot_allow_grant_editor_permissions_when_shared &&
      module.power_platform.managed_environments["prod"].copilot_limit_sharing_mode == "DisableSharing"
    )
    error_message = "Production must enforce stronger sharing and solution-checker controls than test; dev must not be managed."
  }

  assert {
    condition = (
      module.power_platform.environment_settings["dev"].audit_and_logs.audit_settings.log_retention_period_in_days == 31 &&
      module.power_platform.environment_settings["test"].audit_and_logs.audit_settings.log_retention_period_in_days == 90 &&
      module.power_platform.environment_settings["prod"].audit_and_logs.audit_settings.log_retention_period_in_days == 365 &&
      module.power_platform.environment_settings["prod"].audit_and_logs.audit_settings.is_user_access_audit_enabled &&
      module.power_platform.environment_settings["prod"].audit_and_logs.plugin_trace_log_setting == "Off"
    )
    error_message = "The committed environments must have distinct audit policies and production access logging."
  }

  assert {
    condition = (
      module.power_platform.environment_settings["dev"].email.email_settings.max_upload_file_size_in_bytes == 33554432 &&
      module.power_platform.environment_settings["test"].email.email_settings.max_upload_file_size_in_bytes == 16777216 &&
      module.power_platform.environment_settings["prod"].email.email_settings.max_upload_file_size_in_bytes == 5242880 &&
      contains(module.power_platform.environment_settings["prod"].privacy_and_security.blocked_attachment_extensions, "exe") &&
      length(module.power_platform.environment_settings["prod"].privacy_and_security.blocked_attachment_extensions) >
      length(module.power_platform.environment_settings["test"].privacy_and_security.blocked_attachment_extensions)
    )
    error_message = "Production must have the smallest upload limit and the longest blocked attachment list."
  }

  assert {
    condition = alltrue([
      for name, settings in module.power_platform.environment_settings : settings.environment_id == output.environment_ids[name]
      ]) && alltrue([
      for name, settings in module.power_platform.managed_environments : settings.environment_id == output.environment_ids[name]
    ])
    error_message = "Governance must reference its own environment, not another environment's ID."
  }

  assert {
    condition     = output.tenant_settings_id != null && output.tenant_settings_id == module.tenant.tenant_settings_id
    error_message = "The tenant baseline must remain managed by the separate tenant module."
  }
}