variable "security_groups" {
  description = "Entra access groups keyed by environment. Ownership includes the Terraform principal; membership is managed exclusively here."
  type = map(object({
    display_name = string
    owner_ids    = optional(set(string), [])
    member_ids   = optional(set(string), [])
  }))
  nullable = false
}