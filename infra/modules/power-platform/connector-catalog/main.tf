# Keep connector discovery at a module boundary: Terraform's mock defaults
# cannot supply distinct elements for this computed nested list attribute.
data "powerplatform_connectors" "tenant" {}

output "connectors" {
  description = "Tenant connector IDs and blockability, consumed by DLP classification."
  value = [
    for connector in data.powerplatform_connectors.tenant.connectors : {
      id          = connector.id
      unblockable = connector.unblockable
    }
  ]
}