resource "powerplatform_environment_settings" "environments" {
  for_each = { for name, environment in local.environments : name => environment.settings if environment.settings != null }

  environment_id = powerplatform_environment.environments[each.key].id

  # Omitted blocks stay unmanaged here, including AI features and the firewall.
  audit_and_logs = each.value.audit == null ? null : {
    plugin_trace_log_setting = each.value.audit.plugin_trace_log_setting
    audit_settings = {
      is_audit_enabled             = each.value.audit.is_audit_enabled
      is_user_access_audit_enabled = each.value.audit.is_user_access_audit_enabled
      is_read_audit_enabled        = each.value.audit.is_read_audit_enabled
      log_retention_period_in_days = each.value.audit.log_retention_period_in_days
    }
  }

  email = each.value.max_upload_file_size_in_bytes == null ? null : {
    email_settings = {
      max_upload_file_size_in_bytes = each.value.max_upload_file_size_in_bytes
    }
  }

  # This set replaces the environment's current blocked extensions instead of adding to them.
  privacy_and_security = each.value.blocked_attachment_extensions == null ? null : {
    blocked_attachment_extensions = each.value.blocked_attachment_extensions
  }

  # Avoid simultaneous governance writes during initial adoption.
  depends_on = [powerplatform_managed_environment.environments]
}