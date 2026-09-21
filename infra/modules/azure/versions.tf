terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.9.0"
    }
  }
}