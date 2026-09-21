import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { approvedPolicies, checkPlan } from './check-terraform-plan.mjs';

const plan = (resource_changes = []) => ({ format_version: '1.2', planned_values: {}, resource_changes });
const changes = Object.entries(approvedPolicies).map(([address, policy]) => ({
  address,
  mode: 'managed',
  change: { actions: ['delete'], before: { id: policy.id, display_name: policy.name }, after: null },
}));

test('normal runs reject even the approved DLP deletions', () => {
  assert.throws(() => checkPlan(plan(changes)), /deletions or replacements/);
});

test('explicit cleanup permits only the three exact live policies', () => {
  assert.deepEqual(checkPlan(plan(changes), true), Object.keys(approvedPolicies));
});

test('cleanup can resume after partial completion or run idempotently', () => {
  assert.equal(checkPlan(plan(changes.slice(0, 1)), true).length, 1);
  assert.deepEqual(checkPlan(plan(), true), []);
});

test('cleanup rejects unrelated deletions and another policy address', () => {
  for (const address of ['module.azure.azuread_group.environment_access["dev"]', 'module.power_platform.powerplatform_data_loss_prevention_policy.environment["other"]']) {
    assert.throws(() => checkPlan(plan([{ ...changes[0], address }]), true), /only deletion/);
  }
});

test('cleanup rejects changed policy IDs or names', () => {
  for (const before of [{ ...changes[0].change.before, id: 'another-policy' }, { ...changes[0].change.before, display_name: 'Another policy' }]) {
    assert.throws(() => checkPlan(plan([{ ...changes[0], change: { ...changes[0].change, before } }]), true), /only deletion/);
  }
});

test('cleanup rejects updates, creates, and both replacement orderings', () => {
  for (const actions of [['update'], ['create'], ['create', 'delete'], ['delete', 'create']]) {
    assert.throws(() => checkPlan(plan([{ ...changes[0], change: { ...changes[0].change, actions } }]), true), /only deletion/);
  }
});

test('normal runs allow creation and update but block replacement', () => {
  for (const actions of [['create'], ['update'], ['no-op'], ['read']]) {
    assert.deepEqual(checkPlan(plan([{ change: { actions } }])), []);
  }
  for (const actions of [['create', 'delete'], ['delete', 'create']]) {
    assert.throws(() => checkPlan(plan([{ change: { actions } }])), /deletions or replacements/);
  }
});

test('no-op and data reads are allowed during cleanup', () => {
  assert.deepEqual(checkPlan(plan([{ change: { actions: ['no-op'] } }, { change: { actions: ['read'] } }]), true), []);
});

test('malformed and incomplete plans fail closed', () => {
  for (const value of [null, {}, { ...plan(), format_version: '2.0' }, { ...plan(), resource_changes: {} }, { ...plan(), errored: true }, { ...plan(), complete: false }]) {
    assert.throws(() => checkPlan(value, true), /Invalid or incomplete/);
  }
  assert.throws(() => checkPlan(plan([{}])), /Unknown/);
  assert.throws(() => checkPlan(plan([{ change: { actions: ['forget'] } }]), true), /Unknown/);
});

test('duplicate deletions and non-managed targets fail closed', () => {
  assert.throws(() => checkPlan(plan([changes[0], changes[0]]), true), /Duplicate/);
  assert.throws(() => checkPlan(plan([{ ...changes[0], mode: 'data' }]), true), /only deletion/);
});

const script = fileURLToPath(new URL('./check-terraform-plan.mjs', import.meta.url));
test('CLI consumes stdin and requires the exact cleanup flag', () => {
  for (const flag of ['false', '', 'TRUE', 'true']) {
    const result = spawnSync(process.execPath, [script], {
      input: JSON.stringify(plan(changes)),
      encoding: 'utf8',
      env: { ...process.env, ALLOW_DEMO_DLP_DELETION: flag },
    });
    assert.equal(result.status, flag === 'true' ? 0 : 1, result.stderr);
  }
});

test('CLI rejects malformed JSON without exposing plan fragments', () => {
  const result = spawnSync(process.execPath, [script], {
    input: 'PRIVATE_SENTINEL',
    encoding: 'utf8',
  });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Invalid plan JSON/);
  assert.doesNotMatch(result.stderr, /PRIVATE_SENTINEL/);
});