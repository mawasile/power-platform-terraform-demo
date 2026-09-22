module "tenant" {
  source = "./modules/power-platform/tenant"

  tenant_settings = var.tenant_settings
}

moved {
  from = module.power_platform.powerplatform_tenant_settings.governance
  to   = module.tenant.powerplatform_tenant_settings.governance
}