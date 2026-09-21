---
title: Power Platform and Azure infrastructure
description: Terraform modules for three Power Platform environments and their Microsoft Entra access groups.
---

## Structure

Run Terraform from `infra`, the single root module and state boundary.

* `main.tf` connects the Azure and Power Platform modules.
* `providers.tf` configures OIDC authentication and provider version constraints.
* `terraform.tfvars` contains the committed, non-secret infrastructure values.
* `backend.tf` configures Azure Blob remote state with Entra authentication and locking.
* `modules/azure` creates one Microsoft Entra security group per environment using `hashicorp/azuread`.
* `modules/power-platform` creates the Power Platform environments using `microsoft/power-platform`.
* `tests/environments.tftest.hcl` tests both modules with mocked providers.
* `tests/deployment.tftest.hcl` checks the actual committed tfvars with a mocked plan.

Security groups belong to Microsoft Entra, not an Azure subscription or resource group.
The state storage account requires an Azure subscription, but these modules do not need an `azurerm` provider.
The `azurerm` backend is built into Terraform and is separate from the AzureRM provider.

## Infrastructure values in Git

Treat `terraform.tfvars` as infrastructure code, not a generated file or GitHub secret.
It defines Dev and Test (Sandbox) and Prod (Production), their group names and membership, the region, and Dataverse settings.
Terraform loads it automatically; the workflow also passes it explicitly to `plan`.
Change these values through reviewed pull requests. Do not generate another tfvars file in the workflow or duplicate these values in repository variables.

`variables.tf` defines the input types and validation; deployment values live in `terraform.tfvars`.
Module tests supply their own fixtures; a separate deployment test checks the committed tfvars without cloud access.
The ignore rules allow this one tfvars file while excluding other tfvars, state, saved plans, and `.terraform` downloads.
Never put tokens, passwords, or client secrets in the committed file.

Each entry in `environments` supports these group settings:

* `security_group_display_name`: defaults to the environment display name followed by `- Users`, separated by a space
* `security_group_owner_ids`: additional user or service-principal object IDs; the current Terraform identity is always included
* `security_group_member_ids`: member object IDs; defaults to an empty set

The root outputs include `environment_ids`, `environment_urls`, and `security_group_ids`, keyed by `dev`, `test`, and `prod`.
The Power Platform module receives each group's `object_id`, not the provider's `/groups/...` resource path.
These references make environment creation depend on group creation.

> [!IMPORTANT]
> Groups start with no members. Add the intended users before deploying to avoid blocking ordinary users' access.
> Group ownership does not grant membership. Users still need appropriate licensing and Dataverse security roles.

Terraform manages the full membership list. Members added only through the portal will be removed by a subsequent apply.
Do not also manage the same group's members using separate `azuread_group_member` resources.
When `enable_dataverse` is false, groups are still created but are not attached to the environments by this configuration.

## GitHub repository setup

In `mawasile/power-platform-terraform-demo`, add these under Settings > Secrets and variables > Actions.

| Kind     | Name                       | Value                                             |
|----------|----------------------------|---------------------------------------------------|
| Secret   | `AZURE_TENANT_ID`           | Microsoft Entra tenant ID                          |
| Secret   | `AZURE_CLIENT_ID`           | Application/client ID of the deployment principal  |
| Variable | `TF_STATE_STORAGE_ACCOUNT` | Existing Azure storage account name               |
| Variable | `TF_STATE_CONTAINER`       | Existing private blob container name, e.g. tfstate  |

The workflow maps the two secrets to `ARM_CLIENT_ID` / `ARM_TENANT_ID` for AzureAD and the backend,
and to `POWER_PLATFORM_CLIENT_ID` / `POWER_PLATFORM_TENANT_ID` for Power Platform.
All three use native OIDC support. No client secret, storage key, Azure CLI login, or `azure/login` action is needed.
The local, git-ignored `.env` is only a placeholder reference; neither Terraform nor the workflow loads it.

### Federated identity

Create a GitHub environment named `infrastructure` under repository Settings > Environments.
Restrict its deployment branches to `main`, and configure required reviewers if supported by your GitHub plan.
Without configured protection rules, the environment name alone does not provide an approval gate.

Configure the Entra application's GitHub federated credential with:

* Issuer: `https://token.actions.githubusercontent.com`
* Audience: `api://AzureADTokenExchange`
* Subject: `repo:mawasile@50197777/power-platform-terraform-demo@1379899334:environment:infrastructure`

Use the environment subject, not the branch or pull-request subject, because the deployment job references that GitHub environment.
The workflow also restricts deployment to `main` in the named repository.
GitHub reports `use_immutable_subject: true` for this repository, so its verified subject prefix includes the owner and repository IDs.
Do not omit the numeric IDs. For a different repository, confirm its OIDC subject settings rather than copying this value.
See [GitHub's immutable subject claims](https://docs.github.com/en/actions/reference/security/oidc#immutable-subject-claims).

### Permissions and prerequisites

OIDC authenticates the principal; it does not grant resource permissions.

* Grant Microsoft Graph application permissions with admin consent for Entra group management. The AzureAD provider supports `Group.Create` for groups owned by the principal, or `Group.ReadWrite.All`. Specifying user principals as owners additionally requires a user-read permission such as `User.Read.All`.
* Register the application as a Power Platform management application and configure the Power Platform provider's required application permissions. Ensure the tenant has the licensing and database capacity needed for the environments.
* Create the storage account and private blob container before the first run. Grant the deployment principal `Storage Blob Data Contributor` scoped to the state container. Enable blob versioning and soft delete, and ensure the runner can reach the storage endpoint.

Storage is a bootstrap dependency: this Terraform root cannot create its own backend before `terraform init` runs.
The configuration uses standard Azure Blob endpoints, so no subscription ID secret or storage-account management-plane permission is required at runtime.
Private endpoints require a suitably networked runner; the workflow currently uses a GitHub-hosted Ubuntu runner.
The state blob key is fixed in `backend.tf` as `power-platform-terraform-demo.tfstate`.
Do not change the account, container, or key after deployment without explicitly migrating the state.

## Workflow behavior

The [Terraform infrastructure workflow](../.github/workflows/terraform.yml) runs from `infra`.

1. Pull requests to `main` run formatting, backend-free initialization, validation, and mocked tests. This job has no cloud secrets or OIDC token permission; it does not perform a live cloud plan.
2. Pushes to `main` affecting infrastructure or the workflow run those checks, then plan and apply using the protected environment.
3. Manual runs on `main` plan only by default. Select the `apply` checkbox to apply the saved plan in that run.

Configure OIDC, repository settings, and backend storage before pushing to `main` for the first deployment.
Deployment uses the committed lockfile and tfvars; it never runs `terraform init -upgrade`.
Concurrent deployments are serialized and running applies are not cancelled by newer pushes.
Azure Blob leases provide state locking, including protection from other Terraform clients.
Plans that delete or replace any resource are blocked; there is no automatic destroy operation.
Intentional destructive changes require a separately reviewed process rather than bypassing the guard casually.
Plans stay on the runner and are deleted at the end of the job, not uploaded as artifacts.

This workflow assumes a fresh deployment or an already-correct remote state.
If resources already exist, migrate/import their state before the first deployment to avoid creating duplicates.
No legacy resource-address migration is included in this configuration.

## Local checks without cloud access

From `infra`, run `terraform init -backend=false -lockfile=readonly`, `terraform fmt -check -recursive`,
`terraform validate`, and `terraform test`. Both providers are mocked during tests.
Real deployment is performed only through GitHub Actions.
Commit `.terraform.lock.hcl` alongside the infrastructure files.

## References

* [Power Platform OIDC setup and prerequisites](https://raw.githubusercontent.com/microsoft/terraform-provider-power-platform/v4.2.0/docs/guides/oidc.md)
* [AzureAD group permissions](https://raw.githubusercontent.com/hashicorp/terraform-provider-azuread/v3.9.0/docs/resources/group.md)
* [Azure Blob backend OIDC and RBAC](https://developer.hashicorp.com/terraform/language/backend/azurerm)
