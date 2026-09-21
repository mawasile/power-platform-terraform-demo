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
  description = "Exactly three environments and their Terraform-managed Entra security groups. Owner/member values are directory object IDs. The Terraform identity is always an owner."
  type = map(object({
    display_name                = string
    environment_type            = string
    security_group_display_name = optional(string)
    security_group_owner_ids    = optional(set(string), [])
    security_group_member_ids   = optional(set(string), [])
  }))
  nullable = false

  validation {
    condition     = length(var.environments) == 3
    error_message = "Define exactly three Power Platform environments."
  }

  validation {
    condition = alltrue([
      for environment in var.environments :
      contains(["Sandbox", "Production"], environment.environment_type)
    ])
    error_message = "Each environment_type must be Sandbox or Production."
  }

  validation {
    condition = alltrue([
      for environment in var.environments : length(trimspace(environment.display_name)) > 0
    ])
    error_message = "Every environment must have a non-empty display_name."
  }

  validation {
    condition = alltrue([
      for environment in var.environments :
      environment.security_group_display_name == null ? true : length(trimspace(environment.security_group_display_name)) > 0
    ])
    error_message = "If specified, security_group_display_name must not be empty."
  }

  validation {
    condition = alltrue(flatten([
      for environment in var.environments : [
        for object_id in setunion(environment.security_group_owner_ids, environment.security_group_member_ids) :
        can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", object_id))
      ]
    ]))
    error_message = "Security group owners and members must be Entra object IDs in GUID format, not email addresses or application client IDs."
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