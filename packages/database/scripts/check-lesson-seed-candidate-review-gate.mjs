import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PACKAGE_DIR = join(SCRIPT_DIR, '..');
const DEFAULT_REVIEW_DIR = join(PACKAGE_DIR, 'data', 'curriculum', 'lesson-seed-candidate-review');
const LEVELS = new Set(['N5', 'N4', 'N3', 'N2', 'N1']);
const DECISIONS = ['APPROVED', 'PENDING', 'NEEDS_EDIT', 'REJECTED'];

function usage() {
  return [
    'Usage: node scripts/check-lesson-seed-candidate-review-gate.mjs [--level N4] [--candidate <candidateId>] [--in <reviewDir>]',
    '',
    'Blocks candidate promotion until matching review rows are APPROVED.',
  ].join('\n');
}

function parseArgs(argv) {
  const args = {
    level: null,
    candidateId: null,
    reviewDir: DEFAULT_REVIEW_DIR,
    help: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--') continue;
    if (arg === '--level') {
      const value = argv[index + 1]?.toUpperCase();
      if (!value || value.startsWith('--')) throw new Error('--level requires a JLPT level');
      args.level = value;
      index += 1;
      continue;
    }
    if (arg.startsWith('--level=')) {
      args.level = arg.slice('--level='.length).toUpperCase();
      continue;
    }
    if (arg === '--candidate') {
      const value = argv[index + 1];
      if (!value || value.startsWith('--')) throw new Error('--candidate requires a candidateId');
      args.candidateId = value;
      index += 1;
      continue;
    }
    if (arg.startsWith('--candidate=')) {
      args.candidateId = arg.slice('--candidate='.length);
      continue;
    }
    if (arg === '--in') {
      const value = argv[index + 1];
      if (!value || value.startsWith('--')) throw new Error('--in requires a directory path');
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
  if (args.candidateId && !/^lsc-[a-z0-9][a-z0-9-]*$/.test(args.candidateId)) {
    throw new Error('--candidate must match lsc-<slug>');
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
    addIssue(issues, 'FAIL', 'lesson seed candidate review gate', `Missing review directory: ${reviewDir}`);
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

function candidateLabel(row) {
  return [row.candidateId, row.title].filter(Boolean).join(' ');
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
      targetLevel ?? 'lesson seed candidate review gate',
      targetLevel ? `No candidate review packet found for ${targetLevel}.` : 'No candidate review packet JSON files found.',
    );
  }

  return packets;
}

function summarizePackets(packets, targetCandidateId, issues) {
  const counts = emptyDecisionCounts();
  const blockers = [];
  let rowCount = 0;

  for (const { fileName, packet } of packets) {
    if (!Array.isArray(packet.reviewRows)) {
      addIssue(issues, 'FAIL', fileName, 'reviewRows must be an array.');
      continue;
    }

    for (const [index, row] of packet.reviewRows.entries()) {
      if (targetCandidateId && row?.candidateId !== targetCandidateId) continue;

      rowCount += 1;
      const decision = row?.reviewerDecision;
      const scope = `${fileName}#${row?.reviewId ?? `row-${index + 1}`}`;
      if (!DECISIONS.includes(decision)) {
        addIssue(issues, 'FAIL', scope, `Unknown reviewerDecision: ${decision ?? '<missing>'}`);
        blockers.push({ scope, decision: decision ?? '<missing>', candidate: candidateLabel(row ?? {}) });
        continue;
      }

      counts[decision] += 1;
      if (decision !== 'APPROVED') {
        blockers.push({
          scope,
          decision,
          candidate: candidateLabel(row),
          notes: typeof row.reviewerNotes === 'string' ? row.reviewerNotes.trim() : '',
        });
      }
    }
  }

  if (targetCandidateId && rowCount === 0) {
    addIssue(issues, 'FAIL', targetCandidateId, 'No matching candidate review row found.');
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
  const { counts, blockers, rowCount } = summarizePackets(packets, args.candidateId, issues);
  const failures = issues.filter((issue) => issue.level === 'FAIL');

  console.log('Lesson seed candidate review approval gate summary');
  console.log(`- packets: ${packets.length}`);
  console.log(`- levels: ${packets.map(({ packet }) => packet.level).join(', ') || 'none'}`);
  console.log(`- candidate: ${args.candidateId ?? 'all'}`);
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
    console.log('Blocked candidate review rows');
    for (const blocker of blockers) {
      const candidate = blocker.candidate ? ` ${blocker.candidate}` : '';
      const notes = blocker.notes ? ` notes="${blocker.notes}"` : '';
      console.log(`- ${blocker.scope}:${candidate} -> ${blocker.decision}${notes}`);
    }
  }

  if (failures.length > 0 || blockers.length > 0 || rowCount === 0) {
    console.log('');
    console.log('Lesson seed candidate review approval gate blocked.');
    process.exit(1);
  }

  console.log('Lesson seed candidate review approval gate passed.');
}

main();
