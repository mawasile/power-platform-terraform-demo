variable "location" {
  description = "Power Platform location, such as europe or unitedstates; not an Azure region name. Ignored when macro_region is set."
  type        = string
  nullable    = false
}

variable "macro_region" {
  description = "Optional geography, such as eu-efta or north-america, for tenants using macro-region provisioning. Overrides location."
  type        = string
  default     = null
}

variable "environments" {
  description = "Power Platform environments keyed by a stable short name, with per-environment provisioning, settings, and managed controls. Null provisioning overrides inherit the root defaults."
  type = map(object({
    display_name     = string
    environment_type = string
    location         = optional(string)
    macro_region     = optional(string)
    enable_dataverse = optional(bool)
    language_code    = optional(number)
    currency_code    = optional(string)
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
    condition     = length(var.environments) > 0
    error_message = "Define at least one Power Platform environment."
  }

  # Each key is a resource identity: renaming one replaces that environment.
  validation {
    condition = alltrue([
      for name in keys(var.environments) : can(regex("^[a-z][a-z0-9-]{1,31}$", name))
    ])
    error_message = "Environment keys must be 2-32 lowercase characters, starting with a letter, such as dev or uat-eu."
  }

  validation {
    condition = alltrue([
      for environment in var.environments :
      contains(["Sandbox", "Production"], environment.environment_type)
    ])
    error_message = "Each environment_type must be Sandbox or Production."
  }

  # Every Production environment carries the same strict baseline, not just one named prod.
  validation {
    condition = alltrue([
      for name, environment in var.environments : environment.environment_type != "Production" ? true : try(
        environment.settings.audit.is_audit_enabled &&
        environment.settings.audit.is_user_access_audit_enabled &&
        length(environment.settings.blocked_attachment_extensions) > 0 &&
        environment.managed_environment.solution_checker_mode == "Block" &&
        environment.managed_environment.is_group_sharing_disabled &&
        environment.managed_environment.limit_sharing_mode == "ExcludeSharingToSecurityGroups" &&
        environment.managed_environment.max_limit_user_sharing >= 1 &&
        environment.managed_environment.max_limit_user_sharing <= 5 &&
        environment.managed_environment.power_automate_is_sharing_disabled &&
        !environment.managed_environment.copilot_allow_grant_editor_permissions_when_shared &&
        environment.managed_environment.copilot_limit_sharing_mode == "DisableSharing",
        false
      )
    ])
    error_message = "Every Production environment requires audit and access logging, blocked attachment extensions, Block solution checking, no group sharing, a canvas sharing cap of 1-5 people, and disabled flow and agent sharing."
  }

  validation {
    condition = alltrue([
      for environment in var.environments : length(trimspace(environment.display_name)) > 0
    ])
    error_message = "Every environment must have a non-empty display_name."
  }
}

variable "enable_dataverse" {
  description = "Provision a Dataverse database in each environment. Choose before deployment; adding Dataverse cannot be undone in place."
  type        = bool
  nullable    = false
}

variable "language_code" {
  description = "Dataverse base language LCID. 1033 is English (United States)."
  type        = number
  nullable    = false
}

variable "currency_code" {
  description = "Dataverse base currency ISO code."
  type        = string
  nullable    = false
}