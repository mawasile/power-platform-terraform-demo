# Test the reusable environment module independently of this demo's prod policy.
mock_provider "powerplatform" {
  mock_resource "powerplatform_environment" {
    defaults = { id = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" }
  }
}

variables {
  location         = "europe"
  enable_dataverse = true
  language_code    = 1033
  currency_code    = "EUR"
  environments = {
    sample = {
      display_name      = "Isolated module test"
      environment_type  = "Sandbox"
      security_group_id = "22222222-2222-2222-2222-222222222222"
      settings = {
        audit = {
          plugin_trace_log_setting     = "Exception"
          is_audit_enabled             = true
          is_user_access_audit_enabled = false
          is_read_audit_enabled        = false
          log_retention_period_in_days = 31
        }
        max_upload_file_size_in_bytes = 16777216
        blocked_attachment_extensions = ["exe", "ps1"]
      }
      managed_environment = {
        is_group_sharing_disabled                          = true
        limit_sharing_mode                                 = "ExcludeSharingToSecurityGroups"
        max_limit_user_sharing                             = 20
        solution_checker_mode                              = "Warn"
        power_automate_is_sharing_disabled                 = false
        copilot_allow_grant_editor_permissions_when_shared = true
        copilot_limit_sharing_mode                         = "ExcludeSharingToSecurityGroups"
        copilot_max_limit_user_sharing                     = 20
      }
    }
  }
}

run "governance_is_environment_scoped" {
  command = apply
  module { source = "./modules/power-platform/environments" }

  assert {
    condition = (
      powerplatform_environment_settings.environments["sample"].environment_id == output.environment_ids["sample"] &&
      powerplatform_environment_settings.environments["sample"].email.email_settings.max_upload_file_size_in_bytes == 16777216 &&
      toset(powerplatform_environment_settings.environments["sample"].privacy_and_security.blocked_attachment_extensions) == toset(["exe", "ps1"]) &&
      powerplatform_managed_environment.environments["sample"].environment_id == output.environment_ids["sample"] &&
      powerplatform_managed_environment.environments["sample"].is_usage_insights_disabled &&
      !powerplatform_managed_environment.environments["sample"].suppress_validation_emails
    )
    error_message = "Governance must use its environment ID and documented optional defaults."
  }
}

run "no_dataverse_without_governance" {
  command = plan
  module { source = "./modules/power-platform/environments" }
  variables {
    environments = {
      sample = merge(var.environments.sample, {
        enable_dataverse    = false
        settings            = null
        managed_environment = null
      })
    }
  }
  assert {
    condition = (
      length(output.environment_settings) == 0 &&
      length(output.managed_environments) == 0 &&
      output.environment_urls["sample"] == null
    )
    error_message = "Optional governance must not create settings resources when absent."
  }
}

run "reject_governance_without_dataverse" {
  command = plan
  module { source = "./modules/power-platform/environments" }
  variables {
    environments = { sample = merge(var.environments.sample, { enable_dataverse = false }) }
  }
  expect_failures = [powerplatform_environment.environments]
}

run "forever_retention" {
  command = plan
  module { source = "./modules/power-platform/environments" }
  variables {
    environments = {
      sample = merge(var.environments.sample, {
        settings = merge(var.environments.sample.settings, {
          audit = merge(var.environments.sample.settings.audit, { log_retention_period_in_days = -1 })
        })
      })
    }
  }
  assert {
    condition     = powerplatform_environment_settings.environments["sample"].audit_and_logs.audit_settings.log_retention_period_in_days == -1
    error_message = "The provider's forever-retention sentinel must be supported."
  }
}

run "reject_short_retention" {
  command = plan
  module { source = "./modules/power-platform/environments" }
  variables {
    environments = {
      sample = merge(var.environments.sample, {
        settings = merge(var.environments.sample.settings, {
          audit = merge(var.environments.sample.settings.audit, { log_retention_period_in_days = 30 })
        })
      })
    }
  }
  expect_failures = [var.environments]
}

run "reject_fractional_retention" {
  command = plan
  module { source = "./modules/power-platform/environments" }
  variables {
    environments = {
      sample = merge(var.environments.sample, {
        settings = merge(var.environments.sample.settings, {
          audit = merge(var.environments.sample.settings.audit, { log_retention_period_in_days = 31.5 })
        })
      })
    }
  }
  expect_failures = [var.environments]
}

run "reject_access_logging_without_auditing" {
  command = plan
  module { source = "./modules/power-platform/environments" }
  variables {
    environments = {
      sample = merge(var.environments.sample, {
        settings = merge(var.environments.sample.settings, {
          audit = merge(var.environments.sample.settings.audit, { is_audit_enabled = false, is_user_access_audit_enabled = true })
        })
      })
    }
  }
  expect_failures = [var.environments]
}

run "reject_unknown_trace_mode" {
  command = plan
  module { source = "./modules/power-platform/environments" }
  variables {
    environments = {
      sample = merge(var.environments.sample, {
        settings = merge(var.environments.sample.settings, {
          audit = merge(var.environments.sample.settings.audit, { plugin_trace_log_setting = "Verbose" })
        })
      })
    }
  }
  expect_failures = [var.environments]
}

run "reject_inconsistent_canvas_sharing" {
  command = plan
  module { source = "./modules/power-platform/environments" }
  variables {
    environments = {
      sample = merge(var.environments.sample, {
        managed_environment = merge(var.environments.sample.managed_environment, { is_group_sharing_disabled = false })
      })
    }
  }
  expect_failures = [var.environments]
}

run "reject_unknown_checker_mode" {
  command = plan
  module { source = "./modules/power-platform/environments" }
  variables {
    environments = {
      sample = merge(var.environments.sample, {
        managed_environment = merge(var.environments.sample.managed_environment, { solution_checker_mode = "Audit" })
      })
    }
  }
  expect_failures = [var.environments]
}

run "reject_fractional_sharing_limit" {
  command = plan
  module { source = "./modules/power-platform/environments" }
  variables {
    environments = {
      sample = merge(var.environments.sample, {
        managed_environment = merge(var.environments.sample.managed_environment, { max_limit_user_sharing = 1.5 })
      })
    }
  }
  expect_failures = [var.environments]
}

run "settings_groups_are_independent" {
  command = plan
  module { source = "./modules/power-platform/environments" }
  variables {
    environments = {
      sample = merge(var.environments.sample, {
        settings = { max_upload_file_size_in_bytes = 1048576 }
      })
    }
  }
  # Omitted groups are computed, so they keep the environment's current values.
  assert {
    condition     = powerplatform_environment_settings.environments["sample"].email.email_settings.max_upload_file_size_in_bytes == 1048576
    error_message = "Each settings group must be configurable without the others."
  }
}

run "reject_oversized_upload_limit" {
  command = plan
  module { source = "./modules/power-platform/environments" }
  variables {
    environments = {
      sample = merge(var.environments.sample, {
        settings = merge(var.environments.sample.settings, { max_upload_file_size_in_bytes = 268435456 })
      })
    }
  }
  expect_failures = [var.environments]
}

run "reject_empty_blocked_extensions" {
  command = plan
  module { source = "./modules/power-platform/environments" }
  variables {
    environments = {
      sample = merge(var.environments.sample, {
        settings = merge(var.environments.sample.settings, { blocked_attachment_extensions = [] })
      })
    }
  }
  expect_failures = [var.environments]
}

run "reject_dotted_blocked_extension" {
  command = plan
  module { source = "./modules/power-platform/environments" }
  variables {
    environments = {
      sample = merge(var.environments.sample, {
        settings = merge(var.environments.sample.settings, { blocked_attachment_extensions = [".exe"] })
      })
    }
  }
  expect_failures = [var.environments]
}