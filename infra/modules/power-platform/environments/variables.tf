variable "environments" {
  description = "Environment provisioning and governance, with the Entra group object ID used to restrict Dataverse access. Null overrides inherit shared defaults."
  type = map(object({
    display_name      = string
    environment_type  = string
    security_group_id = string
    location          = optional(string)
    macro_region      = optional(string)
    enable_dataverse  = optional(bool)
    language_code     = optional(number)
    currency_code     = optional(string)
    settings = optional(object({
      audit = optional(object({
        plugin_trace_log_setting     = string
        is_audit_enabled             = bool
        is_user_access_audit_enabled = bool
        is_read_audit_enabled        = bool
        log_retention_period_in_days = number
      }))
      max_upload_file_size_in_bytes = optional(number)
      blocked_attachment_extensions = optional(set(string))
    }))
    managed_environment = optional(object({
      is_usage_insights_disabled                         = optional(bool, true)
      is_group_sharing_disabled                          = bool
      limit_sharing_mode                                 = string
      max_limit_user_sharing                             = number
      solution_checker_mode                              = string
      suppress_validation_emails                         = optional(bool, false)
      power_automate_is_sharing_disabled                 = bool
      copilot_allow_grant_editor_permissions_when_shared = bool
      copilot_limit_sharing_mode                         = string
      copilot_max_limit_user_sharing                     = number
    }))
  }))
  nullable = false

  validation {
    condition = alltrue([
      for environment in var.environments : try(environment.settings.audit, null) == null ? true : try(
        contains(["Off", "Exception", "All"], environment.settings.audit.plugin_trace_log_setting) &&
        floor(environment.settings.audit.log_retention_period_in_days) == environment.settings.audit.log_retention_period_in_days &&
        (environment.settings.audit.log_retention_period_in_days == -1 ||
        (environment.settings.audit.log_retention_period_in_days >= 31 && environment.settings.audit.log_retention_period_in_days <= 24855)) &&
        (environment.settings.audit.is_audit_enabled ||
        (!environment.settings.audit.is_user_access_audit_enabled && !environment.settings.audit.is_read_audit_enabled)),
        false
      )
    ])
    error_message = "Audit settings require Off/Exception/All tracing, whole-day retention of 31-24855 or -1 (forever), and auditing enabled for access/read logging."
  }

  validation {
    condition = alltrue([
      for environment in var.environments : try(environment.settings.max_upload_file_size_in_bytes, null) == null ? true : try(
        floor(environment.settings.max_upload_file_size_in_bytes) == environment.settings.max_upload_file_size_in_bytes &&
        environment.settings.max_upload_file_size_in_bytes >= 1024 &&
        environment.settings.max_upload_file_size_in_bytes <= 134217728,
        false
      )
    ])
    error_message = "max_upload_file_size_in_bytes must be a whole number of bytes from 1024 through the platform maximum of 134217728 (128 MB)."
  }

  # A configured set replaces the environment's whole blocked list, so an empty set is rejected.
  validation {
    condition = alltrue([
      for environment in var.environments : try(environment.settings.blocked_attachment_extensions, null) == null ? true : try(
        length(environment.settings.blocked_attachment_extensions) > 0 &&
        alltrue([
          for extension in environment.settings.blocked_attachment_extensions :
          can(regex("^[a-z0-9]+$", extension))
        ]),
        false
      )
    ])
    error_message = "blocked_attachment_extensions must be a non-empty set of lowercase extensions without leading dots, such as exe."
  }

  validation {
    condition = alltrue([
      for environment in var.environments : environment.managed_environment == null ? true : try(
        contains(["None", "Warn", "Block"], environment.managed_environment.solution_checker_mode) &&
        (environment.managed_environment.is_group_sharing_disabled ? (
          environment.managed_environment.limit_sharing_mode == "ExcludeSharingToSecurityGroups" &&
          environment.managed_environment.max_limit_user_sharing >= 1 &&
          floor(environment.managed_environment.max_limit_user_sharing) == environment.managed_environment.max_limit_user_sharing
          ) : (
          environment.managed_environment.limit_sharing_mode == "NoLimit" &&
          environment.managed_environment.max_limit_user_sharing == -1
        )) &&
        contains(["NoLimit", "ExcludeSharingToSecurityGroups", "DisableSharing"], environment.managed_environment.copilot_limit_sharing_mode) &&
        (environment.managed_environment.copilot_limit_sharing_mode == "ExcludeSharingToSecurityGroups" ? (
          environment.managed_environment.copilot_max_limit_user_sharing >= 1 &&
          floor(environment.managed_environment.copilot_max_limit_user_sharing) == environment.managed_environment.copilot_max_limit_user_sharing
        ) : environment.managed_environment.copilot_max_limit_user_sharing == -1),
        false
      )
    ])
    error_message = "Managed controls require None/Warn/Block checking, consistent canvas sharing mode/cap, and valid agent sharing mode/cap. Use -1 for inactive caps, otherwise a positive integer."
  }
}

variable "location" {
  description = "Default Power Platform location. Ignored when macro_region is set."
  type        = string
  nullable    = false
}

variable "macro_region" {
  description = "Default Power Platform macro region, overriding location."
  type        = string
  default     = null
}

variable "enable_dataverse" {
  description = "Default for provisioning Dataverse and associating each environment with its security group."
  type        = bool
  nullable    = false
}

variable "language_code" {
  description = "Default Dataverse base language LCID."
  type        = number
  nullable    = false
}

variable "currency_code" {
  description = "Default Dataverse base currency ISO code."
  type        = string
  nullable    = false
}