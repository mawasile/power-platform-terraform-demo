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
    name => var.enable_dataverse ? try(environment.dataverse.url, null) : null
  }
}

output "environments" {
  description = "Managed environments and their configuration, keyed by environment name."
  value       = powerplatform_environment.environments
}

output "tenant_settings_id" {
  description = "Tenant ID whose governance settings are managed, or null if disabled."
  value       = try(powerplatform_tenant_settings.governance[0].id, null)
}