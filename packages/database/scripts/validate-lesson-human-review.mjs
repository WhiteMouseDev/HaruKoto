import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildPacket } from './prepare-lesson-human-review.mjs';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PACKAGE_DIR = join(SCRIPT_DIR, '..');
const REVIEW_DIR = join(PACKAGE_DIR, 'data', 'curriculum', 'lesson-human-review');
const LEVELS = new Set(['N5', 'N4', 'N3', 'N2', 'N1']);
const STATUSES = new Set(['draft']);
const DECISIONS = new Set(['PENDING', 'APPROVED', 'NEEDS_EDIT', 'REJECTED']);
const DECISIONS_REQUIRING_NOTES = new Set(['NEEDS_EDIT', 'REJECTED']);

function usage() {
  return 'Usage: node scripts/validate-lesson-human-review.mjs [--in <reviewDir>]';
}

function parseArgs(argv) {
  const args = {
    reviewDir: REVIEW_DIR,
    help: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--') continue;
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
    addIssue(issues, 'FAIL', 'lesson human review', `Missing review directory: ${reviewDir}`);
    return [];
  }

  const files = readdirSync(reviewDir)
    .filter((name) => name.endsWith('.json'))
    .filter((name) => !name.startsWith('_'))
    .sort()
    .map((name) => join(reviewDir, name));

  if (files.length === 0) {
    addIssue(issues, 'FAIL', 'lesson human review', `No review packet JSON files found in ${reviewDir}`);
  }

  return files;
}

function canonicalize(value) {
  if (Array.isArray(value)) return value.map((item) => canonicalize(item));
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonicalize(value[key])]));
}

function stripReviewerState(packet) {
  if (!packet || typeof packet !== 'object') return packet;
  if (!Array.isArray(packet.reviewRows)) return packet;
  return {
    ...packet,
    reviewRows: packet.reviewRows.map((row) => {
      if (!row || typeof row !== 'object') return row;
      const { reviewerDecision, reviewerNotes, ...rest } = row;
      return rest;
    }),
  };
}

function packetsMatchIgnoringReviewerState(actual, expected) {
  return (
    JSON.stringify(canonicalize(stripReviewerState(actual))) ===
    JSON.stringify(canonicalize(stripReviewerState(expected)))
  );
}

function validateReviewRows(packet, fileName, issues) {
  if (!Array.isArray(packet.reviewRows)) {
    addIssue(issues, 'FAIL', fileName, 'reviewRows must be an array.');
    return 0;
  }

  const seenReviewIds = new Set();
  packet.reviewRows.forEach((row, index) => {
    const scope = `${fileName}#${row?.reviewId ?? `row-${index + 1}`}`;
    if (!row || typeof row !== 'object') {
      addIssue(issues, 'FAIL', scope, 'Review row must be an object.');
      return;
    }

    if (typeof row.reviewId !== 'string' || row.reviewId.trim() === '') {
      addIssue(issues, 'FAIL', scope, 'reviewId must be a non-empty string.');
    } else if (seenReviewIds.has(row.reviewId)) {
      addIssue(issues, 'FAIL', scope, 'reviewId must be unique within a packet.');
    } else {
      seenReviewIds.add(row.reviewId);
    }

    if (!DECISIONS.has(row.reviewerDecision)) {
      addIssue(
        issues,
        'FAIL',
        scope,
        `reviewerDecision must be one of ${Array.from(DECISIONS).join(', ')}.`,
      );
    }

    if (typeof row.reviewerNotes !== 'string') {
      addIssue(issues, 'FAIL', scope, 'reviewerNotes must be a string.');
    } else if (DECISIONS_REQUIRING_NOTES.has(row.reviewerDecision) && row.reviewerNotes.trim() === '') {
      addIssue(issues, 'FAIL', scope, `${row.reviewerDecision} requires reviewerNotes.`);
    }
  });

  return packet.reviewRows.length;
}

function validatePacket(packet, fileName, issues) {
  if (!packet || typeof packet !== 'object' || Array.isArray(packet)) {
    addIssue(issues, 'FAIL', fileName, 'Review packet must be a JSON object.');
    return 0;
  }

  if (packet.schemaVersion !== 1) {
    addIssue(issues, 'FAIL', fileName, 'schemaVersion must be 1.');
  }
  if (!STATUSES.has(packet.status)) {
    addIssue(issues, 'FAIL', fileName, `status must be one of ${Array.from(STATUSES).join(', ')}.`);
  }
  if (packet.reviewKind !== 'lesson_human_curriculum_review') {
    addIssue(issues, 'FAIL', fileName, 'reviewKind must be lesson_human_curriculum_review.');
  }
  if (!LEVELS.has(packet.level)) {
    addIssue(issues, 'FAIL', fileName, 'level must be one of N5, N4, N3, N2, N1.');
  }

  const rowCount = validateReviewRows(packet, fileName, issues);
  if (LEVELS.has(packet.level)) {
    const expectedPacket = buildPacket(packet.level);
    if (!packetsMatchIgnoringReviewerState(packet, expectedPacket)) {
      addIssue(
        issues,
        'FAIL',
        fileName,
        `Packet drifted from lesson/TTS source data. Run lessons:review:prepare -- --level ${packet.level}.`,
      );
    }
  }

  return rowCount;
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
  const files = listReviewFiles(args.reviewDir, issues);
  let rowCount = 0;

  for (const filePath of files) {
    const fileName = filePath.replace(`${args.reviewDir}/`, '');
    try {
      const packet = readJson(filePath);
      rowCount += validatePacket(packet, fileName, issues);
    } catch (error) {
      addIssue(issues, 'FAIL', fileName, `Invalid JSON: ${error.message}`);
    }
  }

  const failures = issues.filter((issue) => issue.level === 'FAIL');

  console.log('Lesson human review validation summary');
  console.log(`- files: ${files.length}`);
  console.log(`- rows: ${rowCount}`);
  console.log(`- failures: ${failures.length}`);

  for (const issue of issues) {
    console.log(`[${issue.level}] ${issue.scope}: ${issue.message}`);
  }

  if (failures.length > 0) {
    process.exit(1);
  }

  console.log('Lesson human review validation passed.');
}

main();
