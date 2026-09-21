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

variable "dlp_policies" {
  description = "Strict DLP policies keyed by a managed environment key. Allowlisted connectors are Business; other blockable connectors and all custom connectors are Blocked."
  type = map(object({
    display_name           = string
    business_connector_ids = set(string)
  }))
  default  = {}
  nullable = false
}