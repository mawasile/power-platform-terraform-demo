resource "powerplatform_environment" "environments" {
  for_each = var.environments

  display_name     = each.value.display_name
  description      = "${each.key} environment managed by Terraform."
  environment_type = each.value.environment_type
  location         = var.macro_region == null ? var.location : null
  macro_region     = var.macro_region

  # Dataverse requires available tenant database capacity and appropriate licensing.
  dataverse = var.enable_dataverse ? {
    language_code     = var.language_code
    currency_code     = var.currency_code
    security_group_id = each.value.security_group_id
  } : null
}