locals {
  # One import per solution and target environment; file paths are repository relative.
  solution_deployments = merge([
    for name, solution in var.solutions : {
      for environment in solution.environments :
      "${name}/${environment}" => {
        environment_id                   = module.power_platform.environment_ids[environment]
        unique_name                      = name
        version                          = solution.version
        file                             = "${path.root}/../${solution.file}"
        environment_variables            = lookup(solution.environment_variables, environment, {})
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
