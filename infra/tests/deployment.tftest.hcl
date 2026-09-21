# No variable overrides: validate the actual committed infrastructure.tfvars offline.
# Run with terraform test -var-file="infrastructure.tfvars".
mock_provider "powerplatform" {}

# Override only the read-only API boundary; classify the fixture in real HCL.
override_module {
  target = module.power_platform.module.connector_catalog[0]
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

mock_provider "azuread" {
  mock_data "azuread_client_config" {
    defaults = {
      object_id = "11111111-1111-1111-1111-111111111111"
    }
  }
}

run "committed_configuration" {
  command = plan

  assert {
    condition = (
      length(output.environment_ids) == 3 &&
      toset(keys(output.environment_ids)) == toset(keys(output.security_group_ids))
    )
    error_message = "The committed configuration must plan three environments with matching security groups."
  }

  assert {
    condition     = toset(keys(output.dlp_policy_ids)) == toset(keys(output.environment_ids))
    error_message = "The committed configuration must plan one DLP policy per demo environment."
  }
}