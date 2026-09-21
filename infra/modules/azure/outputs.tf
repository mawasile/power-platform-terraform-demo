output "security_group_ids" {
  description = "Entra group object IDs, not provider resource paths, keyed by environment."
  value = {
    for name, group in azuread_group.environment_access : name => group.object_id
  }
}

output "security_groups" {
  description = "Managed groups and their configuration, keyed by environment."
  value       = azuread_group.environment_access
}