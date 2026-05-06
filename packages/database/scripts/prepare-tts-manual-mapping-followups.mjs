import { existsSync, readdirSync, readFileSync, writeFileSync } from 'fs';
import { dirname, join, resolve } from 'path';
import { fileURLToPath, pathToFileURL } from 'url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PACKAGE_DIR = join(SCRIPT_DIR, '..');
const DEFAULT_REVIEW_DIR = join(PACKAGE_DIR, 'data', 'curriculum', 'tts-manual-mapping-review');
const DEFAULT_OUT_FILE = join(DEFAULT_REVIEW_DIR, '_followups.json');
const DECISION_ORDER = [
  'APPROVED',
  'PENDING',
  'NEEDS_MAPPING',
  'NEEDS_TOPIC_SPLIT',
  'NEEDS_PARTIAL_OVERRIDE',
  'REJECTED',
];
const FOLLOWUP_ACTIONS = new Map([
  [
    'NEEDS_MAPPING',
    {
      actionType: 'add_topic_mapping',
      recommendedActionKo: 'topic map 후보가 없으므로 topic-grammar-map 또는 topic-vocabulary-map에 후보를 추가한다.',
    },
  ],
  [
    'NEEDS_TOPIC_SPLIT',
    {
      actionType: 'split_topic_or_strengthen_mapping',
      recommendedActionKo: '복수의 non-exact 후보가 있으므로 topic을 더 작은 학습 항목으로 쪼개거나 exact/stronger mapping을 추가한다.',
    },
  ],
  [
    'NEEDS_PARTIAL_OVERRIDE',
    {
      actionType: 'review_partial_override',
      recommendedActionKo: '단일 non-exact 후보를 사용할 수 있는지 검토하고 승인 시 명시적 partial override 근거를 남긴다.',
    },
  ],
]);

const REVIEW_DIR = resolveOption('--in') ?? DEFAULT_REVIEW_DIR;
const OUT_FILE = resolveOption('--out') ?? join(REVIEW_DIR, '_followups.json');

function usage() {
  return [
    'Usage: node scripts/prepare-tts-manual-mapping-followups.mjs [--in <reviewDir>] [--out <file>]',
    '',
    'Builds a reviewer-facing follow-up contract from TTS manual mapping review rows.',
  ].join('\n');
}

function resolveOption(name) {
  const index = process.argv.indexOf(name);
  if (index === -1) return null;
  const value = process.argv[index + 1];
  if (!value || value.startsWith('--')) {
    console.error(`${name} requires a value.\n\n${usage()}`);
    process.exit(1);
  }
  return resolve(process.cwd(), value);
}

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, 'utf-8'));
}

function writeJson(filePath, data) {
  writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`, 'utf-8');
}

function displayPath(filePath) {
  const relativePath = filePath.startsWith(PACKAGE_DIR) ? filePath.slice(PACKAGE_DIR.length + 1) : filePath;
  return relativePath.replaceAll('\\', '/');
}

function normalizeDecision(value) {
  return String(value ?? '').trim().toUpperCase();
}

function sorted(values) {
  return Array.from(new Set(values.filter((value) => value !== null && value !== undefined && value !== ''))).sort();
}

function candidateOrder(candidate) {
  return candidate.grammarOrder ?? candidate.vocabularyOrder ?? 0;
}

function candidateKey(candidate) {
  return [
    candidate.contentType,
    candidate.lookupType,
    candidate.topicId,
    candidate.jlptLevel,
    candidateOrder(candidate),
    candidate.matchType,
    candidate.contentLabel ?? '',
    candidate.contentReading ?? '',
    candidate.meaningKo ?? '',
  ].join('|');
}

function summarizeCandidate(candidate) {
  const summary = {
    contentType: candidate.contentType,
    lookupType: candidate.lookupType,
    topicId: candidate.topicId,
    jlptLevel: candidate.jlptLevel,
    matchType: candidate.matchType,
    contentLabel: candidate.contentLabel ?? null,
    meaningKo: candidate.meaningKo ?? null,
    noteKo: candidate.noteKo ?? null,
  };
  if (candidate.grammarOrder !== undefined) summary.grammarOrder = candidate.grammarOrder;
  if (candidate.vocabularyOrder !== undefined) summary.vocabularyOrder = candidate.vocabularyOrder;
  if (candidate.contentReading !== undefined) summary.contentReading = candidate.contentReading;
  return summary;
}

function makeFollowupId(decision, topicId, contentType) {
  return `tts-followup-${decision.toLowerCase().replaceAll('_', '-')}-${topicId.replace(/^topic-/, '')}-${contentType}`;
}

export function loadManualMappingReviewRows(reviewDir) {
  if (!existsSync(reviewDir)) {
    throw new Error(`Review directory does not exist: ${reviewDir}`);
  }

  const files = readdirSync(reviewDir)
    .filter((file) => file.endsWith('.json'))
    .filter((file) => !file.startsWith('_'))
    .sort();

  const rows = [];
  for (const file of files) {
    const parsed = readJson(join(reviewDir, file));
    if (!Array.isArray(parsed)) throw new Error(`Review file must be an array: ${file}`);
    for (const row of parsed) rows.push(row);
  }
  return rows;
}

export function buildFollowupContract(reviewRows, { reviewDir, generatedAt = new Date().toISOString() }) {
  const byDecision = Object.fromEntries(DECISION_ORDER.map((decision) => [decision, 0]));
  const groups = new Map();

  for (const row of reviewRows) {
    const decision = normalizeDecision(row.decision);
    byDecision[decision] = (byDecision[decision] ?? 0) + 1;
    const action = FOLLOWUP_ACTIONS.get(decision);
    if (!action) continue;

    const groupKey = `${decision}:${row.topicId}:${row.contentType}`;
    if (!groups.has(groupKey)) {
      groups.set(groupKey, {
        decision,
        contentType: row.contentType,
        topicId: row.topicId,
        rows: [],
        candidatesByKey: new Map(),
      });
    }

    const group = groups.get(groupKey);
    group.rows.push(row);
    for (const candidate of row.candidates ?? []) {
      group.candidatesByKey.set(candidateKey(candidate), summarizeCandidate(candidate));
    }
  }

  const followups = Array.from(groups.values())
    .map((group) => {
      const action = FOLLOWUP_ACTIONS.get(group.decision);
      const candidates = Array.from(group.candidatesByKey.values()).sort((left, right) => {
        const levelCompare = String(left.jlptLevel ?? '').localeCompare(String(right.jlptLevel ?? ''));
        if (levelCompare !== 0) return levelCompare;
        return candidateOrder(left) - candidateOrder(right);
      });
      return {
        followupId: makeFollowupId(group.decision, group.topicId, group.contentType),
        actionType: action.actionType,
        decision: group.decision,
        contentType: group.contentType,
        topicId: group.topicId,
        rowCount: group.rows.length,
        reviewIds: sorted(group.rows.map((row) => row.reviewId)),
        targetIds: sorted(group.rows.map((row) => row.targetId)),
        audioFields: sorted(group.rows.map((row) => row.audioField)),
        adminFields: sorted(group.rows.map((row) => row.adminField)),
        blockerCodes: sorted(group.rows.flatMap((row) => row.blockerCodes ?? [])),
        candidateCount: candidates.length,
        candidates,
        recommendedActionKo: action.recommendedActionKo,
      };
    })
    .sort((left, right) => {
      const decisionCompare = DECISION_ORDER.indexOf(left.decision) - DECISION_ORDER.indexOf(right.decision);
      if (decisionCompare !== 0) return decisionCompare;
      const topicCompare = left.topicId.localeCompare(right.topicId);
      if (topicCompare !== 0) return topicCompare;
      return left.contentType.localeCompare(right.contentType);
    });

  const unresolvedRows =
    (byDecision.NEEDS_MAPPING ?? 0) + (byDecision.NEEDS_TOPIC_SPLIT ?? 0) + (byDecision.NEEDS_PARTIAL_OVERRIDE ?? 0);

  return {
    schemaVersion: 1,
    status: 'draft',
    generatedAt,
    sourceReviewDir: displayPath(reviewDir),
    summary: {
      totalRows: reviewRows.length,
      approvedRows: byDecision.APPROVED ?? 0,
      pendingRows: byDecision.PENDING ?? 0,
      unresolvedRows,
      followupGroups: followups.length,
      byDecision,
    },
    followups,
  };
}

function main() {
  try {
    const reviewRows = loadManualMappingReviewRows(REVIEW_DIR);
    const followups = buildFollowupContract(reviewRows, { reviewDir: REVIEW_DIR });
    writeJson(OUT_FILE, followups);
    console.log('TTS manual mapping follow-ups prepared.');
    console.log(`- review dir: ${REVIEW_DIR}`);
    console.log(`- output: ${OUT_FILE}`);
    console.log(`- unresolved rows: ${followups.summary.unresolvedRows}`);
    console.log(`- follow-up groups: ${followups.summary.followupGroups}`);
  } catch (error) {
    console.error(error instanceof Error ? error.message : error);
    console.error(`\n${usage()}`);
    process.exit(1);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
