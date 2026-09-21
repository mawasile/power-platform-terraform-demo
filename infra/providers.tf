terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.9.0"
    }
    powerplatform = {
      source  = "microsoft/power-platform"
      version = "~> 4.2.0"
    }
  }
}

# GitHub Actions supplies ARM_CLIENT_ID / ARM_TENANT_ID for AzureAD and
# POWER_PLATFORM_CLIENT_ID / POWER_PLATFORM_TENANT_ID for Power Platform.
# Each provider obtains a short-lived GitHub OIDC token directly.
provider "azuread" {
  use_cli  = false
  use_oidc = true
}

provider "powerplatform" {
  use_cli  = false
  use_oidc = true
}