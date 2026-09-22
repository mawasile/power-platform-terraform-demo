locals {
  environments = {
    for name, environment in var.environments : name => merge(environment, {
      location         = coalesce(environment.location, var.location)
      macro_region     = environment.macro_region == null ? var.macro_region : environment.macro_region
      enable_dataverse = coalesce(environment.enable_dataverse, var.enable_dataverse)
      language_code    = coalesce(environment.language_code, var.language_code)
      currency_code    = coalesce(environment.currency_code, var.currency_code)
    })
  }
}

resource "powerplatform_environment" "environments" {
  for_each = local.environments

  display_name     = each.value.display_name
  description      = "${each.key} environment managed by Terraform."
  environment_type = each.value.environment_type
  location         = each.value.macro_region == null ? each.value.location : null
  macro_region     = each.value.macro_region

  # Dataverse requires available tenant database capacity and appropriate licensing.
  dataverse = each.value.enable_dataverse ? {
    language_code     = each.value.language_code
    currency_code     = each.value.currency_code
    security_group_id = each.value.security_group_id
  } : null

  lifecycle {
    precondition {
      condition     = each.value.enable_dataverse || (each.value.settings == null && each.value.managed_environment == null)
      error_message = "Environment settings and Managed Environments require Dataverse. Remove them before disabling Dataverse on a fresh deployment."
    }
  }
}