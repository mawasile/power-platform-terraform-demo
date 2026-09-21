# Both providers are mocked: no Entra or Power Platform resources are created.
# Keep test fixtures independent of the committed deployment tfvars.
variables {
  location         = "europe"
  macro_region     = null
  enable_dataverse = true
  language_code    = 1033
  currency_code    = "EUR"
  tenant_settings  = null

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

run "without_dataverse" {
  command = plan

  variables {
    enable_dataverse = false
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
    condition     = alltrue([for url in values(output.environment_urls) : url == null])
    error_message = "Environment URLs must be null when Dataverse is disabled."
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

run "reject_wrong_environment_count" {
  command = plan

  variables {
    environments = {
      dev = {
        display_name     = "Only one environment"
        environment_type = "Sandbox"
      }
    }
  }

  expect_failures = [var.environments]
}

run "custom_group_configuration" {
  command = plan

  variables {
    environments = {
      dev = {
        display_name                = "Demo - Dev"
        environment_type            = "Sandbox"
        security_group_display_name = "Custom Dev Access"
        security_group_owner_ids    = ["11111111-1111-1111-1111-111111111111", "55555555-5555-5555-5555-555555555555"]
        security_group_member_ids   = ["66666666-6666-6666-6666-666666666666"]
      }
      test = {
        display_name     = "Demo - Test"
        environment_type = "Sandbox"
      }
      prod = {
        display_name     = "Demo - Prod"
        environment_type = "Production"
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
    condition     = length(module.azure.security_groups["test"].members) == 0 && length(module.azure.security_groups["prod"].members) == 0
    error_message = "Dev members must not be added to test or prod."
  }
}

run "reject_invalid_member_id" {
  command = plan

  variables {
    environments = {
      dev = {
        display_name              = "Demo - Dev"
        environment_type          = "Sandbox"
        security_group_member_ids = ["user@example.com"]
      }
      test = {
        display_name     = "Demo - Test"
        environment_type = "Sandbox"
      }
      prod = {
        display_name     = "Demo - Prod"
        environment_type = "Production"
      }
    }
  }

  expect_failures = [var.environments]
}