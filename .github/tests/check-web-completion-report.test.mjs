import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { test } from 'node:test';
import {
  checkWebCompletionReport,
  REQUIRED_WEB_COMPLETION_CASES,
} from '../scripts/check-web-completion-report.mjs';

function passing() {
  return {
    success: true,
    numFailedTests: 0,
    numFailedTestSuites: 0,
    testResults: [
      {
        name: '/workspace/apps/web/src/__tests__/quiz-completion-atomicity.test.ts',
        assertionResults: REQUIRED_WEB_COMPLETION_CASES.map((fullName) => ({
          fullName,
          status: 'passed',
        })),
      },
    ],
  };
}

test('accepts exactly the required 29 completion and preservation regressions', () => {
  // Seven assertions for the removed automatic settlement are replaced by
  // three preservation/concurrency and two durable-answer completion cases.
  assert.equal(REQUIRED_WEB_COMPLETION_CASES.length, 29);
  assert.deepEqual(checkWebCompletionReport(passing()), []);
});
test('rejects deletion of each required regression', () => {
  for (const name of REQUIRED_WEB_COMPLETION_CASES) {
    const report = passing();
    report.testResults[0].assertionResults =
      report.testResults[0].assertionResults.filter((t) => t.fullName !== name);
    assert.ok(checkWebCompletionReport(report).length > 0, name);
  }
});
test('rejects skipped, pending, failed or todo regressions', () => {
  for (const status of ['skipped', 'pending', 'failed', 'todo']) {
    const report = passing();
    report.testResults[0].assertionResults[0].status = status;
    assert.ok(checkWebCompletionReport(report).length > 0, status);
  }
});
test('rejects a duplicate replacing a deleted test even when the count matches', () => {
  const report = passing();
  report.testResults[0].assertionResults[0] = {
    ...report.testResults[0].assertionResults[1],
  };
  assert.ok(checkWebCompletionReport(report).length > 0);
});
test('rejects absent, renamed and duplicated suites', () => {
  assert.ok(checkWebCompletionReport({}).length > 0);
  assert.ok(checkWebCompletionReport({ testResults: [] }).length > 0);
  const renamed = passing();
  renamed.testResults[0].name = '/other.test.ts';
  assert.ok(checkWebCompletionReport(renamed).length > 0);
  const duplicate = passing();
  duplicate.testResults.push(duplicate.testResults[0]);
  assert.ok(checkWebCompletionReport(duplicate).length > 0);
});
test('rejects unsuccessful reports with otherwise passing required tests', () => {
  const report = passing();
  report.success = false;
  assert.ok(checkWebCompletionReport(report).length > 0);
});
test('accepts other passing suites and Windows report paths', () => {
  const report = passing();
  report.testResults[0].name =
    'C:\\repo\\apps\\web\\src\\__tests__\\quiz-completion-atomicity.test.ts';
  report.testResults.push({ name: '/other.test.ts', assertionResults: [] });
  assert.deepEqual(checkWebCompletionReport(report), []);
});
test('CLI rejects unreadable and malformed JSON, accepts valid data', () => {
  const dir = mkdtempSync(join(tmpdir(), 'hk-web-completion-'));
  try {
    const path = join(dir, 'results.json');
    const run = () =>
      spawnSync(process.execPath, [
        '.github/scripts/check-web-completion-report.mjs',
        path,
      ]);
    assert.equal(run().status, 1);
    writeFileSync(path, '{');
    assert.equal(run().status, 1);
    writeFileSync(path, JSON.stringify(passing()));
    assert.equal(run().status, 0);
    const skipped = passing();
    skipped.testResults[0].assertionResults[0].status = 'skipped';
    writeFileSync(path, JSON.stringify(skipped));
    assert.equal(run().status, 1);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
