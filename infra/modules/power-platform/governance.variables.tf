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

variable "dlp_policies" {
  description = "Strict DLP policies keyed by a managed environment key, each with an explicit Business connector allowlist."
  type = map(object({
    display_name           = string
    business_connector_ids = set(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for policy in var.dlp_policies :
      length(trimspace(policy.display_name)) > 0 && length(policy.business_connector_ids) > 0
    ])
    error_message = "Each DLP policy needs a display name and at least one Business connector."
  }

  validation {
    condition = alltrue(flatten([
      for policy in var.dlp_policies : [
        for id in policy.business_connector_ids :
        can(regex("^/providers/Microsoft[.]PowerApps/apis/[^/]+$", id))
      ]
    ]))
    error_message = "Use full connector IDs such as /providers/Microsoft.PowerApps/apis/shared_sharepointonline."
  }
}