import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

// Replacements appear as create,delete or delete,create and are blocked like deletions.
const SAFE_ACTIONS = ['no-op', 'read', 'create', 'update'];
const KNOWN_ACTIONS = [...SAFE_ACTIONS, 'delete', 'create,delete', 'delete,create'];

export function checkPlan(plan, destroyRequested = false) {
  // Destroy runs deliberately target module.solutions/power_platform/azure to
  // protect module.tenant, which makes Terraform mark the plan incomplete.
  if (!plan || !/^1\./.test(plan.format_version ?? '') ||
      !plan.planned_values || plan.errored ||
      (!destroyRequested && plan.complete === false) ||
      !Array.isArray(plan.resource_changes ?? [])) {
    throw new Error('Invalid or incomplete Terraform plan; apply is blocked.');
  }

  let changes = 0;
  for (const resource of plan.resource_changes ?? []) {
    const actions = resource.change?.actions;
    const action = Array.isArray(actions) ? actions.join(',') : '';
    if (!KNOWN_ACTIONS.includes(action)) {
      throw new Error('Unknown resource action; apply is blocked.');
    }
    if (action === 'no-op' || action === 'read') continue;
    if (destroyRequested) {
      // A destroy run must not sneak in creates, updates, or replacements.
      if (action !== 'delete') {
        throw new Error('A destroy run may only delete resources; apply is blocked.');
      }
    } else if (actions.includes('delete')) {
      throw new Error('Plan contains deletions or replacements; automatic apply is blocked.');
    }
    changes += 1;
  }
  return changes;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const destroyRequested = process.env.DESTROY_REQUESTED === 'true';
    const changes = checkPlan(JSON.parse(readFileSync(0, 'utf8')), destroyRequested);
    console.log(destroyRequested
      ? `Destroy guard passed. Resources to destroy: ${changes}.`
      : `Deletion/replacement guard passed. Resource changes to apply: ${changes}.`);
  } catch (error) {
    // JSON parse errors may contain snippets of sensitive plan data.
    console.error(`::error::${error instanceof SyntaxError ? 'Invalid plan JSON; apply is blocked.' : error.message}`);
    process.exitCode = 1;
  }
}
