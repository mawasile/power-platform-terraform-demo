---
title: Power Platform and Azure infrastructure
description: Terraform modules for three Power Platform environments and their Microsoft Entra access groups.
---

## Structure

Run Terraform from `infra`, the single root module and state boundary.

* `main.tf` connects the Azure and Power Platform modules.
* `providers.tf` configures OIDC authentication and provider version constraints.
* `infrastructure.tfvars` contains the committed, non-secret infrastructure values.
* `backend.tf` configures Azure Blob remote state with Entra authentication and locking.
* `modules/azure` creates one Microsoft Entra security group per environment using `hashicorp/azuread`.
* `modules/power-platform` creates the Power Platform environments using `microsoft/power-platform`.
* `modules/power-platform/tenant-settings.tf` manages the selected tenant-wide governance switches.
* `tests/environments.tftest.hcl` tests both modules with mocked providers.
* `tests/deployment.tftest.hcl` checks the actual committed tfvars with a mocked plan.
* `tests/governance.tftest.hcl` tests the tenant-settings baseline, opt-out, and explicit setting overrides.

Security groups belong to Microsoft Entra, not an Azure subscription or resource group.
The state storage account requires an Azure subscription, but these modules do not need an `azurerm` provider.
The `azurerm` backend is built into Terraform and is separate from the AzureRM provider.

## Infrastructure values in Git

Treat `infrastructure.tfvars` as infrastructure code, not a generated file or GitHub secret.
It defines Dev and Test (Sandbox) and Prod (Production), their group names and membership, the region, and Dataverse settings.
Terraform does not auto-load this filename. The workflow passes `-var-file=infrastructure.tfvars` explicitly to both `test` and `plan`.
Change these values through reviewed pull requests. Do not generate another tfvars file in the workflow or duplicate these values in repository variables.

`variables.tf` defines the input types and validation; deployment values live in `infrastructure.tfvars`.
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

## Tenant governance

The selected baseline is enabled in `infrastructure.tfvars`. The existing workflow deploys these resources along with the environments.
Review the governance plan before pushing to `main`, because a push triggers automatic apply.

### Tenant-wide settings

`tenant_settings` manages five restrictions:

* Only admins can create production/sandbox environments.
* Only admins can create trial environments.
* Only admins can create developer environments.
* Makers cannot share apps with Everyone.
* Makers cannot share connections with Everyone.

> [!WARNING]
> These switches affect the entire Power Platform tenant, including environments outside this demo.
> They are not scoped by the three environment IDs. Existing environment creators retain management of their existing environments.

The resource updates the existing tenant-settings singleton. Only the five configured fields are managed;
unrelated settings, including AI and licensing options, are omitted. Review the live plan and resulting tenant settings.
Use only one Terraform state to manage this singleton. If it is already managed elsewhere, coordinate ownership instead of managing it twice.

On a fresh deployment, `tenant_settings = null` opts out. After adoption, do not remove it casually:
the provider's destroy operation can restore pre-management values recorded in private state.
The resource has `prevent_destroy = true`, and the workflow also blocks deletions.
Setting individual switches to `false` is an explicit tenant-wide policy change, not opting out of management.
Deleting the resource block can bypass Terraform's lifecycle protection; keep governance changes under review.

The deployment identity needs tenant-level Power Platform management access for tenant settings.
Entra group permissions or access to the demo environments alone is insufficient.
The existing OIDC management-application registration is a prerequisite; this configuration does not grant itself admin access.
An administrator should verify the service principal permissions before the first governance deployment.
Mock tests validate configuration behavior, not live permissions or service-side enforcement.

### Previously deployed data policies

DLP policy resources and connector discovery have been removed from this codebase.
Removing code does not itself change deployed policies or remote state.
If the previously deployed policies are still tracked in state, the next live plan will propose deleting them;
the workflow's deletion guard will block that apply.
Before the next deployment, choose a separately reviewed policy deletion or state handoff that preserves the live policies.
Do not bypass the deletion guard or discard the complete state file to complete this transition.

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
`terraform validate`, and `terraform test "-var-file=infrastructure.tfvars"`. Both providers are mocked during tests.
The quoted argument also works in PowerShell. Plain `terraform test` does not load the deployment file and reports missing required variables.
Real deployment is performed only through GitHub Actions.
Commit `.terraform.lock.hcl` alongside the infrastructure files.

## References

* [Power Platform OIDC setup and prerequisites](https://raw.githubusercontent.com/microsoft/terraform-provider-power-platform/v4.2.0/docs/guides/oidc.md)
* [AzureAD group permissions](https://raw.githubusercontent.com/hashicorp/terraform-provider-azuread/v3.9.0/docs/resources/group.md)
* [Azure Blob backend OIDC and RBAC](https://developer.hashicorp.com/terraform/language/backend/azurerm)
* [Control environment creation](https://learn.microsoft.com/power-platform/admin/control-environment-creation)
* [Tenant settings resource](https://raw.githubusercontent.com/microsoft/terraform-provider-power-platform/v4.2.0/docs/resources/tenant_settings.md)

