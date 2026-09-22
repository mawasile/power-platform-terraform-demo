variable "deployments" {
  description = "Managed solution imports keyed by solution and environment. The unique name and version must match the package metadata exactly."
  type = map(object({
    environment_id                   = string
    unique_name                      = string
    version                          = string
    file                             = string
    environment_variables            = optional(map(string), {})
    connection_references            = optional(map(string), {})
    publish_all_customizations       = optional(bool, false)
    skip_product_update_dependencies = optional(bool, false)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for deployment in var.deployments :
      can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$", deployment.version))
    ])
    error_message = "Each solution version must use the four-part Dataverse format, such as 1.0.0.2."
  }

  validation {
    condition = alltrue([
      for deployment in var.deployments : endswith(deployment.file, ".zip")
    ])
    error_message = "Each solution file must be a .zip package exported as managed."
  }

  validation {
    condition = alltrue(flatten([
      for deployment in var.deployments : [
        for schema_name in keys(deployment.environment_variables) :
        can(regex("^[A-Za-z][A-Za-z0-9]*_[A-Za-z0-9_]+$", schema_name))
      ]
    ]))
    error_message = "Environment variable keys must be schema names including the publisher prefix, such as bal_MagicNumber."
  }
}
