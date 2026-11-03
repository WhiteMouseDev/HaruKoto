import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  checkStopWebReport,
  REQUIRED_STOP_SUITES,
} from '../scripts/check-stop-web-report.mjs';

function passing() {
  return {
    success: true,
    numFailedTests: 0,
    numFailedTestSuites: 0,
    testResults: REQUIRED_STOP_SUITES.map((file) => ({
      name: `/workspace/apps/web/src/__tests__/${file}`,
      assertionResults: [{ fullName: 'required', status: 'passed' }],
    })),
  };
}
test('accepts all five suites passing', () =>
  assert.deepEqual(checkStopWebReport(passing()), []));
test('rejects deletion of any required suite', () => {
  for (let index = 0; index < REQUIRED_STOP_SUITES.length; index++) {
    const report = passing();
    report.testResults.splice(index, 1);
    assert.ok(checkStopWebReport(report).length);
  }
});
test('rejects skipped/pending/failed tests and empty suites', () => {
  for (const status of ['skipped', 'pending', 'failed', 'todo']) {
    const report = passing();
    report.testResults[0].assertionResults[0].status = status;
    assert.ok(checkStopWebReport(report).length);
  }
  const empty = passing();
  empty.testResults[0].assertionResults = [];
  assert.ok(checkStopWebReport(empty).length);
});
test('rejects duplicate suites and unsuccessful reports', () => {
  const duplicate = passing();
  duplicate.testResults.push(duplicate.testResults[0]);
  assert.ok(checkStopWebReport(duplicate).length);
  const failed = passing();
  failed.success = false;
  assert.ok(checkStopWebReport(failed).length);
  assert.ok(checkStopWebReport({}).length);
});
