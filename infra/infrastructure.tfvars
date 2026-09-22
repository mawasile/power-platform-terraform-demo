# Shared provisioning defaults. Each environment can override these values.
# Load alongside config/environments.tfvars and config/tenant.tfvars.
# All three files contain reviewed, non-secret infrastructure configuration.

location         = "europe"
macro_region     = null
enable_dataverse = true
language_code    = 1033
currency_code    = "EUR"