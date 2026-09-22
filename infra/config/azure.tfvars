# Microsoft Entra access groups, keyed by the environment keys in environments.tfvars.
# Omit an environment to accept the default group name and an empty membership.
environment_access_groups = {
  dev = {
    display_name = "Demo - Dev - Users"
    owner_ids    = []
    member_ids   = []
  }

  test = {
    display_name = "Demo - Test - Users"
    owner_ids    = []
    member_ids   = []
  }

  prod = {
    display_name = "Demo - Prod - Users"
    owner_ids    = []
    member_ids   = []
  }
}

# Add intended users' Entra object IDs to member_ids before granting access.
# Membership is authoritative; portal-only additions are removed on apply.
# The deployment identity is always an owner, not an automatic member.
