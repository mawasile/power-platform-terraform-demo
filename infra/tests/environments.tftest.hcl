# Both providers are mocked: no Entra or Power Platform resources are created.
# Keep test fixtures independent of the committed deployment tfvars.
variables {
  location         = "europe"
  macro_region     = null
  enable_dataverse = true
  language_code    = 1033
  currency_code    = "EUR"
  tenant_settings  = null

  # Ignore the committed access groups so runs may redefine the environment set.
  environment_access_groups = {}

  # Solution imports target environment keys; keep them out of environment runs.
  solutions = {}

  environments = {
    dev = {
      display_name     = "Demo - Dev"
      environment_type = "Sandbox"
    }
    test = {
      display_name     = "Demo - Test"
      environment_type = "Sandbox"
    }
    prod = {
      display_name     = "Demo - Prod"
      environment_type = "Production"
      settings = {
        audit = {
          plugin_trace_log_setting     = "Off"
          is_audit_enabled             = true
          is_user_access_audit_enabled = true
          is_read_audit_enabled        = false
          log_retention_period_in_days = 365
        }
        max_upload_file_size_in_bytes = 5242880
        blocked_attachment_extensions = ["exe", "ps1"]
      }
      managed_environment = {
        is_group_sharing_disabled                          = true
        limit_sharing_mode                                 = "ExcludeSharingToSecurityGroups"
        max_limit_user_sharing                             = 5
        solution_checker_mode                              = "Block"
        power_automate_is_sharing_disabled                 = true
        copilot_allow_grant_editor_permissions_when_shared = false
        copilot_limit_sharing_mode                         = "DisableSharing"
        copilot_max_limit_user_sharing                     = -1
      }
    }
  }
}

mock_provider "powerplatform" {}

mock_provider "azuread" {
  mock_data "azuread_client_config" {
    defaults = {
      object_id = "11111111-1111-1111-1111-111111111111"
    }
  }
}

# Distinct GUIDs detect cross-wiring and the use of provider paths instead of IDs.
override_resource {
  target = module.azure.azuread_group.environment_access["dev"]
  values = {
    id        = "/groups/22222222-2222-2222-2222-222222222222"
    object_id = "22222222-2222-2222-2222-222222222222"
  }
}

override_resource {
  target = module.azure.azuread_group.environment_access["test"]
  values = {
    id        = "/groups/33333333-3333-3333-3333-333333333333"
    object_id = "33333333-3333-3333-3333-333333333333"
  }
}

override_resource {
  target = module.azure.azuread_group.environment_access["prod"]
  values = {
    id        = "/groups/44444444-4444-4444-4444-444444444444"
    object_id = "44444444-4444-4444-4444-444444444444"
  }
}

run "three_default_environments" {
  # A mocked apply resolves generated group IDs for the cross-module assertions.
  command = apply

  assert {
    condition     = toset(keys(output.environment_ids)) == toset(["dev", "test", "prod"])
    error_message = "The default configuration must create dev, test, and prod."
  }

  assert {
    condition = (
      module.power_platform.environments["dev"].environment_type == "Sandbox" &&
      module.power_platform.environments["test"].environment_type == "Sandbox" &&
      module.power_platform.environments["prod"].environment_type == "Production"
    )
    error_message = "Dev and test must be Sandbox environments, and prod must be Production."
  }

  assert {
    condition = alltrue([
      for name, environment in module.power_platform.environments :
      environment.location == "europe" &&
      environment.dataverse.language_code == 1033 &&
      environment.dataverse.currency_code == "EUR" &&
      environment.dataverse.security_group_id == output.security_group_ids[name]
    ])
    error_message = "Each environment must use its own created Entra group and the configured Dataverse settings."
  }

  assert {
    condition = (
      toset(keys(output.security_group_ids)) == toset(["dev", "test", "prod"]) &&
      length(toset(values(output.security_group_ids))) == 3 &&
      output.security_group_ids["dev"] == "22222222-2222-2222-2222-222222222222" &&
      output.security_group_ids["test"] == "33333333-3333-3333-3333-333333333333" &&
      output.security_group_ids["prod"] == "44444444-4444-4444-4444-444444444444"
    )
    error_message = "Expose three distinct group object IDs, not azuread resource paths."
  }

  assert {
    condition = alltrue([
      for name, group in module.azure.security_groups :
      group.display_name == "${var.environments[name].display_name} - Users" &&
      group.security_enabled && !group.mail_enabled &&
      contains(group.owners, "11111111-1111-1111-1111-111111111111") &&
      length(group.members) == 0
    ])
    error_message = "Default groups must be non-mail-enabled security groups owned by Terraform, with no members."
  }
}

run "without_dataverse_in_dev" {
  command = plan

  variables {
    environments = merge(var.environments, {
      dev = merge(var.environments.dev, { enable_dataverse = false })
    })
  }

  # The provider computes the omitted Dataverse attribute only after a real apply.
  # Check that the no-database configuration plans and exposes no database URLs.
  assert {
    condition     = length(output.environment_ids) == 3
    error_message = "Disabling Dataverse must still plan three environments."
  }

  assert {
    condition     = length(output.security_group_ids) == 3
    error_message = "Groups must remain managed even when Dataverse is disabled."
  }

  assert {
    condition     = output.environment_urls["dev"] == null
    error_message = "Dev must expose no URL when its Dataverse is disabled."
  }

  assert {
    condition     = module.power_platform.environments["prod"].dataverse.currency_code == "EUR"
    error_message = "Disabling dev Dataverse must not disable prod Dataverse."
  }
}

run "macro_region_provisioning" {
  command = plan

  variables {
    macro_region = "eu-efta"
  }

  assert {
    condition = alltrue([
      for environment in module.power_platform.environments : environment.macro_region == "eu-efta"
    ])
    error_message = "All environments must use the configured macro region."
  }
}

run "single_environment" {
  command = plan

  variables {
    environments = {
      dev = {
        display_name     = "Only one environment"
        environment_type = "Sandbox"
      }
    }
  }

  assert {
    condition     = length(output.environment_ids) == 1 && length(output.security_group_ids) == 1
    error_message = "The environment count must not be fixed at three."
  }
}

run "reject_no_environments" {
  command = plan

  variables {
    environments = {}
  }

  expect_failures = [var.environments]
}

run "reject_invalid_environment_key" {
  command = plan

  variables {
    environments = {
      "Dev EU" = {
        display_name     = "Invalid key"
        environment_type = "Sandbox"
      }
    }
  }

  expect_failures = [var.environments]
}

run "custom_group_configuration" {
  command = plan

  variables {
    environment_access_groups = {
      dev = {
        display_name = "Custom Dev Access"
        owner_ids    = ["11111111-1111-1111-1111-111111111111", "55555555-5555-5555-5555-555555555555"]
        member_ids   = ["66666666-6666-6666-6666-666666666666"]
      }
    }
  }

  assert {
    condition = (
      module.azure.security_groups["dev"].display_name == "Custom Dev Access" &&
      toset(module.azure.security_groups["dev"].owners) == toset(["11111111-1111-1111-1111-111111111111", "55555555-5555-5555-5555-555555555555"]) &&
      toset(module.azure.security_groups["dev"].members) == toset(["66666666-6666-6666-6666-666666666666"])
    )
    error_message = "Custom group settings must be respected without duplicating or removing the Terraform owner."
  }

  assert {
    condition = (
      module.azure.security_groups["test"].display_name == "Demo - Test - Users" &&
      length(module.azure.security_groups["test"].members) == 0 &&
      length(module.azure.security_groups["prod"].members) == 0
    )
    error_message = "Environments without an entry must keep the default group name and no members."
  }
}

run "reject_invalid_member_id" {
  command = plan

  variables {
    environment_access_groups = {
      dev = {
        member_ids = ["user@example.com"]
      }
    }
  }

  expect_failures = [var.environment_access_groups]
}

run "reject_unknown_access_group_key" {
  command = plan

  variables {
    environment_access_groups = {
      staging = {
        member_ids = ["66666666-6666-6666-6666-666666666666"]
      }
    }
  }

  expect_failures = [var.environment_access_groups]
}

run "reject_solution_in_dev" {
  command = plan

  variables {
    solutions = {
      SampleSolution = {
        version      = "1.0.0.2"
        file         = "solutions/SampleSolution_managed.zip"
        environments = ["dev", "test"]
      }
    }
  }

  expect_failures = [var.solutions]
}

run "reject_solution_for_unknown_environment" {
  command = plan

  variables {
    solutions = {
      SampleSolution = {
        version      = "1.0.0.2"
        file         = "solutions/SampleSolution_managed.zip"
        environments = ["staging"]
      }
    }
  }

  expect_failures = [var.solutions]
}

run "reject_solution_without_environments" {
  command = plan

  variables {
    solutions = {
      SampleSolution = {
        version      = "1.0.0.2"
        file         = "solutions/SampleSolution_managed.zip"
        environments = []
      }
    }
  }

  expect_failures = [var.solutions]
}

run "reject_values_for_untargeted_environment" {
  command = plan

  variables {
    solutions = {
      SampleSolution = {
        version               = "1.0.0.2"
        file                  = "solutions/SampleSolution_managed.zip"
        environments          = ["test"]
        environment_variables = { prod = { bal_MagicNumber = "7" } }
      }
    }
  }

  expect_failures = [var.solutions]
}

run "per_environment_provisioning_overrides" {
  command = plan

  variables {
    environments = merge(var.environments, {
      dev = merge(var.environments.dev, {
        location      = "unitedstates"
        currency_code = "USD"
        language_code = 1031
      })
      test = merge(var.environments.test, { macro_region = "eu-efta" })
    })
  }

  assert {
    condition = (
      module.power_platform.environments["dev"].location == "unitedstates" &&
      module.power_platform.environments["dev"].dataverse.currency_code == "USD" &&
      module.power_platform.environments["dev"].dataverse.language_code == 1031 &&
      module.power_platform.environments["test"].macro_region == "eu-efta" &&
      module.power_platform.environments["prod"].location == "europe" &&
      module.power_platform.environments["prod"].dataverse.currency_code == "EUR" &&
      module.power_platform.environments["prod"].dataverse.language_code == 1033
    )
    error_message = "Each environment must use only its own overrides, with shared defaults elsewhere."
  }
}

run "additional_environment" {
  command = plan
  variables {
    environments = merge(var.environments, {
      "uat-eu" = {
        display_name     = "Demo - UAT"
        environment_type = "Sandbox"
      }
    })
  }

  assert {
    condition = (
      length(output.environment_ids) == 4 &&
      length(output.security_group_ids) == 4 &&
      module.power_platform.environments["uat-eu"].environment_type == "Sandbox" &&
      module.azure.security_groups["uat-eu"].display_name == "Demo - UAT - Users"
    )
    error_message = "Adding an environment key must create that environment and its access group."
  }

  assert {
    condition     = toset(keys(module.power_platform.managed_environments)) == toset(["prod"])
    error_message = "A new Sandbox environment must not require premium Managed Environment controls."
  }
}

run "reject_weak_additional_production" {
  command = plan
  variables {
    environments = merge(var.environments, {
      "prod-eu" = {
        display_name     = "Demo - Prod EU"
        environment_type = "Production"
      }
    })
  }
  expect_failures = [var.environments]
}

run "additional_production_with_strict_baseline" {
  command = plan
  variables {
    environments = merge(var.environments, {
      "prod-eu" = merge(var.environments.prod, { display_name = "Demo - Prod EU" })
    })
  }

  assert {
    condition = (
      module.power_platform.managed_environments["prod-eu"].solution_checker_mode == "Block" &&
      module.power_platform.environment_settings["prod-eu"].audit_and_logs.audit_settings.is_user_access_audit_enabled
    )
    error_message = "A second Production environment must carry the same strict baseline."
  }
}

run "reject_unmanaged_production" {
  command = plan
  variables {
    environments = merge(var.environments, {
      prod = merge(var.environments.prod, { managed_environment = null })
    })
  }
  expect_failures = [var.environments]
}

run "reject_production_auditing_disabled" {
  command = plan
  variables {
    environments = merge(var.environments, {
      prod = merge(var.environments.prod, {
        settings = merge(var.environments.prod.settings, { audit = null })
      })
    })
  }
  expect_failures = [var.environments]
}

run "reject_production_without_blocked_attachments" {
  command = plan
  variables {
    environments = merge(var.environments, {
      prod = merge(var.environments.prod, {
        settings = merge(var.environments.prod.settings, { blocked_attachment_extensions = null })
      })
    })
  }
  expect_failures = [var.environments]
}

run "reject_production_warning_only_checker" {
  command = plan
  variables {
    environments = merge(var.environments, {
      prod = merge(var.environments.prod, {
        managed_environment = merge(var.environments.prod.managed_environment, { solution_checker_mode = "Warn" })
      })
    })
  }
  expect_failures = [var.environments]
}

run "reject_production_broad_sharing" {
  command = plan
  variables {
    environments = merge(var.environments, {
      prod = merge(var.environments.prod, {
        managed_environment = merge(var.environments.prod.managed_environment, { max_limit_user_sharing = 20 })
      })
    })
  }
  expect_failures = [var.environments]
}

run "reject_production_access_logging_disabled" {
  command = plan
  variables {
    environments = merge(var.environments, {
      prod = merge(var.environments.prod, {
        settings = merge(var.environments.prod.settings, {
          audit = merge(var.environments.prod.settings.audit, { is_user_access_audit_enabled = false })
        })
      })
    })
  }
  expect_failures = [var.environments]
}

run "reject_production_flow_sharing" {
  command = plan
  variables {
    environments = merge(var.environments, {
      prod = merge(var.environments.prod, {
        managed_environment = merge(var.environments.prod.managed_environment, { power_automate_is_sharing_disabled = false })
      })
    })
  }
  expect_failures = [var.environments]
}

run "reject_production_agent_editor_sharing" {
  command = plan
  variables {
    environments = merge(var.environments, {
      prod = merge(var.environments.prod, {
        managed_environment = merge(var.environments.prod.managed_environment, { copilot_allow_grant_editor_permissions_when_shared = true })
      })
    })
  }
  expect_failures = [var.environments]
}

run "reject_production_agent_viewer_sharing" {
  command = plan
  variables {
    environments = merge(var.environments, {
      prod = merge(var.environments.prod, {
        managed_environment = merge(var.environments.prod.managed_environment, { copilot_limit_sharing_mode = "NoLimit" })
      })
    })
  }
  expect_failures = [var.environments]
}