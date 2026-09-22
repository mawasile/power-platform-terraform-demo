# No variable overrides: validate the committed configuration files offline.
# Assertions derive expected keys from var.environments/var.solutions, so adding
# an environment or another solution target never requires editing this file.
mock_provider "powerplatform" {
  # A shared static GUID keeps environment_id attributes format-valid for any
  # number of committed environments; no assertion here relies on ID uniqueness.
  mock_resource "powerplatform_environment" {
    defaults = { id = "cccccccc-cccc-cccc-cccc-cccccccccccc" }
  }
}

mock_provider "azuread" {
  mock_data "azuread_client_config" {
    defaults = {
      object_id = "11111111-1111-1111-1111-111111111111"
    }
  }

  mock_resource "azuread_group" {
    defaults = { object_id = "22222222-2222-2222-2222-222222222222" }
  }
}

run "committed_configuration" {
  # Mock apply resolves IDs so governance-to-environment wiring is tested too.
  command = apply

  assert {
    condition = (
      toset(keys(output.environment_ids)) == toset(keys(var.environments)) &&
      toset(keys(output.environment_ids)) == toset(keys(output.security_group_ids))
    )
    error_message = "Every committed environment must plan with a matching security group."
  }

  assert {
    condition = (
      toset(keys(module.power_platform.managed_environments)) == toset([
        for name, environment in var.environments : name if environment.managed_environment != null
      ]) &&
      module.power_platform.managed_environments["test"].solution_checker_mode == "Warn" &&
      module.power_platform.managed_environments["prod"].solution_checker_mode == "Block" &&
      module.power_platform.managed_environments["test"].max_limit_user_sharing == 20 &&
      module.power_platform.managed_environments["prod"].max_limit_user_sharing == 5 &&
      !module.power_platform.managed_environments["test"].power_automate_is_sharing_disabled &&
      module.power_platform.managed_environments["prod"].power_automate_is_sharing_disabled &&
      !module.power_platform.managed_environments["prod"].copilot_allow_grant_editor_permissions_when_shared &&
      module.power_platform.managed_environments["prod"].copilot_limit_sharing_mode == "DisableSharing"
    )
    error_message = "Production must enforce stronger sharing and solution-checker controls than test; only the configured environments are managed."
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

  assert {
    condition = (
      toset(keys(module.solutions.deployments)) == toset(flatten([
        for name, solution in var.solutions : [for environment in solution.environments : "${name}/${environment}"]
      ])) &&
      alltrue(flatten([
        for name, solution in var.solutions : [
          for environment in solution.environments :
          module.solutions.deployments["${name}/${environment}"].environment_id == output.environment_ids[environment] &&
          module.solutions.deployments["${name}/${environment}"].version == solution.version
        ]
      ]))
    )
    error_message = "Every configured solution must import into exactly its configured environments, at its configured version."
  }

  assert {
    condition = alltrue(flatten([
      for name, solution in var.solutions : [
        for environment, variables in solution.environment_variables : [
          for schema_name, value in variables :
          module.solutions.environment_variable_values["${name}/${environment}/${schema_name}"].value == value &&
          module.solutions.environment_variable_values["${name}/${environment}/${schema_name}"].environment_id == output.environment_ids[environment]
        ]
      ]
    ]))
    error_message = "Every configured environment variable value must match its tfvars value and its own environment."
  }
}