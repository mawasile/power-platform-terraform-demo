# No variable overrides: validate the actual committed terraform.tfvars offline.
mock_provider "powerplatform" {}

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
}