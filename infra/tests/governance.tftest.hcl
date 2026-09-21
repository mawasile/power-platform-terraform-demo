mock_provider "powerplatform" {}

override_module {
  target = module.connector_catalog[0]
  outputs = {
    connectors = [
      { id = "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps", unblockable = true },
      { id = "/providers/Microsoft.PowerApps/apis/shared_sharepointonline", unblockable = true },
      { id = "/providers/Microsoft.PowerApps/apis/shared_office365", unblockable = true },
      { id = "/providers/Microsoft.PowerApps/apis/shared_teams", unblockable = true },
      { id = "/providers/Microsoft.PowerApps/apis/shared_onedriveforbusiness", unblockable = true },
      { id = "/providers/Microsoft.PowerApps/apis/shared_approvals", unblockable = true },
      { id = "/providers/Microsoft.PowerApps/apis/shared_dropbox", unblockable = false },
      { id = "/providers/Microsoft.PowerApps/apis/shared_http", unblockable = false },
    ]
  }
}

variables {
  location         = "europe"
  enable_dataverse = true
  language_code    = 1033
  currency_code    = "EUR"
  environments = {
    dev = {
      display_name      = "Demo - Dev"
      environment_type  = "Sandbox"
      security_group_id = "22222222-2222-2222-2222-222222222222"
    }
    test = {
      display_name      = "Demo - Test"
      environment_type  = "Sandbox"
      security_group_id = "33333333-3333-3333-3333-333333333333"
    }
    prod = {
      display_name      = "Demo - Prod"
      environment_type  = "Production"
      security_group_id = "44444444-4444-4444-4444-444444444444"
    }
  }
  tenant_settings = {
    disable_environment_creation_by_non_admin_users           = true
    disable_trial_environment_creation_by_non_admin_users     = true
    disable_developer_environment_creation_by_non_admin_users = true
    disable_share_with_everyone                               = true
    disable_connection_sharing_with_everyone                  = true
  }
  dlp_policies = {
    dev = {
      display_name           = "Dev policy"
      business_connector_ids = ["/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"]
    }
    test = {
      display_name = "Test policy"
      business_connector_ids = [
        "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps",
        "/providers/Microsoft.PowerApps/apis/shared_sharepointonline",
      ]
    }
    prod = {
      display_name           = "Prod policy"
      business_connector_ids = ["/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"]
    }
  }
}

run "governance_disabled" {
  command = plan
  module {
    source = "./modules/power-platform"
  }
  variables {
    tenant_settings = null
    dlp_policies    = {}
  }
  assert {
    condition = (
      output.tenant_settings_id == null && length(output.dlp_policy_ids) == 0 &&
      length(module.connector_catalog) == 0
    )
    error_message = "Opting out on a fresh deployment must not manage settings, policies, or query connectors."
  }
}

run "strict_governance" {
  # Only mock providers are used. Apply resolves environment IDs for scope checks.
  command = apply
  module {
    source = "./modules/power-platform"
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

  assert {
    condition = length(output.dlp_policy_ids) == 3 && alltrue([
      for name, policy in powerplatform_data_loss_prevention_policy.environment :
      policy.environment_type == "OnlyEnvironments" &&
      policy.environments == toset([powerplatform_environment.environments[name].id]) &&
      policy.default_connectors_classification == "Blocked"
    ])
    error_message = "Each policy must target exactly its matching managed environment and block new blockable connectors."
  }

  assert {
    condition = alltrue([
      for name, policy in powerplatform_data_loss_prevention_policy.environment :
      toset([for c in policy.business_connectors : c.id]) == var.dlp_policies[name].business_connector_ids &&
      toset([for c in policy.non_business_connectors : c.id]) == setsubtract(local.unblockable_connector_ids, var.dlp_policies[name].business_connector_ids) &&
      toset([for c in policy.blocked_connectors : c.id]) == toset([
        "/providers/Microsoft.PowerApps/apis/shared_dropbox",
        "/providers/Microsoft.PowerApps/apis/shared_http",
      ]) &&
      length(policy.business_connectors) + length(policy.non_business_connectors) + length(policy.blocked_connectors) == 8
    ])
    error_message = "Catalog connectors must be classified exactly once; unblockable connectors must never be Blocked."
  }

  assert {
    condition = alltrue([
      for policy in powerplatform_data_loss_prevention_policy.environment :
      length(policy.custom_connectors_patterns) == 1 && alltrue([
        for pattern in policy.custom_connectors_patterns :
        pattern.host_url_pattern == "*" && pattern.data_group == "Blocked" && pattern.order == 1
      ])
    ])
    error_message = "Every custom connector host must be blocked, not ignored."
  }
}

run "explicit_false_setting" {
  command = plan
  module {
    source = "./modules/power-platform"
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

run "reject_external_environment" {
  command = plan
  module {
    source = "./modules/power-platform"
  }
  variables {
    dlp_policies = {
      external = {
        display_name           = "Invalid scope"
        business_connector_ids = ["/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"]
      }
    }
  }
  expect_failures = [powerplatform_data_loss_prevention_policy.environment]
}

run "reject_unknown_connector" {
  command = plan
  module {
    source = "./modules/power-platform"
  }
  variables {
    dlp_policies = {
      dev = {
        display_name           = "Typo in allowlist"
        business_connector_ids = ["/providers/Microsoft.PowerApps/apis/shared_does_not_exist"]
      }
    }
  }
  expect_failures = [powerplatform_data_loss_prevention_policy.environment]
}

run "reject_empty_catalog" {
  command = plan
  module {
    source = "./modules/power-platform"
  }
  override_module {
    target  = module.connector_catalog[0]
    outputs = { connectors = [] }
  }
  expect_failures = [powerplatform_data_loss_prevention_policy.environment]
}

run "duplicate_connector_ids" {
  command = plan
  module {
    source = "./modules/power-platform"
  }
  override_module {
    target = module.connector_catalog[0]
    outputs = {
      connectors = [
        { id = "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps", unblockable = true },
        { id = "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps", unblockable = true },
        { id = "/providers/Microsoft.PowerApps/apis/shared_sharepointonline", unblockable = true },
        { id = "/providers/Microsoft.PowerApps/apis/shared_dynamics365marketing", unblockable = false },
        { id = "/providers/Microsoft.PowerApps/apis/shared_dynamics365marketing", unblockable = false },
        { id = "/providers/Microsoft.PowerApps/apis/shared_d365marketingforapps", unblockable = false },
        { id = "/providers/Microsoft.PowerApps/apis/shared_d365marketingforapps", unblockable = false },
        { id = "/providers/Microsoft.PowerApps/apis/shared_approvals", unblockable = true },
        { id = "/providers/Microsoft.PowerApps/apis/shared_approvals", unblockable = false },
        { id = "/providers/Microsoft.PowerApps/apis/shared_http", unblockable = false },
      ]
    }
  }
  assert {
    condition = alltrue([
      for name, policy in powerplatform_data_loss_prevention_policy.environment :
      toset([for c in policy.business_connectors : c.id]) == var.dlp_policies[name].business_connector_ids &&
      contains([for c in policy.non_business_connectors : c.id], "/providers/Microsoft.PowerApps/apis/shared_approvals") &&
      toset([for c in policy.blocked_connectors : c.id]) == toset([
        "/providers/Microsoft.PowerApps/apis/shared_dynamics365marketing",
        "/providers/Microsoft.PowerApps/apis/shared_d365marketingforapps",
        "/providers/Microsoft.PowerApps/apis/shared_http",
      ]) &&
      length(policy.business_connectors) + length(policy.non_business_connectors) + length(policy.blocked_connectors) == 6
    ])
    error_message = "Duplicate catalog IDs must be classified once; any unblockable entry must keep that connector out of Blocked."
  }
}