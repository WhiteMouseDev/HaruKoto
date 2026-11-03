import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  checkWebRetentionReport,
  REQUIRED_WEB_RETENTION_CASES,
} from '../scripts/check-web-retention-report.mjs';

function passing() {
  return {
    success: true,
    numFailedTests: 0,
    numFailedTestSuites: 0,
    testResults: [
      {
        name: '/workspace/apps/web/src/__tests__/quiz-retention-postgres.test.ts',
        assertionResults: REQUIRED_WEB_RETENTION_CASES.map((title) => ({
          fullName: `real PostgreSQL quiz retention and request races ${title}`,
          status: 'passed',
        })),
      },
    ],
  };
}

test('requires all thirteen real database concurrency and preservation cases', () => {
  assert.equal(REQUIRED_WEB_RETENTION_CASES.length, 13);
  assert.deepEqual(checkWebRetentionReport(passing()), []);
});
test('rejects a missing case even if all remaining tests pass', () => {
  for (let index = 0; index < REQUIRED_WEB_RETENTION_CASES.length; index += 1) {
    const report = passing();
    report.testResults[0].assertionResults.splice(index, 1);
    assert.equal(checkWebRetentionReport(report).length, 1);
  }
});
test('rejects opt-in tests that were skipped, failed, pending or duplicated', () => {
  for (const status of ['skipped', 'pending', 'failed', 'todo']) {
    const report = passing();
    report.testResults[0].assertionResults[0].status = status;
    assert.ok(checkWebRetentionReport(report).length > 0);
  }
  const duplicate = passing();
  duplicate.testResults[0].assertionResults.push(
    duplicate.testResults[0].assertionResults[0]
  );
  assert.ok(checkWebRetentionReport(duplicate).length > 0);
});
test('rejects missing or duplicated suites and unsuccessful reports', () => {
  for (const report of [null, {}, { testResults: [] }])
    assert.ok(checkWebRetentionReport(report).length > 0);
  const duplicate = passing();
  duplicate.testResults.push(duplicate.testResults[0]);
  assert.ok(checkWebRetentionReport(duplicate).length > 0);
  const failed = passing();
  failed.success = false;
  assert.ok(checkWebRetentionReport(failed).length > 0);
});
