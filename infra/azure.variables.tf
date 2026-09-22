variable "environment_access_groups" {
  description = "Microsoft Entra access groups for the Power Platform environments, keyed by environment name. Omitted environments get a default group name, no extra owners, and no members."
  type = map(object({
    display_name = optional(string)
    owner_ids    = optional(set(string), [])
    member_ids   = optional(set(string), [])
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for name in keys(var.environment_access_groups) : contains(keys(var.environments), name)
    ])
    error_message = "Each access group key must match an environment key, otherwise its owners and members would be silently ignored."
  }

  validation {
    condition = alltrue([
      for group in var.environment_access_groups :
      group.display_name == null ? true : length(trimspace(group.display_name)) > 0
    ])
    error_message = "If specified, an access group display_name must not be empty."
  }

  validation {
    condition = alltrue(flatten([
      for group in var.environment_access_groups : [
        for object_id in setunion(group.owner_ids, group.member_ids) :
        can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", object_id))
      ]
    ]))
    error_message = "Group owners and members must be Entra object IDs in GUID format, not email addresses or application client IDs."
  }
}
