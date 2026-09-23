variable "solutions" {
  description = "Managed solution packages to import, keyed by the solution unique name from the package. Each entry lists the environments that receive it and any non-secret environment variable values."
  type = map(object({
    version                          = string
    file                             = string
    environments                     = set(string)
    environment_variables            = optional(map(map(string)), {})
    connection_references            = optional(map(string), {})
    publish_all_customizations       = optional(bool, false)
    skip_product_update_dependencies = optional(bool, false)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for name in keys(var.solutions) : can(regex("^[A-Za-z_][A-Za-z0-9_]{0,63}$", name))
    ])
    error_message = "Each key must be the solution unique name from the package, using letters, digits, and underscores only."
  }

  validation {
    condition = alltrue(flatten([
      for solution in var.solutions : [
        for name in solution.environments : contains(keys(var.environments), name)
      ]
    ]))
    error_message = "Each solution may only target environment keys defined in config/environments.tfvars."
  }

  validation {
    condition = alltrue([
      for solution in var.solutions : length(solution.environments) > 0
    ])
    error_message = "Each solution must target at least one environment."
  }

  # Importing into the authoring environment would layer a managed solution over its unmanaged source.
  validation {
    condition = alltrue([
      for solution in var.solutions : !contains(solution.environments, "dev")
    ])
    error_message = "Deploy managed solutions downstream of dev, which holds the unmanaged source."
  }

  validation {
    condition = alltrue(flatten([
      for solution in var.solutions : [
        for name in keys(solution.environment_variables) : contains(solution.environments, name)
      ]
    ]))
    error_message = "Environment variable values may only target environments that receive the solution."
  }
}

variable "solution_secrets" {
  description = "Sensitive environment variable values, keyed by solution unique name, then environment, then schema name. Supply only via TF_VAR_solution_secrets sourced from GitHub Environment secrets; these override any committed value for the same schema name."
  type        = map(map(map(string)))
  default     = {}
  sensitive   = true

  validation {
    condition = alltrue([
      for name in keys(var.solution_secrets) : contains(keys(var.solutions), name)
    ])
    error_message = "Each solution_secrets key must match a solution defined in var.solutions."
  }

  validation {
    condition = alltrue(flatten([
      for name, environments in var.solution_secrets : [
        for environment in keys(environments) : try(contains(var.solutions[name].environments, environment), false)
      ]
    ]))
    error_message = "solution_secrets may only target environments configured for that solution."
  }
}
