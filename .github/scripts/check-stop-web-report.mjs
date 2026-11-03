import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export const REQUIRED_STOP_SUITES = Object.freeze([
  'study-write-stop-policy.test.ts',
  'study-write-stop-proxy.test.ts',
  'study-write-stop-quiz-ui.test.tsx',
  'study-write-stop-kana-ui.test.tsx',
  'study-write-stop-kana-complete-ui.test.tsx',
]);

export function checkStopWebReport(report) {
  if (!report || !Array.isArray(report.testResults))
    return ['Missing Vitest results'];
  const errors = [];
  if (
    report.success !== true ||
    report.numFailedTests !== 0 ||
    report.numFailedTestSuites !== 0
  )
    errors.push('Vitest did not succeed');
  for (const file of REQUIRED_STOP_SUITES) {
    const suites = report.testResults.filter(
      (suite) =>
        typeof suite?.name === 'string' &&
        suite.name.replaceAll('\\', '/').endsWith(`/src/__tests__/${file}`)
    );
    if (
      suites.length !== 1 ||
      !Array.isArray(suites[0]?.assertionResults) ||
      suites[0].assertionResults.length === 0
    ) {
      errors.push(`Missing or duplicate STOP suite: ${file}`);
      continue;
    }
    if (suites[0].assertionResults.some((test) => test.status !== 'passed'))
      errors.push(`STOP suite has a failed/skipped/pending test: ${file}`);
  }
  return errors;
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
) {
  try {
    const errors = checkStopWebReport(
      JSON.parse(readFileSync(process.argv[2], 'utf8'))
    );
    if (errors.length) {
      errors.forEach((error) => process.stderr.write(`${error}\n`));
      process.exitCode = 1;
    } else
      process.stdout.write(
        'All five required STOP suites passed without skips.\n'
      );
  } catch {
    process.stderr.write('Cannot read a valid STOP web report.\n');
    process.exitCode = 1;
  }
}
