import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

// The three existing policies explicitly approved for removal. Never use a
// resource-type wildcard here: new policies must not inherit this exception.
export const approvedPolicies = Object.freeze({
  'module.power_platform.powerplatform_data_loss_prevention_policy.environment["dev"]': {
    id: '27f9d984-79e3-4d7c-93ec-9e91784cd79c',
    name: 'Demo - Dev - Strict DLP',
  },
  'module.power_platform.powerplatform_data_loss_prevention_policy.environment["test"]': {
    id: 'cdc5be60-991c-477e-909a-9e392dddbe4d',
    name: 'Demo - Test - Strict DLP',
  },
  'module.power_platform.powerplatform_data_loss_prevention_policy.environment["prod"]': {
    id: 'af01330c-72e6-476d-9c90-930388bd1085',
    name: 'Demo - Prod - Strict DLP',
  },
});

export function checkPlan(plan, allowDemoDlpDeletion = false) {
  if (!plan || !/^1\./.test(plan.format_version ?? '') ||
      !plan.planned_values || plan.errored || plan.complete === false ||
      !Array.isArray(plan.resource_changes ?? [])) {
    throw new Error('Invalid or incomplete Terraform plan; apply is blocked.');
  }

  const deleted = [];
  for (const resource of plan.resource_changes ?? []) {
    const actions = resource.change?.actions;
    const action = Array.isArray(actions) ? actions.join(',') : '';
    if (!['no-op', 'read', 'create', 'update', 'delete', 'create,delete', 'delete,create'].includes(action)) {
      throw new Error('Unknown resource action; apply is blocked.');
    }
    if (action === 'no-op' || action === 'read') continue;

    if (allowDemoDlpDeletion) {
      const policy = Object.hasOwn(approvedPolicies, resource.address) ? approvedPolicies[resource.address] : null;
      if (action !== 'delete' || resource.mode !== 'managed' || !policy ||
          resource.change.before?.id !== policy.id ||
          resource.change.before?.display_name !== policy.name) {
        throw new Error('Cleanup permits only deletion of the three approved demo DLP policies; all other changes are blocked.');
      }
      if (deleted.includes(resource.address)) throw new Error('Duplicate resource change; apply is blocked.');
      deleted.push(resource.address);
    } else if (actions.includes('delete')) {
      throw new Error('Plan contains deletions or replacements; automatic apply is blocked.');
    }
  }
  return deleted;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const plan = JSON.parse(readFileSync(0, 'utf8'));
    const cleanup = process.env.ALLOW_DEMO_DLP_DELETION === 'true';
    const deleted = checkPlan(plan, cleanup);
    console.log(cleanup ? `Approved demo DLP deletions: ${deleted.length}. No other resource changes permitted.` : 'Deletion/replacement guard passed.');
  } catch (error) {
    // JSON parse errors may contain snippets of sensitive plan data.
    console.error(`::error::${error instanceof SyntaxError ? 'Invalid plan JSON; apply is blocked.' : error.message}`);
    process.exitCode = 1;
  }
}