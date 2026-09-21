variable "environments" {
  description = "Environment configuration with the Entra group object ID used to restrict Dataverse access."
  type = map(object({
    display_name      = string
    environment_type  = string
    security_group_id = string
  }))
  nullable = false
}

variable "location" {
  description = "Power Platform location. Ignored when macro_region is set."
  type        = string
  nullable    = false
}

variable "macro_region" {
  description = "Optional Power Platform macro region, overriding location."
  type        = string
  default     = null
}

variable "enable_dataverse" {
  description = "Whether to provision Dataverse and associate each environment with its security group."
  type        = bool
  nullable    = false
}

variable "language_code" {
  description = "Dataverse base language LCID."
  type        = number
  nullable    = false
}

variable "currency_code" {
  description = "Dataverse base currency ISO code."
  type        = string
  nullable    = false
}