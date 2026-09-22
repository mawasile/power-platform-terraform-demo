import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { checkPlan } from './check-terraform-plan.mjs';

const plan = (resource_changes = []) => ({ format_version: '1.2', planned_values: {}, resource_changes });
const change = (actions) => ({ address: 'module.power_platform.powerplatform_environment.environments["dev"]', mode: 'managed', change: { actions } });

test('creates and updates are allowed and counted', () => {
  assert.equal(checkPlan(plan([change(['create']), change(['update'])])), 2);
  assert.equal(checkPlan(plan([change(['no-op']), change(['read'])])), 0);
  assert.equal(checkPlan(plan()), 0);
});

test('deletions are blocked', () => {
  assert.throws(() => checkPlan(plan([change(['delete'])])), /deletions or replacements/);
  assert.throws(() => checkPlan(plan([change(['create']), change(['delete'])])), /deletions or replacements/);
});

test('both replacement orderings are blocked', () => {
  for (const actions of [['create', 'delete'], ['delete', 'create']]) {
    assert.throws(() => checkPlan(plan([change(actions)])), /deletions or replacements/);
  }
});

test('unknown actions fail closed', () => {
  assert.throws(() => checkPlan(plan([{}])), /Unknown/);
  assert.throws(() => checkPlan(plan([change(['forget'])])), /Unknown/);
  assert.throws(() => checkPlan(plan([{ change: { actions: 'create' } }])), /Unknown/);
});

test('malformed and incomplete plans fail closed', () => {
  for (const value of [null, {}, { ...plan(), format_version: '2.0' }, { ...plan(), resource_changes: {} }, { ...plan(), errored: true }, { ...plan(), complete: false }]) {
    assert.throws(() => checkPlan(value), /Invalid or incomplete/);
  }
});

const script = fileURLToPath(new URL('./check-terraform-plan.mjs', import.meta.url));
const run = (input) => spawnSync(process.execPath, [script], { input, encoding: 'utf8' });

test('CLI consumes stdin and reports the guard result', () => {
  const allowed = run(JSON.stringify(plan([change(['create'])])));
  assert.equal(allowed.status, 0, allowed.stderr);
  assert.match(allowed.stdout, /guard passed/);

  const blocked = run(JSON.stringify(plan([change(['delete'])])));
  assert.equal(blocked.status, 1);
  assert.match(blocked.stderr, /deletions or replacements/);
});

test('CLI rejects malformed JSON without exposing plan fragments', () => {
  const result = run('PRIVATE_SENTINEL');
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Invalid plan JSON/);
  assert.doesNotMatch(result.stderr, /PRIVATE_SENTINEL/);
});
