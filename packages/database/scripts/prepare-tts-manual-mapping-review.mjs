import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { dirname, join, resolve } from 'path';
import { fileURLToPath } from 'url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PACKAGE_DIR = join(SCRIPT_DIR, '..');
const CURRICULUM_DIR = join(PACKAGE_DIR, 'data', 'curriculum');
const GRAMMAR_DIR = join(PACKAGE_DIR, 'data', 'grammar');
const DEFAULT_OUT_DIR = join(CURRICULUM_DIR, 'tts-manual-mapping-review');
const LEVELS = ['N5', 'N4', 'N3', 'N2', 'N1'];
const ADMIN_TTS_FIELDS = new Map([
  ['vocabulary', new Set(['reading', 'word', 'example_sentence'])],
  ['grammar', new Set(['pattern', 'example_sentences'])],
]);

const OUT_DIR = resolveOption('--out') ?? DEFAULT_OUT_DIR;
const INCLUDE_READY = hasFlag('--include-ready');

function usage() {
  return [
    'Usage: node scripts/prepare-tts-manual-mapping-review.mjs [--out <dir>] [--include-ready]',
    '',
    'Generates reviewer-editable TTS manual mapping rows from current curriculum contracts.',
    'Rows stay PENDING only when a reviewer can approve a concrete candidate.',
    'Rows without any current topic map candidate are marked NEEDS_MAPPING.',
    'Rows with multiple non-exact candidates are marked NEEDS_TOPIC_SPLIT.',
    'Rows with one non-exact candidate are marked NEEDS_PARTIAL_OVERRIDE.',
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

function displayPath(filePath) {
  const relativePath = filePath.startsWith(PACKAGE_DIR) ? filePath.slice(PACKAGE_DIR.length + 1) : filePath;
  return relativePath.replaceAll('\\', '/');
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

function buildTargetById(targetManifest) {
  return new Map(targetManifest.targets.map((target) => [target.targetId, target]));
}

function buildCandidateMaps(topicGrammarMap, topicVocabularyMap, grammarRowsByLevel) {
  const grammarByTopic = new Map();
  const vocabularyByTopic = new Map();

  for (const mapping of topicGrammarMap.mappings) {
    const grammarRow = grammarRowsByLevel.get(mapping.grammarLevel)?.get(mapping.grammarOrder);
    const candidate = {
      contentType: 'grammar',
      lookupType: 'grammar_level_order',
      topicId: mapping.topicId,
      adminField: null,
      jlptLevel: mapping.grammarLevel,
      grammarOrder: mapping.grammarOrder,
      contentLabel: grammarRow?.pattern ?? null,
      meaningKo: grammarRow?.meaningKo ?? null,
      matchType: mapping.matchType,
      noteKo: mapping.notesKo,
    };
    if (!grammarByTopic.has(mapping.topicId)) grammarByTopic.set(mapping.topicId, []);
    grammarByTopic.get(mapping.topicId).push(candidate);
  }

  for (const mapping of topicVocabularyMap.mappings) {
    const candidate = {
      contentType: 'vocabulary',
      lookupType: 'vocabulary_level_order',
      topicId: mapping.topicId,
      adminField: null,
      jlptLevel: mapping.vocabularyLevel,
      vocabularyOrder: mapping.vocabularyOrder,
      contentLabel: mapping.word,
      contentReading: mapping.reading,
      meaningKo: mapping.meaningKo,
      matchType: mapping.matchType,
      noteKo: mapping.notesKo,
    };
    if (!vocabularyByTopic.has(mapping.topicId)) vocabularyByTopic.set(mapping.topicId, []);
    vocabularyByTopic.get(mapping.topicId).push(candidate);
  }

  return { grammarByTopic, vocabularyByTopic };
}

function adminFieldForTarget(batch, target) {
  const mapping = batch.adminExport.fieldMappings.find((item) => item.audioField === target.audioField);
  return mapping?.adminField ?? null;
}

function candidatesForTarget(batch, target, candidateMaps) {
  if (batch.adminExport.contentType === 'vocabulary') {
    return candidateMaps.vocabularyByTopic.get(target.topicId) ?? [];
  }
  if (batch.adminExport.contentType === 'grammar') {
    return candidateMaps.grammarByTopic.get(target.topicId) ?? [];
  }
  return [];
}

function blockerCodesForTarget(batch, target, adminField, existingAdminTtsSupported, candidates) {
  if (batch.adminExport.mode !== 'existing_admin_tts_fields') return ['admin_extension_required'];
  if (!adminField) return ['missing_admin_field_mapping'];
  if (!existingAdminTtsSupported) return ['unsupported_admin_tts_field'];
  if (batch.adminExport.contentType === 'vocabulary') {
    return candidates.length === 0 ? ['topic_vocabulary_mapping_required'] : ['ambiguous_or_partial_vocabulary_mapping'];
  }
  if (batch.adminExport.contentType === 'grammar') {
    return candidates.length === 0 ? ['topic_grammar_mapping_required'] : ['ambiguous_or_partial_grammar_mapping'];
  }
  return ['unsupported_admin_tts_field'];
}

function rowStatusForTarget(batch, target, adminField, existingAdminTtsSupported, candidates) {
  if (batch.adminExport.mode !== 'existing_admin_tts_fields') return 'blocked';
  if (!adminField || !existingAdminTtsSupported) return 'blocked';
  if (!['vocabulary', 'grammar'].includes(batch.adminExport.contentType)) return 'blocked';
  if (candidates.length === 1 && candidates[0].matchType === 'exact') return 'ready_after_db_lookup';
  return 'manual_mapping_required';
}

function selectedTemplate(contentType) {
  if (contentType === 'vocabulary') {
    return {
      lookupType: 'vocabulary_level_order',
      jlptLevel: null,
      vocabularyOrder: null,
      contentLabel: null,
      contentReading: null,
      meaningKo: null,
    };
  }
  if (contentType === 'grammar') {
    return {
      lookupType: 'grammar_level_order',
      jlptLevel: null,
      grammarOrder: null,
    };
  }
  return null;
}

function buildReviewRow(batch, target, adminField, existingAdminTtsSupported, candidates, operationStatus) {
  const contentType = batch.adminExport.contentType;
  const blockerCodes =
    operationStatus === 'ready_after_db_lookup'
      ? []
      : blockerCodesForTarget(batch, target, adminField, existingAdminTtsSupported, candidates);
  const needsMapping = blockerCodes.includes('topic_vocabulary_mapping_required') || blockerCodes.includes('topic_grammar_mapping_required');
  const exactCandidates = candidates.filter((candidate) => candidate.matchType === 'exact');
  const nonExactCandidates = candidates.filter((candidate) => candidate.matchType !== 'exact');
  const needsTopicSplit = candidates.length > 1 && exactCandidates.length === 0;
  const needsPartialOverride = candidates.length === 1 && nonExactCandidates.length === 1;
  const decision = needsMapping
    ? 'NEEDS_MAPPING'
    : needsTopicSplit
      ? 'NEEDS_TOPIC_SPLIT'
      : needsPartialOverride
        ? 'NEEDS_PARTIAL_OVERRIDE'
        : 'PENDING';
  const reviewerNotes = needsMapping
    ? '현재 topic map 후보가 없어 grammar/vocabulary mapping 보강이 먼저 필요하다.'
    : needsTopicSplit
      ? '복수의 non-exact 후보가 있어 topic split 또는 stronger topic map이 필요하다.'
      : needsPartialOverride
        ? '단일 non-exact 후보만 있어 승인 전 partial override 근거가 필요하다.'
        : '';
  return {
    reviewId: `tts-map-${target.targetId}`,
    batchId: batch.batchId,
    targetId: target.targetId,
    topicId: target.topicId,
    contentType,
    audioTargetType: target.audioTargetType,
    audioField: target.audioField,
    adminField,
    textSource: target.textSource,
    requiredBeforePublish: target.requiredBeforePublish,
    operationStatus,
    blockerCodes,
    decision,
    selectedCandidateIndex: null,
    selected: selectedTemplate(contentType),
    candidates: candidates.map((candidate, index) => ({
      candidateIndex: index,
      ...candidate,
      adminField,
    })),
    reviewerNotes,
  };
}

const targetManifest = readJson(join(CURRICULUM_DIR, 'tts-target-manifest.json'));
const reviewBatches = readJson(join(CURRICULUM_DIR, 'tts-review-batches.json'));
const topicGrammarMap = readJson(join(CURRICULUM_DIR, 'topic-grammar-map.json'));
const topicVocabularyMap = readJson(join(CURRICULUM_DIR, 'topic-vocabulary-map.json'));
const grammarRowsByLevel = loadRowsByLevel(GRAMMAR_DIR, 'grammar');

const targetById = buildTargetById(targetManifest);
const candidateMaps = buildCandidateMaps(topicGrammarMap, topicVocabularyMap, grammarRowsByLevel);

if (!existsSync(OUT_DIR)) mkdirSync(OUT_DIR, { recursive: true });

const manifest = {
  generatedAt: new Date().toISOString(),
  outDir: displayPath(OUT_DIR),
  includeReady: INCLUDE_READY,
  sourceContracts: {
    targetManifest: displayPath(join(CURRICULUM_DIR, 'tts-target-manifest.json')),
    reviewBatches: displayPath(join(CURRICULUM_DIR, 'tts-review-batches.json')),
    topicGrammarMap: displayPath(join(CURRICULUM_DIR, 'topic-grammar-map.json')),
    topicVocabularyMap: displayPath(join(CURRICULUM_DIR, 'topic-vocabulary-map.json')),
  },
  totals: {
    batches: 0,
    targets: 0,
    readyRows: 0,
    manualRows: 0,
    blockedRows: 0,
    writtenRows: 0,
  },
  batches: [],
  workflow: {
    step1: 'Open the generated batch JSON files and inspect rows with decision=PENDING, NEEDS_MAPPING, NEEDS_TOPIC_SPLIT, or NEEDS_PARTIAL_OVERRIDE.',
    step2: 'For a row to approve, set decision=APPROVED and either selectedCandidateIndex or selected.',
    step3: 'Run compile-tts-manual-mapping-overrides.mjs, then curriculum:derive and curriculum:validate.',
  },
};

for (const batch of reviewBatches.batches) {
  if (batch.adminExport.mode !== 'existing_admin_tts_fields') continue;

  const rows = [];
  const batchSummary = {
    batchId: batch.batchId,
    contentType: batch.adminExport.contentType,
    targetCount: batch.targetIds.length,
    readyRows: 0,
    manualRows: 0,
    blockedRows: 0,
    writtenRows: 0,
    outputFile: null,
  };

  for (const targetId of batch.targetIds) {
    const target = targetById.get(targetId);
    if (!target) throw new Error(`Missing TTS target ${targetId} referenced by ${batch.batchId}.`);

    const adminField = adminFieldForTarget(batch, target);
    const supportedFields = ADMIN_TTS_FIELDS.get(batch.adminExport.contentType) ?? new Set();
    const existingAdminTtsSupported = adminField ? supportedFields.has(adminField) : false;
    const candidates = candidatesForTarget(batch, target, candidateMaps);
    const operationStatus = rowStatusForTarget(batch, target, adminField, existingAdminTtsSupported, candidates);
    const row = buildReviewRow(batch, target, adminField, existingAdminTtsSupported, candidates, operationStatus);

    manifest.totals.targets += 1;
    if (operationStatus === 'ready_after_db_lookup') batchSummary.readyRows += 1;
    if (operationStatus === 'manual_mapping_required') batchSummary.manualRows += 1;
    if (operationStatus === 'blocked') batchSummary.blockedRows += 1;

    if (operationStatus === 'manual_mapping_required' || (INCLUDE_READY && operationStatus === 'ready_after_db_lookup')) {
      rows.push(row);
    }
  }

  if (rows.length > 0) {
    const filePath = join(OUT_DIR, `${batch.batchId}.json`);
    writeJson(filePath, rows);
    batchSummary.outputFile = displayPath(filePath);
    batchSummary.writtenRows = rows.length;
  }

  manifest.totals.batches += 1;
  manifest.totals.readyRows += batchSummary.readyRows;
  manifest.totals.manualRows += batchSummary.manualRows;
  manifest.totals.blockedRows += batchSummary.blockedRows;
  manifest.totals.writtenRows += batchSummary.writtenRows;
  manifest.batches.push(batchSummary);
}

writeJson(join(OUT_DIR, '_manifest.json'), manifest);

console.log('TTS manual mapping review files generated.');
console.log(`- out: ${OUT_DIR}`);
console.log(`- existing-admin targets: ${manifest.totals.targets}`);
console.log(`- manual rows: ${manifest.totals.manualRows}`);
console.log(`- ready rows: ${manifest.totals.readyRows}`);
console.log(`- written rows: ${manifest.totals.writtenRows}`);
