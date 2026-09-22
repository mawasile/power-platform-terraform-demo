# Each key is a stable Terraform resource identity. Do not rename deployed keys.
# Add an environment by adding a key here; Production types must meet the strict baseline.
# Region, Dataverse, language, and currency inherit infrastructure.tfvars unless
# overridden inside an environment. Tenant-wide controls belong in tenant.tfvars.
environments = {
  dev = {
    display_name                = "Demo - Dev"
    environment_type            = "Sandbox"
    security_group_display_name = "Demo - Dev - Users"
    security_group_owner_ids    = []
    security_group_member_ids   = []

    settings = {
      audit = {
        plugin_trace_log_setting     = "Exception"
        is_audit_enabled             = true
        is_user_access_audit_enabled = false
        is_read_audit_enabled        = false
        log_retention_period_in_days = 31
      }
      max_upload_file_size_in_bytes = 33554432
      # Dev keeps the environment's existing blocked attachment list.
      blocked_attachment_extensions = null
    }
    # No premium Managed Environment controls in dev.
    managed_environment = null
  }

  test = {
    display_name                = "Demo - Test"
    environment_type            = "Sandbox"
    security_group_display_name = "Demo - Test - Users"
    security_group_owner_ids    = []
    security_group_member_ids   = []

    settings = {
      audit = {
        plugin_trace_log_setting     = "Exception"
        is_audit_enabled             = true
        is_user_access_audit_enabled = false
        is_read_audit_enabled        = false
        log_retention_period_in_days = 90
      }
      max_upload_file_size_in_bytes = 16777216
      blocked_attachment_extensions = ["bat", "cmd", "dll", "exe", "js", "ps1", "vbs"]
    }
    managed_environment = {
      is_usage_insights_disabled                         = true
      is_group_sharing_disabled                          = true
      limit_sharing_mode                                 = "ExcludeSharingToSecurityGroups"
      max_limit_user_sharing                             = 20
      solution_checker_mode                              = "Warn"
      suppress_validation_emails                         = false
      power_automate_is_sharing_disabled                 = false
      copilot_allow_grant_editor_permissions_when_shared = true
      copilot_limit_sharing_mode                         = "ExcludeSharingToSecurityGroups"
      copilot_max_limit_user_sharing                     = 20
    }
  }

  prod = {
    display_name                = "Demo - Prod"
    environment_type            = "Production"
    security_group_display_name = "Demo - Prod - Users"
    security_group_owner_ids    = []
    security_group_member_ids   = []

    settings = {
      audit = {
        plugin_trace_log_setting     = "Off"
        is_audit_enabled             = true
        is_user_access_audit_enabled = true
        # Read/activity logging requires additional licensing and Purview setup.
        is_read_audit_enabled = false
        # Demo baseline, not a compliance guarantee. Review retention and capacity.
        log_retention_period_in_days = 365
      }
      max_upload_file_size_in_bytes = 5242880
      blocked_attachment_extensions = ["bat", "cmd", "com", "cpl", "dll", "exe", "hta", "jar", "js", "lnk", "msi", "ps1", "reg", "scr", "vbs", "wsf"]
    }
    managed_environment = {
      is_usage_insights_disabled                         = true
      is_group_sharing_disabled                          = true
      limit_sharing_mode                                 = "ExcludeSharingToSecurityGroups"
      max_limit_user_sharing                             = 5
      solution_checker_mode                              = "Block"
      suppress_validation_emails                         = false
      power_automate_is_sharing_disabled                 = true
      copilot_allow_grant_editor_permissions_when_shared = false
      copilot_limit_sharing_mode                         = "DisableSharing"
      copilot_max_limit_user_sharing                     = -1
    }
  }
}

# Add intended users' Entra object IDs to security_group_member_ids.
# Membership is authoritative; portal-only additions are removed on apply.
# The deployment identity is always a group owner, not an automatic member.
# Managed Environment sharing limits do not revoke existing sharing grants.
# A blocked_attachment_extensions set replaces that environment's whole list.