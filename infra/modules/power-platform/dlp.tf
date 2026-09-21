# Read the catalog once so every existing connector receives a classification.
module "connector_catalog" {
  source = "./connector-catalog"
  count  = length(var.dlp_policies) > 0 ? 1 : 0
}

locals {
  connector_catalog = length(var.dlp_policies) > 0 ? module.connector_catalog[0].connectors : []
  # The live catalog can contain multiple entries for the same connector ID.
  connectors_by_id = {
    for id in toset([for connector in local.connector_catalog : connector.id]) : id => {
      id                           = id
      action_rules                 = []
      endpoint_rules               = []
      default_action_rule_behavior = ""
    }
  }
  # Any unblockable entry wins if duplicate records disagree on blockability.
  unblockable_connector_ids = toset([
    for connector in local.connector_catalog : connector.id if connector.unblockable
  ])
}

resource "powerplatform_data_loss_prevention_policy" "environment" {
  for_each = var.dlp_policies

  display_name                      = each.value.display_name
  default_connectors_classification = "Blocked"
  environment_type                  = "OnlyEnvironments"
  environments = contains(keys(var.environments), each.key) ? [
    powerplatform_environment.environments[each.key].id
  ] : []

  business_connectors = toset([
    for id, connector in local.connectors_by_id : connector
    if contains(each.value.business_connector_ids, id)
  ])
  non_business_connectors = toset([
    for id, connector in local.connectors_by_id : connector
    if !contains(each.value.business_connector_ids, id) && contains(local.unblockable_connector_ids, id)
  ])
  blocked_connectors = toset([
    for id, connector in local.connectors_by_id : connector
    if !contains(each.value.business_connector_ids, id) && !contains(local.unblockable_connector_ids, id)
  ])

  custom_connectors_patterns = [{
    order            = 1
    host_url_pattern = "*"
    data_group       = "Blocked"
  }]

  lifecycle {
    precondition {
      condition     = contains(keys(var.environments), each.key)
      error_message = "Each DLP policy key must match a managed environment key; external or tenant-wide scopes are not supported."
    }
    precondition {
      condition     = length(local.connector_catalog) > 0
      error_message = "The tenant connector catalog is empty; refusing to create an incomplete DLP policy."
    }
    precondition {
      condition     = length(setsubtract(each.value.business_connector_ids, toset(keys(local.connectors_by_id)))) == 0
      error_message = "A Business connector ID is missing from the tenant catalog. Check the allowlist before deploying."
    }
  }
}