variable "tenant_settings" {
  description = "Optional tenant-wide governance settings. Null leaves the tenant unmanaged. Changes affect ALL environments, not just this demo."
  type = object({
    disable_environment_creation_by_non_admin_users           = bool
    disable_trial_environment_creation_by_non_admin_users     = bool
    disable_developer_environment_creation_by_non_admin_users = bool
    disable_share_with_everyone                               = bool
    disable_connection_sharing_with_everyone                  = bool
  })
  default = null
}