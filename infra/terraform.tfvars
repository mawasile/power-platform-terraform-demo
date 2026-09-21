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