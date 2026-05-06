import { existsSync, readdirSync, readFileSync, writeFileSync } from 'fs';
import { dirname, join, resolve } from 'path';
import { fileURLToPath } from 'url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PACKAGE_DIR = join(SCRIPT_DIR, '..');
const CURRICULUM_DIR = join(PACKAGE_DIR, 'data', 'curriculum');
const GRAMMAR_DIR = join(PACKAGE_DIR, 'data', 'grammar');
const VOCAB_DIR = join(PACKAGE_DIR, 'data', 'vocabulary');
const DEFAULT_REVIEW_DIR = join(CURRICULUM_DIR, 'tts-manual-mapping-review');
const DEFAULT_OUT_FILE = join(CURRICULUM_DIR, 'tts-review-manual-mapping-overrides.json');
const LEVELS = ['N5', 'N4', 'N3', 'N2', 'N1'];
const VALID_DECISIONS = new Set([
  'PENDING',
  'NEEDS_MAPPING',
  'NEEDS_TOPIC_SPLIT',
  'NEEDS_PARTIAL_OVERRIDE',
  'APPROVED',
  'REJECTED',
]);

const REVIEW_DIR = resolveOption('--in') ?? DEFAULT_REVIEW_DIR;
const OUT_FILE = resolveOption('--out') ?? DEFAULT_OUT_FILE;
const REPLACE_EXISTING = hasFlag('--replace');

function usage() {
  return [
    'Usage: node scripts/compile-tts-manual-mapping-overrides.mjs [--in <reviewDir>] [--out <file>] [--replace]',
    '',
    'Compiles APPROVED rows from prepared TTS manual mapping review files into',
    'tts-review-manual-mapping-overrides.json. Non-APPROVED rows are skipped.',
  ].join('\n');
}

function hasFlag(name) {
  return process.argv.slice(2).includes(name);
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

function normalize(value) {
  return String(value ?? '').replace(/\s+/g, ' ').trim();
}

function loadRowsByLevel(dir, suffix) {
  const byLevel = new Map();
  for (const level of LEVELS) {
    const filePath = join(dir, `${level.toLowerCase()}-${suffix}.json`);
    const rows = readJson(filePath);
    byLevel.set(level, new Map(rows.map((row) => [row.order, row])));
  }
  return byLevel;
}

function loadReviewRows(reviewDir) {
  if (!existsSync(reviewDir)) {
    throw new Error(`Review directory does not exist: ${reviewDir}`);
  }

  const files = readdirSync(reviewDir)
    .filter((file) => file.endsWith('.json'))
    .filter((file) => !file.startsWith('_'))
    .sort();

  const rows = [];
  for (const file of files) {
    const fullPath = join(reviewDir, file);
    const parsed = readJson(fullPath);
    if (!Array.isArray(parsed)) throw new Error(`Review file must be an array: ${fullPath}`);
    parsed.forEach((row, index) => rows.push({ row, sourceFile: fullPath, rowNumber: index + 1 }));
  }

  return rows;
}

function existingDecisionsByTarget(outFile) {
  const byTarget = new Map();
  if (REPLACE_EXISTING || !existsSync(outFile)) return byTarget;

  const existing = readJson(outFile);
  for (const decision of existing.decisions ?? []) {
    byTarget.set(decision.targetId, decision);
  }
  return byTarget;
}

function selectedForRow(row) {
  if (Number.isInteger(row.selectedCandidateIndex)) {
    const candidate = row.candidates?.[row.selectedCandidateIndex];
    if (!candidate) {
      throw new Error(`${row.reviewId}: selectedCandidateIndex does not reference a candidate.`);
    }
    return candidate;
  }
  if (row.selected && typeof row.selected === 'object') return row.selected;
  throw new Error(`${row.reviewId}: APPROVED row needs selectedCandidateIndex or selected.`);
}

function requireText(value, scope, field) {
  const text = normalize(value);
  if (!text) throw new Error(`${scope}: ${field} is required.`);
  return text;
}

function requireLevel(value, scope) {
  const level = requireText(value, scope, 'jlptLevel').toUpperCase();
  if (!LEVELS.includes(level)) throw new Error(`${scope}: invalid jlptLevel ${value}.`);
  return level;
}

function requireInteger(value, scope, field) {
  if (!Number.isInteger(value) || value < 1) throw new Error(`${scope}: ${field} must be a positive integer.`);
  return value;
}

function compileVocabularyDecision(row, selected, vocabularyRowsByLevel) {
  const scope = row.reviewId;
  const jlptLevel = requireLevel(selected.jlptLevel, scope);
  const vocabularyOrder = requireInteger(selected.vocabularyOrder, scope, 'vocabularyOrder');
  const sourceRow = vocabularyRowsByLevel.get(jlptLevel)?.get(vocabularyOrder);
  if (!sourceRow) throw new Error(`${scope}: missing vocabulary source row ${jlptLevel}:${vocabularyOrder}.`);

  const contentLabel = requireText(selected.contentLabel, scope, 'contentLabel');
  const contentReading = requireText(selected.contentReading, scope, 'contentReading');
  const meaningKo = requireText(selected.meaningKo, scope, 'meaningKo');
  if (contentLabel !== sourceRow.word) throw new Error(`${scope}: contentLabel does not match vocabulary source row.`);
  if (contentReading !== sourceRow.reading) throw new Error(`${scope}: contentReading does not match vocabulary source row.`);
  if (meaningKo !== sourceRow.meaningKo) throw new Error(`${scope}: meaningKo does not match vocabulary source row.`);

  return {
    targetId: requireText(row.targetId, scope, 'targetId'),
    topicId: requireText(row.topicId, scope, 'topicId'),
    contentType: 'vocabulary',
    lookupType: 'vocabulary_level_order',
    adminField: requireText(row.adminField, scope, 'adminField'),
    jlptLevel,
    vocabularyOrder,
    contentLabel,
    contentReading,
    meaningKo,
    decisionStatus: 'approved',
    notesKo: normalize(row.reviewerNotes) || normalize(selected.noteKo) || 'TTS manual vocabulary mapping approved.',
  };
}

function compileGrammarDecision(row, selected, grammarRowsByLevel) {
  const scope = row.reviewId;
  const jlptLevel = requireLevel(selected.jlptLevel, scope);
  const grammarOrder = requireInteger(selected.grammarOrder, scope, 'grammarOrder');
  if (!grammarRowsByLevel.get(jlptLevel)?.has(grammarOrder)) {
    throw new Error(`${scope}: missing grammar source row ${jlptLevel}:${grammarOrder}.`);
  }

  return {
    targetId: requireText(row.targetId, scope, 'targetId'),
    topicId: requireText(row.topicId, scope, 'topicId'),
    contentType: 'grammar',
    lookupType: 'grammar_level_order',
    adminField: requireText(row.adminField, scope, 'adminField'),
    jlptLevel,
    grammarOrder,
    decisionStatus: 'approved',
    notesKo: normalize(row.reviewerNotes) || normalize(selected.noteKo) || 'TTS manual grammar mapping approved.',
  };
}

function compileDecision(row, vocabularyRowsByLevel, grammarRowsByLevel) {
  const selected = selectedForRow(row);
  if (row.contentType === 'vocabulary') {
    if (selected.lookupType !== 'vocabulary_level_order') {
      throw new Error(`${row.reviewId}: vocabulary rows require vocabulary_level_order.`);
    }
    return compileVocabularyDecision(row, selected, vocabularyRowsByLevel);
  }
  if (row.contentType === 'grammar') {
    if (selected.lookupType !== 'grammar_level_order') {
      throw new Error(`${row.reviewId}: grammar rows require grammar_level_order.`);
    }
    return compileGrammarDecision(row, selected, grammarRowsByLevel);
  }
  throw new Error(`${row.reviewId}: unsupported contentType ${row.contentType}.`);
}

try {
  const reviewRows = loadReviewRows(REVIEW_DIR);
  const vocabularyRowsByLevel = loadRowsByLevel(VOCAB_DIR, 'words');
  const grammarRowsByLevel = loadRowsByLevel(GRAMMAR_DIR, 'grammar');
  const decisionsByTarget = existingDecisionsByTarget(OUT_FILE);
  const stats = {
    files: new Set(reviewRows.map((item) => item.sourceFile)).size,
    rows: reviewRows.length,
    approved: 0,
    rejected: 0,
    needsMapping: 0,
    needsTopicSplit: 0,
    needsPartialOverride: 0,
    pending: 0,
    compiled: 0,
  };

  for (const { row, sourceFile, rowNumber } of reviewRows) {
    const decision = normalize(row.decision).toUpperCase();
    if (!VALID_DECISIONS.has(decision)) {
      throw new Error(
        `${sourceFile}:${rowNumber}: decision must be PENDING, NEEDS_MAPPING, NEEDS_TOPIC_SPLIT, NEEDS_PARTIAL_OVERRIDE, APPROVED, or REJECTED.`,
      );
    }
    if (decision === 'PENDING') {
      stats.pending += 1;
      continue;
    }
    if (decision === 'NEEDS_MAPPING') {
      stats.needsMapping += 1;
      continue;
    }
    if (decision === 'NEEDS_TOPIC_SPLIT') {
      stats.needsTopicSplit += 1;
      continue;
    }
    if (decision === 'NEEDS_PARTIAL_OVERRIDE') {
      stats.needsPartialOverride += 1;
      continue;
    }
    if (decision === 'REJECTED') {
      stats.rejected += 1;
      continue;
    }

    stats.approved += 1;
    const compiled = compileDecision(row, vocabularyRowsByLevel, grammarRowsByLevel);
    decisionsByTarget.set(compiled.targetId, compiled);
    stats.compiled += 1;
  }

  const output = {
    schemaVersion: 1,
    status: 'draft',
    decisions: Array.from(decisionsByTarget.values()).sort((left, right) => left.targetId.localeCompare(right.targetId)),
  };

  writeJson(OUT_FILE, output);

  console.log('TTS manual mapping overrides compiled.');
  console.log(`- review dir: ${REVIEW_DIR}`);
  console.log(`- output: ${OUT_FILE}`);
  console.log(`- files: ${stats.files}`);
  console.log(`- rows: ${stats.rows}`);
  console.log(`- approved: ${stats.approved}`);
  console.log(`- rejected: ${stats.rejected}`);
  console.log(`- needs mapping: ${stats.needsMapping}`);
  console.log(`- needs topic split: ${stats.needsTopicSplit}`);
  console.log(`- needs partial override: ${stats.needsPartialOverride}`);
  console.log(`- pending: ${stats.pending}`);
  console.log(`- compiled decisions: ${output.decisions.length}`);
} catch (error) {
  console.error(error instanceof Error ? error.message : error);
  console.error(`\n${usage()}`);
  process.exit(1);
}
