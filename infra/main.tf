module "azure" {
  source = "./modules/azure"

  security_groups = {
    for name, environment in var.environments : name => {
      display_name = coalesce(environment.security_group_display_name, "${environment.display_name} - Users")
      owner_ids    = environment.security_group_owner_ids
      member_ids   = environment.security_group_member_ids
    }
  }
}

module "power_platform" {
  # Keep this module label so existing environment state addresses stay stable.
  source = "./modules/power-platform/environments"

  environments = {
    for name, environment in var.environments : name => merge(environment, {
      security_group_id = module.azure.security_group_ids[name]
    })
  }

  location         = var.location
  macro_region     = var.macro_region
  enable_dataverse = var.enable_dataverse
  language_code    = var.language_code
  currency_code    = var.currency_code
}
