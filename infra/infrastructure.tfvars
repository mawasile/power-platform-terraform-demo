# Commit this file: these non-secret values are part of the infrastructure.
# GitHub Actions deploys this exact configuration. Change it through a PR.
# Tenant/client IDs belong in GitHub repository secrets, not in this file.

location         = "europe"
macro_region     = null
enable_dataverse = true
language_code    = 1033
currency_code    = "EUR"

environments = {
  dev = {
    display_name                = "Demo - Dev"
    environment_type            = "Sandbox"
    security_group_display_name = "Demo - Dev - Users"
    security_group_owner_ids    = []
    security_group_member_ids   = []
  }
  test = {
    display_name                = "Demo - Test"
    environment_type            = "Sandbox"
    security_group_display_name = "Demo - Test - Users"
    security_group_owner_ids    = []
    security_group_member_ids   = []
  }
  prod = {
    display_name                = "Demo - Prod"
    environment_type            = "Production"
    security_group_display_name = "Demo - Prod - Users"
    security_group_owner_ids    = []
    security_group_member_ids   = []
  }
}

# Add intended users' Entra object IDs to member_ids before granting access.
# The deployment service principal is always an owner, not an automatic member.
# Membership is authoritative: portal-only additions will be removed on apply.

# WARNING: These five switches apply across the ENTIRE tenant.
tenant_settings = {
  disable_environment_creation_by_non_admin_users           = true
  disable_trial_environment_creation_by_non_admin_users     = true
  disable_developer_environment_creation_by_non_admin_users = true
  disable_share_with_everyone                               = true
  disable_connection_sharing_with_everyone                  = true
}

# One policy per managed environment; policy keys must match environment keys.
# Other unblockable connectors remain Non-Business (a platform limitation).
# Everything else is Blocked, including new blockable and custom connectors.
dlp_policies = {
  dev = {
    display_name = "Demo - Dev - Strict DLP"
    business_connector_ids = [
      "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps",
      "/providers/Microsoft.PowerApps/apis/shared_sharepointonline",
      "/providers/Microsoft.PowerApps/apis/shared_office365",
      "/providers/Microsoft.PowerApps/apis/shared_teams",
      "/providers/Microsoft.PowerApps/apis/shared_onedriveforbusiness",
    ]
  }
  test = {
    display_name = "Demo - Test - Strict DLP"
    business_connector_ids = [
      "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps",
      "/providers/Microsoft.PowerApps/apis/shared_sharepointonline",
      "/providers/Microsoft.PowerApps/apis/shared_office365",
      "/providers/Microsoft.PowerApps/apis/shared_teams",
      "/providers/Microsoft.PowerApps/apis/shared_onedriveforbusiness",
    ]
  }
  prod = {
    display_name = "Demo - Prod - Strict DLP"
    business_connector_ids = [
      "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps",
      "/providers/Microsoft.PowerApps/apis/shared_sharepointonline",
      "/providers/Microsoft.PowerApps/apis/shared_office365",
      "/providers/Microsoft.PowerApps/apis/shared_teams",
      "/providers/Microsoft.PowerApps/apis/shared_onedriveforbusiness",
    ]
  }
}