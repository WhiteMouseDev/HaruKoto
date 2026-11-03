import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export const REQUIRED_WEB_RETENTION_CASES = Object.freeze([
  'serializes duplicate and stale-tab answers without a second SRS effect',
  'keeps wrong-to-correct learning attempts while rejecting stale predecessors',
  'rejects premature completion and resolves concurrent final-answer/completion exactly once',
  'finds a thirty-day-old quiz behind empty sessions, resumes it and starts another without settling it',
  'settles old answers once without creating attendance and promotes only a new saved answer',
  'preserves pre-existing day credit null before completion adds XP',
  'preserves pre-existing day credit true before completion adds XP',
  'preserves pre-existing day credit false before completion adds XP',
  'never demotes a concurrent real answer when recovering an old completion',
  'serializes actual kana progress with delayed completion without losing day credit',
  'compatibility OFF never creates FALSE for a new delayed-completion day',
  'compatibility OFF preserves stored day credit false during delayed completion',
  'compatibility OFF preserves stored day credit true during delayed completion',
]);

export function checkWebRetentionReport(report) {
  const suites = report?.testResults?.filter((suite) =>
    suite.name
      ?.replaceAll('\\', '/')
      .endsWith('/src/__tests__/quiz-retention-postgres.test.ts')
  );
  if (
    !Array.isArray(suites) ||
    suites.length !== 1 ||
    !Array.isArray(suites[0].assertionResults)
  )
    return ['Expected exactly one real-PostgreSQL web retention suite'];
  const tests = suites[0].assertionResults;
  const errors = [];
  for (const title of REQUIRED_WEB_RETENTION_CASES) {
    const matching = tests.filter(
      (test) =>
        test.fullName ===
        `real PostgreSQL quiz retention and request races ${title}`
    );
    if (matching.length !== 1 || matching[0].status !== 'passed')
      errors.push(
        `Required real-PostgreSQL regression missing, duplicated or not passed: ${title}`
      );
  }
  if (
    report.success !== true ||
    report.numFailedTests !== 0 ||
    report.numFailedTestSuites !== 0
  )
    errors.push('Vitest report is not successful');
  return errors;
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
) {
  try {
    const errors = checkWebRetentionReport(
      JSON.parse(readFileSync(process.argv[2], 'utf8'))
    );
    if (errors.length) {
      for (const error of errors) process.stderr.write(`${error}\n`);
      process.exitCode = 1;
    } else
      process.stdout.write(
        'All required real-PostgreSQL web retention regressions passed without skips.\n'
      );
  } catch {
    process.stderr.write(
      'Cannot read a valid web retention regression report.\n'
    );
    process.exitCode = 1;
  }
}
