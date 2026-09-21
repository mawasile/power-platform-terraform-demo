output "environment_ids" {
  description = "Power Platform environment IDs, keyed by environment name."
  value       = module.power_platform.environment_ids
}

output "environment_urls" {
  description = "Dataverse URLs, keyed by environment name. Null when Dataverse is disabled."
  value       = module.power_platform.environment_urls
}

output "security_group_ids" {
  description = "Terraform-managed Entra security group object IDs, keyed by environment name."
  value       = module.azure.security_group_ids
}

output "tenant_settings_id" {
  description = "Tenant ID whose governance settings are managed, or null if disabled."
  value       = module.power_platform.tenant_settings_id
}