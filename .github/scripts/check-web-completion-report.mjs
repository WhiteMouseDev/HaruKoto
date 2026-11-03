import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const fileSuffix = '/src/__tests__/quiz-completion-atomicity.test.ts';
const required = [];
for (const kind of ['normal quiz', 'kana quiz', 'kana stage']) {
  const prefix = `'${kind}' completion atomicity `;
  required.push(
    prefix +
      'commits once and preserves the saved date/score after response loss and next-day replay',
    prefix + 'rechecks completion after competing requests wait, awarding once'
  );
  const failures =
    kind === 'kana stage'
      ? ['stage', 'unlock', 'daily', 'user', 'achievement', 'notification']
      : ['session', 'daily', 'user', 'achievement', 'notification'];
  for (const failure of failures) {
    required.push(
      prefix +
        `rolls back all durable effects after ${failure} fails and retries the same request`
    );
  }
  if (kind !== 'kana stage') {
    required.push(
      prefix +
        'retains read-only completed legacy sessions without backfill or rewards'
    );
  }
}
const start = 'starting a quiz preserves prior sessions ';
required.push(
  start +
    'leaves old answers, completion and XP untouched even after simultaneous starts with no new content',
  start +
    'only explicit completion awards XP when another quiz starts (start-first)',
  start +
    'only explicit completion awards XP when another quiz starts (complete-first)',
  'web completion waits for durable answers does not close, reward or count activity before the final answer is stored',
  'web completion waits for durable answers does not count duplicate attempts or negative time as additional study time'
);
export const REQUIRED_WEB_COMPLETION_CASES = Object.freeze(required);

/** Exact IDs fail closed if a critical regression disappears or becomes skipped. */
export function checkWebCompletionReport(report) {
  if (!report || !Array.isArray(report.testResults))
    return ['Missing Vitest testResults'];
  const suites = report.testResults.filter(
    (suite) =>
      typeof suite.name === 'string' &&
      suite.name.replaceAll('\\', '/').endsWith(fileSuffix)
  );
  if (suites.length !== 1 || !Array.isArray(suites[0]?.assertionResults)) {
    return ['Expected exactly one web completion regression suite'];
  }
  const cases = suites[0].assertionResults;
  const errors = [];
  if (cases.length !== required.length)
    errors.push(
      `Expected ${required.length} web completion cases, found ${cases.length}`
    );
  for (const name of required) {
    const matches = cases.filter((test) => test.fullName === name);
    if (matches.length !== 1)
      errors.push(`Required regression found ${matches.length} times: ${name}`);
    else if (matches[0].status !== 'passed')
      errors.push(`Required regression did not pass: ${name}`);
  }
  if (
    report.success !== true ||
    report.numFailedTests !== 0 ||
    report.numFailedTestSuites !== 0
  ) {
    errors.push('Vitest report is not successful');
  }
  return errors;
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
) {
  try {
    const report = JSON.parse(readFileSync(process.argv[2], 'utf8'));
    const errors = checkWebCompletionReport(report);
    if (errors.length) {
      for (const error of errors) process.stderr.write(`${error}\n`);
      process.exitCode = 1;
    } else {
      process.stdout.write(
        `All ${required.length} required web completion regressions passed without skips.\n`
      );
    }
  } catch {
    process.stderr.write(
      'Cannot read a valid web completion regression report.\n'
    );
    process.exitCode = 1;
  }
}
