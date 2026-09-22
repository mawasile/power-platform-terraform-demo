resource "powerplatform_managed_environment" "environments" {
  for_each = { for name, environment in local.environments : name => environment.managed_environment if environment.managed_environment != null }

  environment_id                                     = powerplatform_environment.environments[each.key].id
  is_usage_insights_disabled                         = each.value.is_usage_insights_disabled
  is_group_sharing_disabled                          = each.value.is_group_sharing_disabled
  limit_sharing_mode                                 = each.value.limit_sharing_mode
  max_limit_user_sharing                             = each.value.max_limit_user_sharing
  solution_checker_mode                              = each.value.solution_checker_mode
  suppress_validation_emails                         = each.value.suppress_validation_emails
  power_automate_is_sharing_disabled                 = each.value.power_automate_is_sharing_disabled
  copilot_allow_grant_editor_permissions_when_shared = each.value.copilot_allow_grant_editor_permissions_when_shared
  copilot_limit_sharing_mode                         = each.value.copilot_limit_sharing_mode
  copilot_max_limit_user_sharing                     = each.value.copilot_max_limit_user_sharing

  # solution_checker_rule_overrides is omitted: provider 4.2.0 returns null for an
  # empty set, which fails apply with an inconsistent-result error.
}