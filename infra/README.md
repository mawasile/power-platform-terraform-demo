---
title: Power Platform and Azure infrastructure
description: Shared-state Terraform modules for Power Platform environments, Microsoft Entra access groups, and environment and tenant governance.
---

## Structure

Run Terraform from `infra`, the single root module and state boundary for dev, test, prod, and tenant governance.
The module refactor preserves the existing backend and OIDC configuration; module folders are not separate deployment roots.

* `main.tf` keeps `module.azure` unchanged and connects `module.power_platform` to `./modules/power-platform/environments`. The legacy module label preserves environment state addresses.
* `tenant.tf` connects `module.tenant` to `./modules/power-platform/tenant` and declares the tenant-settings state move.
* `variables.tf` defines shared defaults and environment inputs; `azure.variables.tf` defines the Entra group input and `tenant.variables.tf` defines the separate tenant input.
* `providers.tf` configures OIDC authentication and provider version constraints.
* `infrastructure.tfvars` contains shared provisioning defaults, `config/azure.tfvars` configures the Microsoft Entra access groups, `config/environments.tfvars` contains the environment profiles, `config/solutions.tfvars` lists the managed solutions to import, and `config/tenant.tfvars` configures the tenant singleton.
* `backend.tf` configures Azure Blob remote state with Entra authentication and locking.
* `modules/azure` creates one Microsoft Entra security group per environment using `hashicorp/azuread`.
* `modules/power-platform/environments/main.tf` provisions environments using `microsoft/power-platform`; `settings.tf` manages `powerplatform_environment_settings` for auditing, email upload limits, and blocked attachments, and `managed-environments.tf` manages sharing and solution-checker controls.
* `modules/power-platform/tenant` owns the selected tenant-wide governance switches separately from environment provisioning.
* `modules/power-platform/solutions` imports managed solution packages with `powerplatform_managed_solution` and sets their environment variable values.
* `tests/environments.tftest.hcl` covers environment provisioning and controls with mocked providers.
* `tests/deployment.tftest.hcl` checks the committed four-file configuration with a mocked apply, including generated ID wiring.
* `tests/environment-settings.tftest.hcl` tests the reusable environment module's settings and sharing validation independently of the production policy.
* `tests/governance.tftest.hcl` covers tenant governance. The expanded tests exercise profiles, overrides, and validation failures without cloud access.

Security groups belong to Microsoft Entra, not an Azure subscription or resource group.
The state storage account requires an Azure subscription, but these modules do not need an `azurerm` provider.
The `azurerm` backend is built into Terraform and is separate from the AzureRM provider.

## Infrastructure values in Git

Treat these five committed, non-secret files as infrastructure code, not generated files or GitHub secrets:

* `infrastructure.tfvars` defines shared location, macro-region, Dataverse, language, and currency defaults.
* `config/azure.tfvars` defines the Microsoft Entra access groups: their names, owners, and members.
* `config/environments.tfvars` defines the Power Platform profiles, including names, types, environment settings, and Managed Environment controls.
* `config/solutions.tfvars` defines which managed solution packages are imported, into which environments, and with which environment variable values.
* `config/tenant.tfvars` configures the tenant-settings singleton once, not once per environment.

Terraform does not auto-load these filenames. The workflow passes all five files explicitly to both `test` and `plan`.
Change values through reviewed pull requests. Do not generate extra tfvars files in the workflow or duplicate these values in repository variables.
The `.gitignore` allowlist names exactly these five paths while excluding other tfvars, state, saved plans, and `.terraform` downloads.
Never put tokens, passwords, or client secrets in the committed files.

## Solution deployment

`config/solutions.tfvars` promotes managed solution packages out of dev. Each entry is keyed by the solution unique name
from the package and lists the environments that receive it:

```hcl
TerrraformExampleSolution = {
  version      = "1.0.0.2"
  file         = "solutions/TerrraformExampleSolution_managed.zip"
  environments = ["test", "prod"]
  environment_variables = {
    test = { bal_MagicNumber = "42" }
  }
}
```

The `unique_name` key and `version` must match the package metadata exactly, because the provider treats that identity as the
deployment trigger rather than a file checksum. Replacing the zip alone changes nothing; raise `version` in the same commit.
File paths are repository relative, and a missing package fails the plan rather than the apply.
Exporting a new version through the [solution export workflow](../.github/workflows/solution-export.yml) covers the unmanaged
source in `solutions/`; the managed package for deployment is a separate artifact.

Imports target downstream environments only. Deploying a managed solution into dev would layer it over the unmanaged source,
so the configuration rejects `dev` as a target.
Definitions ship inside the package, so values are applied after the import through `powerplatform_environment_variable_value`.
A definition with no value stays valid until a consumer needs one.

### Environment variable values

Values come from two sources that merge per environment:

* `config/solutions.tfvars` holds ordinary, reviewable values under `environment_variables`. Test's `bal_MagicNumber` lives here.
* The sensitive `solution_secrets` variable holds values that must not be committed. Prod's `bal_MagicNumber` lives here.

```hcl
solution_secrets = {
  TerrraformExampleSolution = {
    prod = { bal_MagicNumber = "7" }
  }
}
```

The deployment workflow builds that object at runtime from the `MAGIC_NUMBER_PROD` GitHub Environment secret, using `jq -n`
so the secret is never interpolated into a JSON string, then masks it and passes it as `TF_VAR_solution_secrets`.
A secret wins over a committed value for the same schema name, so an environment can be promoted from a committed value to an
injected one without editing the module. Both sources may only target environments that receive the solution, and
`solution_secrets` must reference a solution that exists in `solutions`.

Because values may be sensitive, the module iterates the map keys rather than the map itself: a sensitive value cannot be used
as a resource instance key. Mocked tests run with `solution_secrets` empty by default and assert the committed values, while a
dedicated run supplies both sources to confirm the override order.

> [!IMPORTANT]
> Production enforces solution checker `Block`, so a package with critical findings fails to import there.
> Validate in test first, and expect a higher version to upgrade through Dataverse stage-and-upgrade, which removes omitted components.

The root accepts any number of environments, keyed by a short lowercase name such as `dev` or `uat-eu`.
The committed demo defines `dev`, `test`, and `prod`. A key is a resource identity: renaming a deployed key replaces that environment.
Keep every profile in each invocation against this shared state.
Do not invoke a dev-only, test-only, or prod-only file as an isolated deployment against it.
Terraform replaces repeated map variable values; it does not deep-merge them across files.
A later `environments` assignment replaces the entire earlier map rather than adding or patching one profile.

### Adding an environment

Add another entry to `config/environments.tfvars` with a new key, then review the plan:

```hcl
"uat-eu" = {
  display_name     = "Demo - UAT"
  environment_type = "Sandbox"
  settings = {
    audit = {
      plugin_trace_log_setting     = "Exception"
      is_audit_enabled             = true
      is_user_access_audit_enabled = false
      is_read_audit_enabled        = false
      log_retention_period_in_days = 31
    }
  }
  managed_environment = null
}
```

Its Entra access group is created automatically. Add a matching key to `config/azure.tfvars` only to set a custom name, owners, or members.

Terraform then creates that environment and its own Entra access group, leaving existing environments untouched.
The strict baseline follows `environment_type`, not the key name: every `Production` environment must satisfy it,
while `Sandbox` environments may omit Managed Environment controls. Downgrading a deployed environment to `Sandbox`
would bypass those rules, but it also forces replacement, which the workflow's deletion guard blocks.
A new environment consumes tenant capacity and, for Managed Environments, premium licensing.

Each environment can override `location`, `macro_region`, `enable_dataverse`, `language_code`, and `currency_code`.
Omitted or null overrides inherit the shared defaults. In particular, `macro_region = null` inherits the global macro-region;
it cannot clear that value to select a location instead. An effective macro-region takes precedence over location.
Configuring environment settings or Managed Environment controls requires Dataverse for that environment.
Location, language, and currency are provisioning choices; changing them on existing environments can require replacement or be unsupported.
Review the plan rather than treating these overrides as runtime preferences.

Module tests supply their own fixtures; the deployment test checks the committed profiles without cloud access.

### Environment access groups

`config/azure.tfvars` keys `environment_access_groups` by environment name and supports these settings:

* `display_name`: defaults to the environment display name followed by `- Users`, separated by a space
* `owner_ids`: additional user or service-principal object IDs; the current Terraform identity is always included
* `member_ids`: member object IDs; defaults to an empty set

An environment with no entry gets the default name, no extra owners, and no members.
A key that matches no environment is rejected, because its owners and members would otherwise be ignored silently.

The root outputs include `environment_ids`, `environment_urls`, and `security_group_ids`, keyed by `dev`, `test`, and `prod`.
The Power Platform module receives each group's `object_id`, not the provider's `/groups/...` resource path.
These references make environment creation depend on group creation.

> [!IMPORTANT]
> Groups start with no members. Add the intended users before deploying to avoid blocking ordinary users' access.
> Group ownership does not grant membership. Users still need appropriate licensing and Dataverse security roles.

Terraform manages the full membership list. Members added only through the portal will be removed by a subsequent apply.
Do not also manage the same group's members using separate `azuread_group_member` resources.
When an environment's effective `enable_dataverse` is false, its group is still created but is not attached by this configuration.
Its `settings` and `managed_environment` configurations must also be null.

## Environment governance

The profiles intentionally make prod stricter than dev and test. Managed Environments are selected for test and prod only.

| Setting               | Dev         | Test        | Prod       |
|-----------------------|-------------|-------------|------------|
| Environment type      | Sandbox     | Sandbox     | Production |
| Auditing              | Enabled     | Enabled     | Enabled    |
| Audit retention days  | 31          | 90          | 365        |
| Plug-in tracing       | `Exception` | `Exception` | `Off`      |
| User-access auditing  | Disabled    | Disabled    | Enabled    |
| Read auditing         | Disabled    | Disabled    | Disabled   |
| Email upload limit    | 32 MB       | 16 MB       | 5 MB       |
| Blocked attachments   | Unmanaged   | 7 types     | 16 types   |
| Managed Environment   | Null        | Enabled     | Enabled    |

Each profile groups these under `settings`, which maps to one `powerplatform_environment_settings` resource per environment.
The environment module validates whole-day audit retention from 31 through 24855, or `-1` for indefinite retention.
Access or read auditing requires auditing to be enabled. Table- and column-level audit configuration is separate;
enabling environment auditing does not select every table or column for auditing.
Upload limits accept 1024 bytes through the 134217728-byte (128 MB) platform maximum.
Review existing settings, retention costs, storage capacity, and compliance requirements before adopting these values.
The 365-day production baseline is a demo policy, not a compliance guarantee.

### Blocked attachment extensions

> [!WARNING]
> A configured set replaces that environment's entire blocked list rather than adding to it.
> Review the current list before applying, because a short list can remove existing protections.

The module rejects an empty set, which would clear the list, and requires lowercase extensions without leading dots.
Dev omits this setting and keeps whatever the environment already blocks. Test and prod declare explicit demo lists.

### Managed Environment controls

* Test disables canvas-app sharing to security groups and caps individual sharing at 20 users. Solution checker uses `Warn`; flow sharing and agent editor grants remain allowed. Agent viewer sharing excludes security groups and is capped at 20 users.
* Prod disables canvas-app sharing to security groups and caps individual sharing at 5 users. Solution checker uses `Block`; flow sharing, agent viewer sharing, and agent editor grants are blocked. The inactive agent viewer cap is `-1`.
* Both profiles disable usage insights and leave validation emails unsuppressed. Solution-checker rule exclusions are not managed here, so this configuration excludes no rules and leaves any existing exclusions in place.
* Dev has `managed_environment = null`, so this configuration does not manage those controls for dev. This does not prove an existing dev environment is unmanaged outside Terraform.

Root validation requires every Production environment to have auditing, user-access auditing, blocked attachment extensions,
solution checker `Block`, no canvas group sharing, an individual canvas sharing cap from 1 through 5, and blocked flow and agent sharing.
The environment module additionally checks coherent sharing modes and caps: active caps are positive integers,
while inactive caps use `-1`. Production's stricter baseline cannot be relaxed through tfvars alone.

> [!IMPORTANT]
> Managed Environments for test and prod are an accepted premium-licensing choice, not proof of entitlement.
> Verify the required licenses for affected users and workloads, plus tenant and Dataverse capacity, before applying.

Sharing restrictions do not revoke existing grants and can take up to one hour to take effect.
Review existing shares separately. Group-sharing restrictions affect app distribution; they do not remove the environment's Entra access group.
The 20-user and 5-user caps are demo policy choices, not universal enterprise recommendations.
Solution checker `Block` blocks solution imports with critical violations; it does not block unmanaged customizations generally.

### Adopting and removing settings

Creating a `powerplatform_environment_settings` resource adopts and updates settings on an existing environment;
it does not create another environment. Its destroy operation is a settings no-op, not a rollback of applied changes.
Creating a `powerplatform_managed_environment` resource enables or updates controls on the referenced environment,
but destroying it disables Managed Environment controls. Do not treat removing either resource as a safe rollback.
Omitted settings groups are computed: they keep the environment's current values instead of being reset.
This configuration manages only auditing, email upload limits, and blocked attachments;
AI features, behavior settings, and the IP firewall stay unmanaged here.

## Tenant governance

The selected baseline is enabled in `config/tenant.tfvars`. The workflow manages it once through `module.tenant` in the same state as the environments.
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

DLP policy resources and connector discovery were removed from this codebase, and the three retired demo policies
were deleted from the tenant through a separately authorized run. No DLP policy remains in this configuration or its state.
Restoring data policies would require new resources and a reviewed plan.

## State compatibility and extension

Existing environment and Entra group state addresses stay unchanged: `module.power_platform` retains its label,
and `module.azure` is unchanged. Moving environment source files into a child folder does not change those addresses.

The `moved` declaration in `tenant.tf` moves the whole resource from
`module.power_platform.powerplatform_tenant_settings.governance` to `module.tenant.powerplatform_tenant_settings.governance`,
including its counted instance. An upgrade plan should show a state-address move, not tenant-settings destruction or recreation.
Keep this declaration for upgrade compatibility with states that still use the old address.

For an existing deployment, expect three environment-settings resource additions and two Managed Environment resource additions.
These adopt or update the existing environments' settings; they are not five new environments.
Review the actual plan for the tenant move and any drift, and stop if it proposes unexpected environment or group replacement.
These are expected refactor effects, not a verified live-plan result. No remote-state operation or deployment has been performed for this refactor.

For future IaC domains, add sibling modules alongside the relevant existing modules and expose their inputs, outputs, and tests.
Keep tenant-wide singletons under one owner, never duplicated per environment or across states.
Add folders when they contain an implementation, not as empty placeholders.
Separate environment states are a possible future design, not the current layout: they require a separately planned, explicit state migration
and an ownership decision for shared tenant resources. Splitting tfvars files does not split state.

## GitHub repository setup

In `mawasile/power-platform-terraform-demo`, add these under Settings > Secrets and variables > Actions.

* Secret `AZURE_TENANT_ID`: Microsoft Entra tenant ID
* Secret `AZURE_CLIENT_ID`: application/client ID of the deployment principal
* Secret `MAGIC_NUMBER_PROD`: prod value for the `bal_MagicNumber` environment variable, [see Solution deployment](#environment-variable-values)
* Variable `TF_STATE_STORAGE_ACCOUNT`: existing Azure storage account name
* Variable `TF_STATE_CONTAINER`: existing private blob container name, such as `tfstate`

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
4. Manual runs can instead select `destroy` to plan a teardown. See the teardown section below.

Configure OIDC, repository settings, and backend storage before pushing to `main` for the first deployment.
Deployment uses the committed lockfile and all five tfvars files; it never runs `terraform init -upgrade`.
Both mocked tests and the deployment plan load `infrastructure.tfvars`, `config/azure.tfvars`, `config/environments.tfvars`, `config/solutions.tfvars`, and `config/tenant.tfvars`.
Apply consumes the saved plan rather than reloading different profiles.
Concurrent deployments are serialized and running applies are not cancelled by newer pushes.
Azure Blob leases provide state locking, including protection from other Terraform clients.
Normal runs block plans that delete or replace any resource, and the guard also fails closed on an unreadable or incomplete plan.
Plans stay on the runner and are deleted at the end of the job, not uploaded as artifacts.

### Destroying the demo

> [!CAUTION]
> A destroy deletes the Power Platform environments together with their Dataverse databases and all data in them.
> Deleted environments may be recoverable only for a limited period, if at all. Export anything you need first.

A teardown is manual and deliberately awkward to trigger by accident:

1. Run the workflow on `main` with `destroy` selected and `DESTROY` typed into `confirm_destroy`. Leave `apply` unselected to review the destroy plan without executing it.
2. Re-run with both `destroy` and `apply` selected to execute the reviewed plan.

Pushes never destroy anything: the destroy inputs exist only for manual runs, and a mistyped confirmation fails the job before Terraform runs.
In a destroy run the same guard script switches modes and permits deletions only; any create, update, or replacement in that plan blocks the apply.

The destroy targets `module.power_platform` and `module.azure`, so it removes the environments, their settings, the Managed Environment controls, and the Entra access groups.
It deliberately leaves the tenant settings in place: that resource is protected by `prevent_destroy`, and destroying it would restore pre-management values across the whole tenant.
Remove tenant governance separately and deliberately if you truly intend to stop managing it.
After a destroy the state still exists and remains the source of truth for a later redeployment.

The tenant-settings move supports upgrades from the previous module layout; it is not a general import of existing infrastructure.
If resources exist but are not tracked in this state, coordinate their migration/import before deployment to avoid duplicates.

## Local checks without cloud access

From `infra`, run `terraform init -backend=false -lockfile=readonly`, `terraform fmt -check -recursive`,
`terraform validate`, and `terraform test "-var-file=infrastructure.tfvars" "-var-file=config/azure.tfvars" "-var-file=config/environments.tfvars" "-var-file=config/solutions.tfvars" "-var-file=config/tenant.tfvars"`.
Both providers are mocked during tests. Quote each complete `-var-file=...` argument in PowerShell.
Plain `terraform test` does not load these deployment files and reports missing required variables.
Mock tests do not verify licenses, capacity, live permissions, or service-side enforcement.
Real deployment is performed only through GitHub Actions.
Commit `.terraform.lock.hcl` alongside the infrastructure files.

## References

* [Power Platform OIDC setup and prerequisites](https://raw.githubusercontent.com/microsoft/terraform-provider-power-platform/v4.2.0/docs/guides/oidc.md)
* [AzureAD group permissions](https://raw.githubusercontent.com/hashicorp/terraform-provider-azuread/v3.9.0/docs/resources/group.md)
* [Azure Blob backend OIDC and RBAC](https://developer.hashicorp.com/terraform/language/backend/azurerm)
* [Control environment creation](https://learn.microsoft.com/power-platform/admin/control-environment-creation)
* [Tenant settings resource](https://raw.githubusercontent.com/microsoft/terraform-provider-power-platform/v4.2.0/docs/resources/tenant_settings.md)
* [Managed Environment licensing](https://learn.microsoft.com/power-platform/admin/managed-environment-licensing)
* [Managed Environment sharing limits](https://learn.microsoft.com/power-platform/admin/managed-environment-sharing-limits)
* [Solution checker enforcement](https://learn.microsoft.com/power-platform/admin/managed-environment-solution-checker)
* [Dataverse auditing](https://learn.microsoft.com/power-platform/admin/manage-dataverse-auditing)
* [Environment settings resource](https://registry.terraform.io/providers/microsoft/power-platform/latest/docs/resources/environment_settings)
