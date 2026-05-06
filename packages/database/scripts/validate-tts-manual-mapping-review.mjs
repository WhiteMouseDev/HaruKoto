import { existsSync, readdirSync, readFileSync } from 'fs';
import { dirname, join, resolve } from 'path';
import { fileURLToPath } from 'url';
import { buildFollowupContract } from './prepare-tts-manual-mapping-followups.mjs';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PACKAGE_DIR = join(SCRIPT_DIR, '..');
const CURRICULUM_DIR = join(PACKAGE_DIR, 'data', 'curriculum');
const GRAMMAR_DIR = join(PACKAGE_DIR, 'data', 'grammar');
const VOCAB_DIR = join(PACKAGE_DIR, 'data', 'vocabulary');
const DEFAULT_REVIEW_DIR = join(CURRICULUM_DIR, 'tts-manual-mapping-review');
const DEFAULT_OVERRIDES_FILE = join(CURRICULUM_DIR, 'tts-review-manual-mapping-overrides.json');
const REVIEW_DIR = resolveOption('--in') ?? DEFAULT_REVIEW_DIR;
const OVERRIDES_FILE = resolveOption('--overrides') ?? DEFAULT_OVERRIDES_FILE;
const LEVELS = ['N5', 'N4', 'N3', 'N2', 'N1'];
const DECISIONS = new Set([
  'PENDING',
  'NEEDS_MAPPING',
  'NEEDS_TOPIC_SPLIT',
  'NEEDS_PARTIAL_OVERRIDE',
  'APPROVED',
  'REJECTED',
]);
const REVIEW_OUTCOME_DECISIONS = new Set(['NEEDS_MAPPING', 'NEEDS_TOPIC_SPLIT', 'NEEDS_PARTIAL_OVERRIDE', 'REJECTED']);
const MATCH_TYPES = new Set(['exact', 'partial', 'related']);
const OPERATION_STATUSES = new Set(['ready_after_db_lookup', 'manual_mapping_required', 'blocked']);
const ADMIN_TTS_FIELDS = new Map([
  ['vocabulary', new Set(['reading', 'word', 'example_sentence'])],
  ['grammar', new Set(['pattern', 'example_sentences'])],
]);

function usage() {
  return 'Usage: node scripts/validate-tts-manual-mapping-review.mjs [--in <reviewDir>]';
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

function normalize(value) {
  return String(value ?? '').replace(/\s+/g, ' ').trim();
}

function addIssue(rows, level, scope, message) {
  rows.push({ level, scope, message });
}

function loadRowsByLevel(dir, suffix) {
  const byLevel = new Map();
  for (const level of LEVELS) {
    const rows = readJson(join(dir, `${level.toLowerCase()}-${suffix}.json`));
    byLevel.set(level, new Map(rows.map((row) => [row.order, row])));
  }
  return byLevel;
}

function loadReviewRows(rows) {
  if (!existsSync(REVIEW_DIR)) {
    addIssue(rows, 'FAIL', 'TTS manual mapping review', `Missing review directory: ${REVIEW_DIR}`);
    return { manifest: null, reviewRows: [] };
  }

  const manifestPath = join(REVIEW_DIR, '_manifest.json');
  let manifest = null;
  if (!existsSync(manifestPath)) {
    addIssue(rows, 'FAIL', 'TTS manual mapping review', 'Missing _manifest.json.');
  } else {
    try {
      manifest = readJson(manifestPath);
    } catch (error) {
      addIssue(rows, 'FAIL', 'TTS manual mapping review', `_manifest.json is invalid JSON: ${error.message}`);
    }
  }

  const reviewRows = [];
  const files = readdirSync(REVIEW_DIR)
    .filter((file) => file.endsWith('.json'))
    .filter((file) => !file.startsWith('_'))
    .sort();

  for (const file of files) {
    const filePath = join(REVIEW_DIR, file);
    try {
      const parsed = readJson(filePath);
      if (!Array.isArray(parsed)) {
        addIssue(rows, 'FAIL', file, 'Review file must contain a JSON array.');
        continue;
      }
      parsed.forEach((row, index) => reviewRows.push({ row, sourceFile: file, rowNumber: index + 1 }));
    } catch (error) {
      addIssue(rows, 'FAIL', file, `Invalid JSON: ${error.message}`);
    }
  }

  return { manifest, reviewRows };
}

function buildContext() {
  const targetManifest = readJson(join(CURRICULUM_DIR, 'tts-target-manifest.json'));
  const reviewBatches = readJson(join(CURRICULUM_DIR, 'tts-review-batches.json'));
  const topicGrammarMap = readJson(join(CURRICULUM_DIR, 'topic-grammar-map.json'));
  const topicVocabularyMap = readJson(join(CURRICULUM_DIR, 'topic-vocabulary-map.json'));
  const grammarRowsByLevel = loadRowsByLevel(GRAMMAR_DIR, 'grammar');
  const vocabularyRowsByLevel = loadRowsByLevel(VOCAB_DIR, 'words');
  const targetById = new Map(targetManifest.targets.map((target) => [target.targetId, target]));
  const batchById = new Map(reviewBatches.batches.map((batch) => [batch.batchId, batch]));
  const expectedManualTargetIds = new Set();

  const grammarCandidateKeys = new Set();
  const vocabularyCandidateKeys = new Set();
  const grammarCandidatesByTopic = new Map();
  const vocabularyCandidatesByTopic = new Map();

  for (const mapping of topicGrammarMap.mappings) {
    grammarCandidateKeys.add(`${mapping.topicId}:${mapping.grammarLevel}:${mapping.grammarOrder}:${mapping.matchType}`);
    if (!grammarCandidatesByTopic.has(mapping.topicId)) grammarCandidatesByTopic.set(mapping.topicId, []);
    grammarCandidatesByTopic.get(mapping.topicId).push(mapping);
  }
  for (const mapping of topicVocabularyMap.mappings) {
    vocabularyCandidateKeys.add(
      `${mapping.topicId}:${mapping.vocabularyLevel}:${mapping.vocabularyOrder}:${mapping.matchType}`,
    );
    if (!vocabularyCandidatesByTopic.has(mapping.topicId)) vocabularyCandidatesByTopic.set(mapping.topicId, []);
    vocabularyCandidatesByTopic.get(mapping.topicId).push(mapping);
  }

  for (const batch of reviewBatches.batches) {
    if (batch.adminExport?.mode !== 'existing_admin_tts_fields') continue;
    for (const targetId of batch.targetIds ?? []) {
      const target = targetById.get(targetId);
      if (!target) continue;
      const adminField = adminFieldForTarget(batch, target);
      const supported = adminField ? (ADMIN_TTS_FIELDS.get(batch.adminExport.contentType) ?? new Set()).has(adminField) : false;
      const candidates =
        batch.adminExport.contentType === 'vocabulary'
          ? vocabularyCandidatesByTopic.get(target.topicId) ?? []
          : grammarCandidatesByTopic.get(target.topicId) ?? [];
      if (!adminField || !supported) continue;
      if (!['vocabulary', 'grammar'].includes(batch.adminExport.contentType)) continue;
      if (candidates.length === 1 && candidates[0].matchType === 'exact') continue;
      expectedManualTargetIds.add(targetId);
    }
  }

  return {
    targetById,
    batchById,
    grammarRowsByLevel,
    vocabularyRowsByLevel,
    grammarCandidateKeys,
    vocabularyCandidateKeys,
    expectedManualTargetIds,
  };
}

function adminFieldForTarget(batch, target) {
  const mapping = batch.adminExport.fieldMappings.find((item) => item.audioField === target.audioField);
  return mapping?.adminField ?? null;
}

function validateCandidate(candidate, reviewRow, context, rows, scope) {
  if (!Number.isInteger(candidate?.candidateIndex) || candidate.candidateIndex < 0) {
    addIssue(rows, 'FAIL', scope, 'candidateIndex must be a zero-based integer.');
  }
  if (candidate.contentType !== reviewRow.contentType) {
    addIssue(rows, 'FAIL', scope, 'candidate contentType must match row contentType.');
  }
  if (candidate.topicId !== reviewRow.topicId) {
    addIssue(rows, 'FAIL', scope, 'candidate topicId must match row topicId.');
  }
  if (candidate.adminField !== reviewRow.adminField) {
    addIssue(rows, 'FAIL', scope, 'candidate adminField must match row adminField.');
  }
  if (!MATCH_TYPES.has(candidate.matchType)) {
    addIssue(rows, 'FAIL', scope, 'candidate matchType is invalid.');
  }

  if (candidate.contentType === 'vocabulary') {
    const key = `${candidate.topicId}:${candidate.jlptLevel}:${candidate.vocabularyOrder}:${candidate.matchType}`;
    if (!context.vocabularyCandidateKeys.has(key)) {
      addIssue(rows, 'FAIL', scope, 'vocabulary candidate is not present in topic-vocabulary-map.json.');
    }
    const sourceRow = context.vocabularyRowsByLevel.get(candidate.jlptLevel)?.get(candidate.vocabularyOrder);
    if (!sourceRow) {
      addIssue(rows, 'FAIL', scope, 'vocabulary candidate references a missing source row.');
    } else {
      if (candidate.contentLabel !== sourceRow.word) addIssue(rows, 'FAIL', scope, 'contentLabel must match source row.');
      if (candidate.contentReading !== sourceRow.reading) addIssue(rows, 'FAIL', scope, 'contentReading must match source row.');
      if (candidate.meaningKo !== sourceRow.meaningKo) addIssue(rows, 'FAIL', scope, 'meaningKo must match source row.');
    }
    return;
  }

  if (candidate.contentType === 'grammar') {
    const key = `${candidate.topicId}:${candidate.jlptLevel}:${candidate.grammarOrder}:${candidate.matchType}`;
    if (!context.grammarCandidateKeys.has(key)) {
      addIssue(rows, 'FAIL', scope, 'grammar candidate is not present in topic-grammar-map.json.');
    }
    if (!context.grammarRowsByLevel.get(candidate.jlptLevel)?.has(candidate.grammarOrder)) {
      addIssue(rows, 'FAIL', scope, 'grammar candidate references a missing source row.');
    }
    return;
  }

  addIssue(rows, 'FAIL', scope, 'candidate contentType must be vocabulary or grammar.');
}

function validateApprovedSelection(reviewRow, selected, context, rows, scope) {
  if (!selected || typeof selected !== 'object') {
    addIssue(rows, 'FAIL', scope, 'APPROVED row requires selectedCandidateIndex or selected.');
    return;
  }

  if (reviewRow.contentType === 'vocabulary') {
    if (selected.lookupType !== 'vocabulary_level_order') {
      addIssue(rows, 'FAIL', scope, 'APPROVED vocabulary row must use vocabulary_level_order.');
    }
    const sourceRow = context.vocabularyRowsByLevel.get(selected.jlptLevel)?.get(selected.vocabularyOrder);
    if (!sourceRow) {
      addIssue(rows, 'FAIL', scope, 'APPROVED vocabulary selection references a missing source row.');
    } else {
      if (selected.contentLabel !== sourceRow.word) addIssue(rows, 'FAIL', scope, 'selected contentLabel must match source row.');
      if (selected.contentReading !== sourceRow.reading) {
        addIssue(rows, 'FAIL', scope, 'selected contentReading must match source row.');
      }
      if (selected.meaningKo !== sourceRow.meaningKo) addIssue(rows, 'FAIL', scope, 'selected meaningKo must match source row.');
    }
    return;
  }

  if (reviewRow.contentType === 'grammar') {
    if (selected.lookupType !== 'grammar_level_order') {
      addIssue(rows, 'FAIL', scope, 'APPROVED grammar row must use grammar_level_order.');
    }
    if (!context.grammarRowsByLevel.get(selected.jlptLevel)?.has(selected.grammarOrder)) {
      addIssue(rows, 'FAIL', scope, 'APPROVED grammar selection references a missing source row.');
    }
  }
}

function hasAmbiguousMappingBlocker(row) {
  return (
    (row.blockerCodes ?? []).includes('ambiguous_or_partial_vocabulary_mapping') ||
    (row.blockerCodes ?? []).includes('ambiguous_or_partial_grammar_mapping')
  );
}

function validateUnresolvedSelection(row, rows, scope, decision) {
  if (row.selectedCandidateIndex !== null) addIssue(rows, 'FAIL', scope, `${decision} row selectedCandidateIndex must be null.`);
  if (!normalize(row.reviewerNotes)) addIssue(rows, 'FAIL', scope, `${decision} row needs reviewerNotes.`);
}

function validateReviewRow(item, context, rows, seenTargetIds) {
  const { row, sourceFile, rowNumber } = item;
  const scope = `${sourceFile}:${rowNumber}`;
  const target = context.targetById.get(row.targetId);
  const batch = context.batchById.get(row.batchId);

  if (seenTargetIds.has(row.targetId)) addIssue(rows, 'FAIL', scope, 'Duplicate review row for targetId.');
  seenTargetIds.add(row.targetId);

  if (row.reviewId !== `tts-map-${row.targetId}`) {
    addIssue(rows, 'FAIL', scope, 'reviewId must be tts-map-<targetId>.');
  }
  if (!target) {
    addIssue(rows, 'FAIL', scope, 'targetId does not exist in tts-target-manifest.json.');
    return;
  }
  if (!batch) {
    addIssue(rows, 'FAIL', scope, 'batchId does not exist in tts-review-batches.json.');
    return;
  }
  if (!(batch.targetIds ?? []).includes(row.targetId)) {
    addIssue(rows, 'FAIL', scope, 'targetId is not part of the referenced batch.');
  }
  if (batch.adminExport.mode !== 'existing_admin_tts_fields') {
    addIssue(rows, 'FAIL', scope, 'manual mapping review rows must target existing admin TTS batches.');
  }
  if (row.topicId !== target.topicId) addIssue(rows, 'FAIL', scope, 'topicId must match target topicId.');
  if (row.contentType !== batch.adminExport.contentType) addIssue(rows, 'FAIL', scope, 'contentType must match batch contentType.');
  if (row.audioTargetType !== target.audioTargetType) addIssue(rows, 'FAIL', scope, 'audioTargetType must match target.');
  if (row.audioField !== target.audioField) addIssue(rows, 'FAIL', scope, 'audioField must match target.');
  if (row.adminField !== adminFieldForTarget(batch, target)) {
    addIssue(rows, 'FAIL', scope, 'adminField must match batch field mapping.');
  }
  if (!OPERATION_STATUSES.has(row.operationStatus)) addIssue(rows, 'FAIL', scope, 'operationStatus is invalid.');

  const decision = normalize(row.decision).toUpperCase();
  if (!DECISIONS.has(decision)) {
    addIssue(
      rows,
      'FAIL',
      scope,
      'decision must be PENDING, NEEDS_MAPPING, NEEDS_TOPIC_SPLIT, NEEDS_PARTIAL_OVERRIDE, APPROVED, or REJECTED.',
    );
  }
  if (!Array.isArray(row.candidates)) addIssue(rows, 'FAIL', scope, 'candidates must be an array.');

  for (const [index, candidate] of (row.candidates ?? []).entries()) {
    if (candidate.candidateIndex !== index) addIssue(rows, 'FAIL', scope, 'candidateIndex values must be sequential.');
    validateCandidate(candidate, row, context, rows, `${scope} candidate ${index}`);
  }

  if (decision === 'PENDING') {
    if (row.selectedCandidateIndex !== null) addIssue(rows, 'FAIL', scope, 'PENDING row selectedCandidateIndex must be null.');
    return;
  }
  if (decision === 'NEEDS_MAPPING') {
    validateUnresolvedSelection(row, rows, scope, 'NEEDS_MAPPING');
    if ((row.candidates ?? []).length !== 0) {
      addIssue(rows, 'FAIL', scope, 'NEEDS_MAPPING is only valid when no candidates exist.');
    }
    if (
      !(
        (row.blockerCodes ?? []).includes('topic_vocabulary_mapping_required') ||
        (row.blockerCodes ?? []).includes('topic_grammar_mapping_required')
      )
    ) {
      addIssue(rows, 'FAIL', scope, 'NEEDS_MAPPING row must have a topic mapping blocker.');
    }
    return;
  }
  if (decision === 'NEEDS_TOPIC_SPLIT') {
    validateUnresolvedSelection(row, rows, scope, 'NEEDS_TOPIC_SPLIT');
    if ((row.candidates ?? []).length <= 1) {
      addIssue(rows, 'FAIL', scope, 'NEEDS_TOPIC_SPLIT is only valid when multiple candidates exist.');
    }
    if ((row.candidates ?? []).some((candidate) => candidate.matchType === 'exact')) {
      addIssue(rows, 'FAIL', scope, 'NEEDS_TOPIC_SPLIT rows must not contain an exact candidate.');
    }
    if (!hasAmbiguousMappingBlocker(row)) {
      addIssue(rows, 'FAIL', scope, 'NEEDS_TOPIC_SPLIT row must have an ambiguous mapping blocker.');
    }
    return;
  }
  if (decision === 'NEEDS_PARTIAL_OVERRIDE') {
    validateUnresolvedSelection(row, rows, scope, 'NEEDS_PARTIAL_OVERRIDE');
    if ((row.candidates ?? []).length !== 1) {
      addIssue(rows, 'FAIL', scope, 'NEEDS_PARTIAL_OVERRIDE is only valid when exactly one candidate exists.');
    }
    if ((row.candidates ?? [])[0]?.matchType === 'exact') {
      addIssue(rows, 'FAIL', scope, 'NEEDS_PARTIAL_OVERRIDE rows must reference a non-exact candidate.');
    }
    if (!hasAmbiguousMappingBlocker(row)) {
      addIssue(rows, 'FAIL', scope, 'NEEDS_PARTIAL_OVERRIDE row must have an ambiguous mapping blocker.');
    }
    return;
  }
  if (decision === 'REJECTED') return;

  const selected = Number.isInteger(row.selectedCandidateIndex) ? row.candidates?.[row.selectedCandidateIndex] : row.selected;
  validateApprovedSelection(row, selected, context, rows, scope);
}

function validateManifest(manifest, reviewRows, context, rows) {
  if (!manifest) return;
  if (manifest.includeReady !== false) addIssue(rows, 'FAIL', '_manifest.json', 'includeReady must be false for source review artifacts.');
  if (manifest.outDir !== 'data/curriculum/tts-manual-mapping-review') {
    addIssue(rows, 'FAIL', '_manifest.json', 'outDir must be source-relative, not an absolute or temp path.');
  }
  if (manifest.totals?.writtenRows !== reviewRows.length) {
    addIssue(rows, 'FAIL', '_manifest.json', 'totals.writtenRows must match review row count.');
  }
  if (manifest.totals?.manualRows !== context.expectedManualTargetIds.size) {
    addIssue(rows, 'FAIL', '_manifest.json', 'totals.manualRows must match current expected manual target count.');
  }
  for (const batch of manifest.batches ?? []) {
    const expectedOutputFile = `data/curriculum/tts-manual-mapping-review/${batch.batchId}.json`;
    if (batch.outputFile !== expectedOutputFile) {
      addIssue(rows, 'FAIL', '_manifest.json', `outputFile for ${batch.batchId} must be ${expectedOutputFile}.`);
    }
  }
}

function loadFollowups(rows) {
  const followupsPath = join(REVIEW_DIR, '_followups.json');
  if (!existsSync(followupsPath)) {
    addIssue(rows, 'FAIL', '_followups.json', 'Missing TTS manual mapping follow-up contract.');
    return null;
  }
  try {
    return readJson(followupsPath);
  } catch (error) {
    addIssue(rows, 'FAIL', '_followups.json', `Invalid JSON: ${error.message}`);
    return null;
  }
}

function stableFollowups(value) {
  if (!value || typeof value !== 'object') return value;
  const { generatedAt: _generatedAt, ...rest } = value;
  return rest;
}

function validateFollowups(followups, reviewRows, rows) {
  if (!followups) return;
  const expected = buildFollowupContract(
    reviewRows.map((item) => item.row),
    {
      reviewDir: REVIEW_DIR,
      generatedAt: followups.generatedAt ?? 'validator',
    },
  );
  if (JSON.stringify(stableFollowups(followups)) !== JSON.stringify(stableFollowups(expected))) {
    addIssue(rows, 'FAIL', '_followups.json', 'Follow-up contract is stale; run curriculum:tts-review:followups.');
  }
}

function candidateRefForReview(candidate) {
  const ref = {
    lookupType: candidate.lookupType,
    jlptLevel: candidate.jlptLevel,
    matchType: candidate.matchType,
    contentLabel: normalize(candidate.contentLabel) || null,
    noteKo: normalize(candidate.noteKo) || null,
  };
  if (candidate.grammarOrder !== undefined) ref.grammarOrder = candidate.grammarOrder;
  if (candidate.vocabularyOrder !== undefined) ref.vocabularyOrder = candidate.vocabularyOrder;
  if (candidate.contentReading !== undefined) ref.contentReading = normalize(candidate.contentReading) || null;
  if (candidate.meaningKo !== undefined) ref.meaningKo = normalize(candidate.meaningKo) || null;
  return ref;
}

function reviewOutcomeForRow(row, decision) {
  return {
    targetId: row.targetId,
    topicId: row.topicId,
    contentType: row.contentType,
    adminField: row.adminField,
    decisionStatus: decision.toLowerCase(),
    notesKo:
      normalize(row.reviewerNotes) ||
      `Manual mapping review outcome recorded as ${decision.toLowerCase().replaceAll('_', ' ')}.`,
    candidateRefs: (row.candidates ?? []).map(candidateRefForReview),
  };
}

function expectedReviewOutcomes(reviewRows) {
  return reviewRows
    .map((item) => {
      const decision = normalize(item.row.decision).toUpperCase();
      return REVIEW_OUTCOME_DECISIONS.has(decision) ? reviewOutcomeForRow(item.row, decision) : null;
    })
    .filter(Boolean)
    .sort((left, right) => left.targetId.localeCompare(right.targetId));
}

function loadOverrides(rows) {
  if (!existsSync(OVERRIDES_FILE)) {
    addIssue(rows, 'FAIL', 'tts-review-manual-mapping-overrides.json', 'Missing manual mapping override contract.');
    return null;
  }
  try {
    return readJson(OVERRIDES_FILE);
  } catch (error) {
    addIssue(rows, 'FAIL', 'tts-review-manual-mapping-overrides.json', `Invalid JSON: ${error.message}`);
    return null;
  }
}

function validateOverrideReviewOutcomes(overrides, reviewRows, rows) {
  if (!overrides) return;
  if (!Array.isArray(overrides.reviewOutcomes)) {
    addIssue(rows, 'FAIL', 'tts-review-manual-mapping-overrides.json', 'reviewOutcomes must be an array.');
    return;
  }
  const expected = expectedReviewOutcomes(reviewRows);
  if (JSON.stringify(overrides.reviewOutcomes) !== JSON.stringify(expected)) {
    addIssue(
      rows,
      'FAIL',
      'tts-review-manual-mapping-overrides.json',
      'reviewOutcomes are stale; run curriculum:tts-review:compile -- --replace.',
    );
  }
}

function printRows(rows) {
  const failCount = rows.filter((row) => row.level === 'FAIL').length;
  const warnCount = rows.filter((row) => row.level === 'WARN').length;
  console.log('TTS manual mapping review validation summary');
  console.log(`- warnings: ${warnCount}`);
  console.log(`- failures: ${failCount}`);
  if (rows.length > 0) {
    console.log('\nFindings');
    for (const row of rows) console.log(`- ${row.level} | ${row.scope} | ${row.message}`);
  }
  if (failCount > 0) process.exit(1);
  console.log('\nTTS manual mapping review validation passed.');
}

function main() {
  const rows = [];
  const context = buildContext();
  const { manifest, reviewRows } = loadReviewRows(rows);
  const followups = loadFollowups(rows);
  const overrides = loadOverrides(rows);
  const seenTargetIds = new Set();

  for (const item of reviewRows) validateReviewRow(item, context, rows, seenTargetIds);

  for (const targetId of context.expectedManualTargetIds) {
    if (!seenTargetIds.has(targetId)) {
      addIssue(rows, 'FAIL', targetId, 'Expected manual mapping target is missing from review artifacts.');
    }
  }
  for (const targetId of seenTargetIds) {
    if (!context.expectedManualTargetIds.has(targetId)) {
      addIssue(rows, 'FAIL', targetId, 'Review artifact contains a target that is no longer manual-mapping-required.');
    }
  }

  validateManifest(manifest, reviewRows, context, rows);
  validateFollowups(followups, reviewRows, rows);
  validateOverrideReviewOutcomes(overrides, reviewRows, rows);
  printRows(rows);
}

main();
