terraform {
  # Storage must exist before init. GitHub repository variables supply its names.
  # Identity comes from ARM_CLIENT_ID and ARM_TENANT_ID, never storage keys.
  backend "azurerm" {
    use_oidc         = true
    use_cli          = false
    use_azuread_auth = true
    key              = "power-platform-terraform-demo.tfstate"
  }
}