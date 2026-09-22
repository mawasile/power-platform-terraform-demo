output "environment_ids" {
  description = "Power Platform environment IDs, keyed by environment name."
  value = {
    for name, environment in powerplatform_environment.environments : name => environment.id
  }
}

output "environment_urls" {
  description = "Dataverse URLs, keyed by environment name. Null when Dataverse is disabled."
  value = {
    for name, environment in powerplatform_environment.environments :
    name => local.environments[name].enable_dataverse ? try(environment.dataverse.url, null) : null
  }
}

output "environments" {
  description = "Provisioned environments and their configuration, keyed by environment name."
  value       = powerplatform_environment.environments
}

output "environment_settings" {
  description = "Environment settings for auditing, email uploads, and blocked attachments, keyed by environment name."
  value       = powerplatform_environment_settings.environments
}

output "managed_environments" {
  description = "Managed Environment controls, keyed by environment name."
  value       = powerplatform_managed_environment.environments
}