# The resource carries a sensitive source url, so expose only the stable fields.
output "deployments" {
  description = "Imported managed solutions, keyed by solution and environment."
  value = {
    for key, solution in powerplatform_managed_solution.deployments : key => {
      environment_id = solution.environment_id
      unique_name    = solution.unique_name
      version        = solution.version
      solution_id    = solution.solution_id
      display_name   = solution.display_name
    }
  }
}

output "solution_ids" {
  description = "Dataverse solution IDs, keyed by solution and environment."
  value = {
    for name, solution in powerplatform_managed_solution.deployments : name => solution.solution_id
  }
}

output "environment_variable_values" {
  description = "Environment variable values set after import, keyed by solution, environment, and schema name."
  value = {
    for key, variable in powerplatform_environment_variable_value.values : key => {
      environment_id = variable.environment_id
      schema_name    = variable.schema_name
      value          = variable.value
    }
  }
  # The provider treats values as sensitive because definitions may be secrets.
  sensitive = true
}
