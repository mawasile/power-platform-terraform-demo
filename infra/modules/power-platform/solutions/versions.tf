terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    powerplatform = {
      source  = "microsoft/power-platform"
      version = ">= 4.2.0"
    }
  }
}
