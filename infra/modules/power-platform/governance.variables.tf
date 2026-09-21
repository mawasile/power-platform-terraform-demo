variable "tenant_settings" {
  description = "Optional tenant-wide settings. Null leaves settings unmanaged on a fresh deployment; removal after creation is protected."
  type = object({
    disable_environment_creation_by_non_admin_users           = bool
    disable_trial_environment_creation_by_non_admin_users     = bool
    disable_developer_environment_creation_by_non_admin_users = bool
    disable_share_with_everyone                               = bool
    disable_connection_sharing_with_everyone                  = bool
  })
  default = null
}