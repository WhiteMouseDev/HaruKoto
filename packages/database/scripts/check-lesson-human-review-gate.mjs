import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PACKAGE_DIR = join(SCRIPT_DIR, '..');
const DEFAULT_REVIEW_DIR = join(PACKAGE_DIR, 'data', 'curriculum', 'lesson-human-review');
const LEVELS = new Set(['N5', 'N4', 'N3', 'N2', 'N1']);
const DECISIONS = ['APPROVED', 'PENDING', 'NEEDS_EDIT', 'REJECTED'];

function usage() {
  return 'Usage: node scripts/check-lesson-human-review-gate.mjs [--level N4] [--in <reviewDir>]';
}

function parseArgs(argv) {
  const args = {
    level: null,
    reviewDir: DEFAULT_REVIEW_DIR,
    help: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--') continue;
    if (arg === '--level') {
      const value = argv[index + 1]?.toUpperCase();
      if (!value || value.startsWith('--')) {
        throw new Error('--level requires a JLPT level');
      }
      args.level = value;
      index += 1;
      continue;
    }
    if (arg.startsWith('--level=')) {
      args.level = arg.slice('--level='.length).toUpperCase();
      continue;
    }
    if (arg === '--in') {
      const value = argv[index + 1];
      if (!value || value.startsWith('--')) {
        throw new Error('--in requires a directory path');
      }
      args.reviewDir = resolve(process.cwd(), value);
      index += 1;
      continue;
    }
    if (arg.startsWith('--in=')) {
      args.reviewDir = resolve(process.cwd(), arg.slice('--in='.length));
      continue;
    }
    if (arg === '--help' || arg === '-h') {
      args.help = true;
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  if (args.level && !LEVELS.has(args.level)) {
    throw new Error('--level must be one of N1, N2, N3, N4, N5');
  }

  return args;
}

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, 'utf8'));
}

function addIssue(rows, level, scope, message) {
  rows.push({ level, scope, message });
}

function listReviewFiles(reviewDir, issues) {
  if (!existsSync(reviewDir)) {
    addIssue(issues, 'FAIL', 'lesson human review gate', `Missing review directory: ${reviewDir}`);
    return [];
  }

  return readdirSync(reviewDir)
    .filter((name) => name.endsWith('.json'))
    .filter((name) => !name.startsWith('_'))
    .sort()
    .map((name) => join(reviewDir, name));
}

function emptyDecisionCounts() {
  return Object.fromEntries(DECISIONS.map((decision) => [decision, 0]));
}

function lessonLabel(row) {
  return [row.lessonId, row.title].filter(Boolean).join(' ');
}

function loadPackets(reviewDir, targetLevel, issues) {
  const packets = [];

  for (const filePath of listReviewFiles(reviewDir, issues)) {
    const fileName = filePath.replace(`${reviewDir}/`, '');
    try {
      const packet = readJson(filePath);
      if (targetLevel && packet.level !== targetLevel) continue;
      packets.push({ fileName, packet });
    } catch (error) {
      addIssue(issues, 'FAIL', fileName, `Invalid JSON: ${error.message}`);
    }
  }

  if (packets.length === 0) {
    addIssue(
      issues,
      'FAIL',
      targetLevel ?? 'lesson human review gate',
      targetLevel ? `No review packet found for ${targetLevel}.` : 'No review packet JSON files found.',
    );
  }

  return packets;
}

function summarizePackets(packets, issues) {
  const counts = emptyDecisionCounts();
  const blockers = [];
  let rowCount = 0;

  for (const { fileName, packet } of packets) {
    if (!Array.isArray(packet.reviewRows)) {
      addIssue(issues, 'FAIL', fileName, 'reviewRows must be an array.');
      continue;
    }

    for (const [index, row] of packet.reviewRows.entries()) {
      rowCount += 1;
      const decision = row?.reviewerDecision;
      const scope = `${fileName}#${row?.reviewId ?? `row-${index + 1}`}`;
      if (!DECISIONS.includes(decision)) {
        addIssue(issues, 'FAIL', scope, `Unknown reviewerDecision: ${decision ?? '<missing>'}`);
        blockers.push({ scope, decision: decision ?? '<missing>', lesson: lessonLabel(row ?? {}) });
        continue;
      }

      counts[decision] += 1;
      if (decision !== 'APPROVED') {
        blockers.push({
          scope,
          decision,
          lesson: lessonLabel(row),
          notes: typeof row.reviewerNotes === 'string' ? row.reviewerNotes.trim() : '',
        });
      }
    }
  }

  return { counts, blockers, rowCount };
}

function main() {
  let args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    console.error('');
    console.error(usage());
    process.exit(2);
  }

  if (args.help) {
    console.log(usage());
    return;
  }

  const issues = [];
  const packets = loadPackets(args.reviewDir, args.level, issues);
  const { counts, blockers, rowCount } = summarizePackets(packets, issues);
  const failures = issues.filter((issue) => issue.level === 'FAIL');

  console.log('Lesson human review approval gate summary');
  console.log(`- packets: ${packets.length}`);
  console.log(`- levels: ${packets.map(({ packet }) => packet.level).join(', ') || 'none'}`);
  console.log(`- rows: ${rowCount}`);
  for (const decision of DECISIONS) {
    console.log(`- ${decision}: ${counts[decision]}`);
  }
  console.log(`- blockers: ${blockers.length}`);

  for (const issue of issues) {
    console.log(`[${issue.level}] ${issue.scope}: ${issue.message}`);
  }

  if (blockers.length > 0) {
    console.log('');
    console.log('Blocked review rows');
    for (const blocker of blockers) {
      const lesson = blocker.lesson ? ` ${blocker.lesson}` : '';
      const notes = blocker.notes ? ` notes="${blocker.notes}"` : '';
      console.log(`- ${blocker.scope}:${lesson} -> ${blocker.decision}${notes}`);
    }
  }

  if (failures.length > 0 || blockers.length > 0 || rowCount === 0) {
    console.log('');
    console.log('Lesson human review approval gate blocked.');
    process.exit(1);
  }

  console.log('Lesson human review approval gate passed.');
}

main();
