output "tenant_settings_id" {
  description = "Tenant ID whose governance settings are managed, or null if disabled."
  value       = try(powerplatform_tenant_settings.governance[0].id, null)
}