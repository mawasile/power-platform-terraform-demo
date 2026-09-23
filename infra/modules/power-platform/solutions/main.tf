resource "powerplatform_managed_solution" "deployments" {
  for_each = var.deployments

  environment_id = each.value.environment_id
  unique_name    = each.value.unique_name
  version        = each.value.version

  source = {
    path = each.value.file
  }

  # An empty map is sent as null: the provider round-trips unset collections better.
  connection_references            = length(each.value.connection_references) > 0 ? each.value.connection_references : null
  publish_all_customizations       = each.value.publish_all_customizations
  skip_product_update_dependencies = each.value.skip_product_update_dependencies

  timeouts = {
    create = "60m"
    update = "60m"
  }

  lifecycle {
    precondition {
      condition     = fileexists(each.value.file)
      error_message = "Solution package not found. Commit the exported zip before deploying: ${each.value.file}"
    }
  }
}

locals {
  environment_variables = merge([
    for key, deployment in var.deployments : {
      for schema_name, value in deployment.environment_variables :
      "${key}/${schema_name}" => {
        environment_id = deployment.environment_id
        schema_name    = schema_name
        value          = value
      }
    }
  ]...)
}

resource "powerplatform_environment_variable_value" "values" {
  # Values may be sensitive, which would poison instance keys; iterate the keys,
  # which only contain solution, environment, and schema names.
  for_each = nonsensitive(toset(keys(local.environment_variables)))

  environment_id = local.environment_variables[each.key].environment_id
  schema_name    = local.environment_variables[each.key].schema_name
  value          = local.environment_variables[each.key].value

  # The package ships the definitions, so the import has to land first.
  depends_on = [powerplatform_managed_solution.deployments]
}
