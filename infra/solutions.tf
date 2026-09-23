locals {
  # One import per solution and target environment; file paths are repository relative.
  solution_deployments = merge([
    for name, solution in var.solutions : {
      for environment in solution.environments :
      "${name}/${environment}" => {
        environment_id = module.power_platform.environment_ids[environment]
        unique_name    = name
        version        = solution.version
        file           = "${path.root}/../${solution.file}"
        # sensitive() keeps the marking consistent whether or not secrets are supplied,
        # so the module can always strip it from the keys it iterates.
        environment_variables = sensitive(merge(
          lookup(solution.environment_variables, environment, {}),
          try(var.solution_secrets[name][environment], {})
        ))
        connection_references            = solution.connection_references
        publish_all_customizations       = solution.publish_all_customizations
        skip_product_update_dependencies = solution.skip_product_update_dependencies
      }
    }
  ]...)
}

module "solutions" {
  source = "./modules/power-platform/solutions"

  deployments = local.solution_deployments
}
