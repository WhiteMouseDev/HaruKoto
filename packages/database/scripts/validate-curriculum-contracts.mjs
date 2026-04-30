import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PACKAGE_DIR = join(SCRIPT_DIR, '..');
const DATA_DIR = join(PACKAGE_DIR, 'data', 'curriculum');
const SCHEMA_DIR = join(PACKAGE_DIR, 'schemas');
const GRAMMAR_DIR = join(PACKAGE_DIR, 'data', 'grammar');
const VOCAB_DIR = join(PACKAGE_DIR, 'data', 'vocabulary');

const CONTRACT_FILES = [
  {
    label: 'PDF topic inventory',
    path: join(DATA_DIR, 'pdf-topic-inventory.json'),
    topArray: 'items',
  },
  {
    label: 'Curriculum topics',
    path: join(DATA_DIR, 'curriculum-topics.json'),
    topArray: 'topics',
  },
  {
    label: 'Topic grammar map',
    path: join(DATA_DIR, 'topic-grammar-map.json'),
    topArray: 'mappings',
  },
  {
    label: 'Topic vocabulary map',
    path: join(DATA_DIR, 'topic-vocabulary-map.json'),
    topArray: 'mappings',
  },
  {
    label: 'Example bank',
    path: join(DATA_DIR, 'example-bank.json'),
    topArray: 'examples',
  },
  {
    label: 'Question blueprints',
    path: join(DATA_DIR, 'question-blueprints.json'),
    topArray: 'blueprints',
  },
  {
    label: 'Grammar metadata v2',
    path: join(DATA_DIR, 'grammar-metadata-v2.json'),
    topArray: 'metadata',
  },
  {
    label: 'TTS target manifest',
    path: join(DATA_DIR, 'tts-target-manifest.json'),
    topArray: 'targets',
  },
  {
    label: 'TTS review batches',
    path: join(DATA_DIR, 'tts-review-batches.json'),
    topArray: 'batches',
  },
  {
    label: 'Lesson draft blueprints',
    path: join(DATA_DIR, 'lesson-draft-blueprints.json'),
    topArray: 'lessons',
  },
  {
    label: 'Lesson seed candidates',
    path: join(DATA_DIR, 'lesson-seed-candidates.json'),
    topArray: 'candidates',
  },
  {
    label: 'Scaffold candidates',
    path: join(DATA_DIR, 'scaffold-candidates.json'),
    topArray: 'candidates',
  },
  {
    label: 'Topic anchor policies',
    path: join(DATA_DIR, 'topic-anchor-policies.json'),
    topArray: 'policies',
  },
  {
    label: 'Contrast question policies',
    path: join(DATA_DIR, 'contrast-question-policies.json'),
    topArray: 'policies',
  },
  {
    label: 'Coverage priorities',
    path: join(DATA_DIR, 'coverage-priorities.json'),
    topArray: 'priorities',
  },
];

const SCHEMA_FILES = [
  'pdf-topic-inventory.schema.json',
  'curriculum-topic.schema.json',
  'topic-grammar-map.schema.json',
  'topic-vocabulary-map.schema.json',
  'example-bank.schema.json',
  'question-blueprint.schema.json',
  'grammar-metadata-v2.schema.json',
  'tts-target-manifest.schema.json',
  'tts-review-batch.schema.json',
  'lesson-draft-blueprint.schema.json',
  'lesson-seed-candidate.schema.json',
  'scaffold-candidate.schema.json',
  'topic-anchor-policy.schema.json',
  'contrast-question-policy.schema.json',
  'coverage-priority.schema.json',
];

const LEVELS = ['N5', 'N4', 'N3', 'N2', 'N1'];
const COVERAGE_STATUSES = new Set(['covered', 'partial', 'missing', 'deferred']);
const CURRENT_LESSON_QUESTION_TYPES = new Set(['VOCAB_MCQ', 'CONTEXT_CLOZE', 'SENTENCE_REORDER']);
const FUTURE_QUESTION_TYPES = new Set(['LISTENING_MCQ', 'USAGE_CONTRAST', 'REGISTER_CHOICE', 'KANA_READING']);
const AUDIO_TARGET_TYPES = new Set([
  'vocabulary',
  'grammar',
  'kana',
  'lesson_script',
  'example_sentence',
  'question_prompt',
]);
const AUDIO_FIELDS = new Set([
  'word',
  'reading',
  'japanese',
  'pattern',
  'example_sentence',
  'script_line',
  'question_prompt',
]);
const GENERATION_STATUSES = new Set(['missing', 'generated', 'approved', 'rejected', 'stale']);
const CACHE_KEY_STRATEGIES = new Set(['provider-model-speed-field-text-hash-v1']);
const ADMIN_TTS_FIELDS = new Map([
  ['vocabulary', new Set(['reading', 'word', 'example_sentence'])],
  ['grammar', new Set(['pattern', 'example_sentences'])],
  ['cloze', new Set(['sentence'])],
  ['sentence_arrange', new Set(['japanese_sentence'])],
  ['conversation', new Set(['situation'])],
]);
const TTS_REVIEW_SURFACES = new Set(['admin_existing_tts', 'admin_extension_required']);
const TTS_REVIEW_SOURCE_KINDS = new Set([
  'topic_vocabulary_fields',
  'topic_grammar_fields',
  'topic_grammar_question_prompts',
  'topic_kana_fields',
  'example_sentence_fields',
  'seed_candidate_script_lines',
  'seed_candidate_question_prompts',
]);
const TTS_ADMIN_EXPORT_MODES = new Set(['existing_admin_tts_fields', 'requires_admin_extension']);
const TTS_ADMIN_EXPORT_CONTENT_TYPES = new Set([
  'vocabulary',
  'grammar',
  'kana',
  'example_sentence_pool',
  'lesson_seed_candidate',
]);
const TTS_ADMIN_EXPORT_BLOCKERS = new Set([
  'admin_tts_field_gap',
  'admin_content_type_gap',
  'lesson_seed_admin_surface_gap',
]);
const EXAMPLE_SOURCE_KINDS = new Set(['harukoto_authored', 'public_dataset_adapted']);
const ORIGINALITY_STATUSES = new Set([
  'authored_not_source_copied',
  'needs_similarity_check',
  'approved_original',
]);
const TRACKS = new Set([
  'ABSOLUTE_ZERO_FOUNDATION',
  'N5_REINFORCEMENT',
  'N4_FOUNDATION',
  'N3_PLUS_EXTENSION',
  'CONVERSATION_REGISTER',
  'BUSINESS_KEIGO',
]);
const PRIORITIES = new Set(['P0', 'P1', 'P2', 'P3']);
const RECOMMENDED_WAVES = new Set([
  'WAVE_1_N5_PATCH',
  'WAVE_2_N4_FOUNDATION',
  'WAVE_3_N3_PLUS',
  'WAVE_4_REGISTER_BUSINESS',
]);
const LESSON_KINDS = new Set([
  'kana_scaffold',
  'reinforcement',
  'new_lesson',
  'bridge',
  'register',
  'business',
]);
const COVERAGE_GOALS = new Set([
  'cover_missing_topic',
  'split_partial_topic',
  'strengthen_existing_topic',
  'prepare_future_runtime',
]);
const VALIDATION_GATES = new Set([
  'ExampleOriginalityGate',
  'RuntimeQuestionCompatibilityGate',
  'AudioReadinessGate',
  'KoreanLearnerGate',
  'RegisterGate',
  'ContrastGate',
]);
const PRIORITY_BLOCKERS = new Set([
  'needs_original_examples',
  'needs_lesson_slot',
  'needs_runtime_support',
  'needs_tts_decision',
  'needs_human_review',
]);
const SCAFFOLD_TYPES = new Set(['kana', 'kanji']);
const ANCHOR_ROUTES = new Set([
  'scaffold_candidate',
  'vocab_skill_candidate',
  'new_grammar_metadata_v2',
  'split_grammar_metadata_v2',
]);
const ANCHOR_MODES = new Set([
  'scaffold',
  'vocabulary_skill',
  'new_n5_grammar',
  'split_n5_n4_grammar',
]);
const PROMOTION_READINESS_STATES = new Set(['blocked', 'ready_for_candidate', 'ready_for_review']);
const PROMOTION_REQUIREMENTS = new Set([
  'scaffold_shape_review',
  'grammar_metadata_v2',
  'contrast_question_policy',
  'runtime_question_review',
  'tts_readiness_review',
  'human_curriculum_review',
]);
const CONTRAST_ROUTES = new Set([
  'vocab_skill_contrast',
  'grammar_metadata_contrast',
  'grammar_split_contrast',
]);
const CONTRAST_REF_KINDS = new Set(['vocabulary_ref', 'grammar_ref', 'grammar_metadata']);
const GRAMMAR_METADATA_ROLES = new Set(['primary_topic', 'split_lower_level', 'split_upper_level']);
const GRAMMAR_METADATA_REGISTERS = new Set(['neutral', 'polite', 'casual', 'formal', 'written', 'business']);
const TARGET_SKILLS = new Set([
  'recognition',
  'form_recall',
  'context_selection',
  'sentence_building',
  'contrast',
  'listening',
  'conversation',
]);
const FORBIDDEN_DRAFT_TEXT = /\b(TODO|TBD|FIXME|PLACEHOLDER)\b|임시|테스트용/i;

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, 'utf8'));
}

function addIssue(rows, level, scope, message) {
  rows.push({ level, scope, message });
}

function hasText(value) {
  return typeof value === 'string' && value.trim() !== '';
}

function sameMultiset(left, right) {
  if (!Array.isArray(left) || !Array.isArray(right) || left.length !== right.length) {
    return false;
  }

  const counts = new Map();
  for (const item of left) counts.set(item, (counts.get(item) ?? 0) + 1);
  for (const item of right) {
    const next = (counts.get(item) ?? 0) - 1;
    if (next < 0) return false;
    if (next === 0) counts.delete(item);
    else counts.set(item, next);
  }
  return counts.size === 0;
}

function walkStrings(value, callback, path = '$') {
  if (typeof value === 'string') {
    callback(value, path);
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((item, index) => walkStrings(item, callback, `${path}[${index}]`));
    return;
  }
  if (value && typeof value === 'object') {
    for (const [key, item] of Object.entries(value)) {
      walkStrings(item, callback, `${path}.${key}`);
    }
  }
}

function grammarOrdersByLevel() {
  const byLevel = new Map();
  for (const level of LEVELS) {
    const filePath = join(GRAMMAR_DIR, `${level.toLowerCase()}-grammar.json`);
    const rows = readJson(filePath);
    byLevel.set(level, new Set(rows.map((row) => row.order)));
  }
  return byLevel;
}

function vocabularyOrdersByLevel() {
  const byLevel = new Map();
  for (const level of LEVELS) {
    const filePath = join(VOCAB_DIR, `${level.toLowerCase()}-words.json`);
    const rows = readJson(filePath);
    byLevel.set(level, new Map(rows.map((row) => [row.order, row])));
  }
  return byLevel;
}

function validateContractShell(file, rows) {
  if (!existsSync(file.path)) {
    addIssue(rows, 'FAIL', file.label, `Missing file: ${file.path}`);
    return null;
  }

  let data;
  try {
    data = readJson(file.path);
  } catch (error) {
    addIssue(rows, 'FAIL', file.label, `Invalid JSON: ${error.message}`);
    return null;
  }

  if (data.schemaVersion !== 1) {
    addIssue(rows, 'FAIL', file.label, 'schemaVersion must be 1.');
  }
  if (!['draft', 'review', 'approved'].includes(data.status)) {
    addIssue(rows, 'FAIL', file.label, 'status must be draft, review, or approved.');
  }
  if (!Array.isArray(data[file.topArray])) {
    addIssue(rows, 'FAIL', file.label, `${file.topArray} must be an array.`);
  } else if (data[file.topArray].length === 0) {
    addIssue(rows, 'WARN', file.label, `${file.topArray} is empty; Wave 0 contract only.`);
  }

  return data;
}

function validateSchemas(rows) {
  for (const name of SCHEMA_FILES) {
    const filePath = join(SCHEMA_DIR, name);
    if (!existsSync(filePath)) {
      addIssue(rows, 'FAIL', 'JSON schema', `Missing schema file: ${name}`);
      continue;
    }
    try {
      const schema = readJson(filePath);
      if (!schema.$schema || !schema.title || schema.type !== 'object') {
        addIssue(rows, 'FAIL', 'JSON schema', `${name} is missing required schema metadata.`);
      }
    } catch (error) {
      addIssue(rows, 'FAIL', 'JSON schema', `${name} is invalid JSON: ${error.message}`);
    }
  }
}

function validatePdfInventory(data, rows) {
  const seen = new Set();
  if (!data || !Array.isArray(data.items)) return seen;
  for (const item of data.items) {
    const scope = `pdf ${item?.pdfRef ?? '?'}`;
    if (typeof item?.pdfRef !== 'string' || !/^\d{3}$/.test(item.pdfRef)) {
      addIssue(rows, 'FAIL', scope, 'pdfRef must be a 3-digit string.');
      continue;
    }
    if (seen.has(item.pdfRef)) {
      addIssue(rows, 'FAIL', scope, 'Duplicate pdfRef.');
    }
    seen.add(item.pdfRef);
    if (!Array.isArray(item.topicCandidates) || item.topicCandidates.length === 0) {
      addIssue(rows, 'FAIL', scope, 'topicCandidates must contain at least one item.');
    }
    if (!Array.isArray(item.inferredLevels) || item.inferredLevels.length === 0) {
      addIssue(rows, 'FAIL', scope, 'inferredLevels must contain at least one item.');
    }
  }
  return seen;
}

function validateTopics(data, rows, grammarOrders, pdfRefs) {
  if (!data || !Array.isArray(data.topics)) {
    return { topicIds: new Set(), topicPdfRefs: new Set(), topicsById: new Map() };
  }

  const topicIds = new Set();
  const topicPdfRefs = new Set();
  const topicsById = new Map();
  for (const topic of data.topics) {
    const scope = topic?.topicId ?? 'topic ?';
    if (typeof topic?.topicId !== 'string' || !/^topic-[a-z0-9][a-z0-9-]*$/.test(topic.topicId)) {
      addIssue(rows, 'FAIL', scope, 'topicId must match topic-<slug>.');
      continue;
    }
    if (topicIds.has(topic.topicId)) {
      addIssue(rows, 'FAIL', scope, 'Duplicate topicId.');
    }
    topicIds.add(topic.topicId);
    topicsById.set(topic.topicId, topic);
    if (!COVERAGE_STATUSES.has(topic.coverageStatus)) {
      addIssue(rows, 'FAIL', scope, 'coverageStatus is invalid.');
    }
    if (!Array.isArray(topic.sourceRefs) || topic.sourceRefs.length === 0) {
      addIssue(rows, 'FAIL', scope, 'sourceRefs must contain at least one item.');
    }
    for (const sourceRef of topic.sourceRefs ?? []) {
      if (sourceRef.type === 'pdf') {
        if (!pdfRefs.has(sourceRef.ref)) {
          addIssue(rows, 'FAIL', scope, `sourceRefs contains unknown pdf ref ${sourceRef.ref}.`);
        }
        topicPdfRefs.add(sourceRef.ref);
      }
    }
    for (const mapping of topic.mappedGrammarOrders ?? []) {
      const orders = grammarOrders.get(mapping.level);
      if (!orders?.has(mapping.order)) {
        addIssue(rows, 'FAIL', scope, `Grammar ${mapping.level} order ${mapping.order} does not exist.`);
      }
    }
    if (!topic.audioPolicy) {
      addIssue(rows, 'FAIL', scope, 'audioPolicy is required for TTS readiness.');
    }
    if (topic.audioPolicy && !Array.isArray(topic.audioPolicy.ttsTargets)) {
      addIssue(rows, 'FAIL', scope, 'audioPolicy.ttsTargets must be an array.');
    }
    if (Array.isArray(topic.audioPolicy?.ttsTargets) && topic.audioPolicy.ttsTargets.length === 0) {
      addIssue(rows, 'FAIL', scope, 'audioPolicy.ttsTargets must not be empty.');
    }
    if (topic.audioPolicy?.audioTargetType && !AUDIO_TARGET_TYPES.has(topic.audioPolicy.audioTargetType)) {
      addIssue(rows, 'FAIL', scope, `Invalid audioTargetType: ${topic.audioPolicy.audioTargetType}`);
    }
  }
  return { topicIds, topicPdfRefs, topicsById };
}

function validateTopicGrammarMap(data, rows, grammarOrders, topicIds) {
  if (!data || !Array.isArray(data.mappings)) return;
  const seen = new Set();
  for (const mapping of data.mappings) {
    const scope = `${mapping?.topicId ?? 'topic ?'} -> ${mapping?.grammarLevel ?? '?'}:${mapping?.grammarOrder ?? '?'}`;
    if (!topicIds.has(mapping?.topicId)) {
      addIssue(rows, 'FAIL', scope, 'Mapping references an unknown topicId.');
    }
    const orders = grammarOrders.get(mapping?.grammarLevel);
    if (!orders?.has(mapping?.grammarOrder)) {
      addIssue(rows, 'FAIL', scope, 'Mapping references a missing grammar order.');
    }
    const key = `${mapping.topicId}:${mapping.grammarLevel}:${mapping.grammarOrder}`;
    if (seen.has(key)) {
      addIssue(rows, 'FAIL', scope, 'Duplicate topic grammar mapping.');
    }
    seen.add(key);
  }
}

function validateTopicVocabularyMap(data, rows, vocabularyOrders, topicIds) {
  const seen = new Set();
  const mappingsByTopicId = new Map();
  const exactMappingByTopicId = new Map();
  if (!data || !Array.isArray(data.mappings)) return { mappingsByTopicId, exactMappingByTopicId };

  for (const mapping of data.mappings) {
    const scope = `${mapping?.topicId ?? 'topic ?'} -> ${mapping?.vocabularyLevel ?? '?'}:${mapping?.vocabularyOrder ?? '?'}`;
    if (!topicIds.has(mapping?.topicId)) {
      addIssue(rows, 'FAIL', scope, 'Mapping references an unknown topicId.');
    }
    const vocabularyRow = vocabularyOrders.get(mapping?.vocabularyLevel)?.get(mapping?.vocabularyOrder);
    if (!vocabularyRow) {
      addIssue(rows, 'FAIL', scope, 'Mapping references a missing vocabulary order.');
    } else {
      if (mapping.word !== vocabularyRow.word) {
        addIssue(rows, 'FAIL', scope, 'word must match the source vocabulary row.');
      }
      if (mapping.reading !== vocabularyRow.reading) {
        addIssue(rows, 'FAIL', scope, 'reading must match the source vocabulary row.');
      }
      if (mapping.meaningKo !== vocabularyRow.meaningKo) {
        addIssue(rows, 'FAIL', scope, 'meaningKo must match the source vocabulary row.');
      }
    }
    if (!['exact', 'partial', 'related'].includes(mapping?.matchType)) {
      addIssue(rows, 'FAIL', scope, 'matchType must be exact, partial, or related.');
    }
    const key = `${mapping.topicId}:${mapping.vocabularyLevel}:${mapping.vocabularyOrder}`;
    if (seen.has(key)) {
      addIssue(rows, 'FAIL', scope, 'Duplicate topic vocabulary mapping.');
    }
    seen.add(key);

    if (!mappingsByTopicId.has(mapping.topicId)) mappingsByTopicId.set(mapping.topicId, []);
    mappingsByTopicId.get(mapping.topicId).push(mapping);
  }

  for (const [topicId, mappings] of mappingsByTopicId) {
    const exactMappings = mappings.filter((mapping) => mapping.matchType === 'exact');
    if (mappings.length === 1 && exactMappings.length === 1) {
      exactMappingByTopicId.set(topicId, exactMappings[0]);
    }
  }

  return { mappingsByTopicId, exactMappingByTopicId };
}

function validatePdfTopicCoverage(pdfRefs, topicPdfRefs, rows) {
  if (pdfRefs.size === 0) return;
  for (const pdfRef of pdfRefs) {
    if (!topicPdfRefs.has(pdfRef)) {
      addIssue(rows, 'FAIL', `pdf ${pdfRef}`, 'No curriculum topic sourceRef covers this PDF.');
    }
  }
}

function validateExamples(data, rows, topicIds) {
  const exampleIds = new Set();
  const exampleText = new Set();
  if (!data || !Array.isArray(data.examples)) return exampleIds;
  for (const example of data.examples) {
    const scope = example?.exampleId ?? 'example ?';
    if (typeof example?.exampleId !== 'string' || !/^ex-[a-z0-9][a-z0-9-]*$/.test(example.exampleId)) {
      addIssue(rows, 'FAIL', scope, 'exampleId must match ex-<slug>.');
      continue;
    }
    if (exampleIds.has(example.exampleId)) {
      addIssue(rows, 'FAIL', scope, 'Duplicate exampleId.');
    }
    exampleIds.add(example.exampleId);
    if (!topicIds.has(example.topicId)) {
      addIssue(rows, 'FAIL', scope, 'Example references an unknown topicId.');
    }
    if (!EXAMPLE_SOURCE_KINDS.has(example.sourceKind)) {
      addIssue(rows, 'FAIL', scope, 'sourceKind is invalid.');
    }
    if (!ORIGINALITY_STATUSES.has(example.originalityStatus)) {
      addIssue(rows, 'FAIL', scope, 'originalityStatus is invalid.');
    }
    if (example.sourceKind !== 'harukoto_authored') {
      addIssue(rows, 'WARN', scope, 'Example is not marked harukoto_authored.');
    }
    if (typeof example.japanese !== 'string' || example.japanese.trim() === '') {
      addIssue(rows, 'FAIL', scope, 'japanese is required.');
    } else if (exampleText.has(example.japanese)) {
      addIssue(rows, 'FAIL', scope, 'Duplicate japanese example text.');
    } else {
      exampleText.add(example.japanese);
    }
    if (Object.hasOwn(example.audio ?? {}, 'audioReviewStatus')) {
      addIssue(rows, 'FAIL', scope, 'Use generationStatus for audio lifecycle, not audioReviewStatus.');
    }
    if (!GENERATION_STATUSES.has(example.audio?.generationStatus)) {
      addIssue(rows, 'FAIL', scope, 'audio.generationStatus is invalid.');
    }
    if (!AUDIO_TARGET_TYPES.has(example.audio?.audioTargetType)) {
      addIssue(rows, 'FAIL', scope, 'audio.audioTargetType is invalid.');
    }
    if (!AUDIO_FIELDS.has(example.audio?.audioField)) {
      addIssue(rows, 'FAIL', scope, 'audio.audioField is invalid.');
    }
  }
  return exampleIds;
}

function validateQuestionBlueprints(data, rows, topicIds) {
  const blueprintIds = new Set();
  const coveredTopicIds = new Set();
  if (!data || !Array.isArray(data.blueprints)) return coveredTopicIds;
  for (const blueprint of data.blueprints) {
    const scope = blueprint?.blueprintId ?? 'blueprint ?';
    if (
      typeof blueprint?.blueprintId !== 'string' ||
      !/^qb-[a-z0-9][a-z0-9-]*$/.test(blueprint.blueprintId)
    ) {
      addIssue(rows, 'FAIL', scope, 'blueprintId must match qb-<slug>.');
      continue;
    }
    if (blueprintIds.has(blueprint.blueprintId)) {
      addIssue(rows, 'FAIL', scope, 'Duplicate blueprintId.');
    }
    blueprintIds.add(blueprint.blueprintId);
    if (!topicIds.has(blueprint.topicId)) {
      addIssue(rows, 'FAIL', scope, 'Blueprint references an unknown topicId.');
    } else {
      coveredTopicIds.add(blueprint.topicId);
    }
    for (const questionType of blueprint.recommendedQuestionTypes ?? []) {
      if (!CURRENT_LESSON_QUESTION_TYPES.has(questionType)) {
        addIssue(rows, 'FAIL', scope, `Unsupported runtime question type in recommendedQuestionTypes: ${questionType}`);
      }
    }
    for (const questionType of blueprint.draftFutureQuestionTypes ?? []) {
      if (!FUTURE_QUESTION_TYPES.has(questionType)) {
        addIssue(rows, 'FAIL', scope, `Unknown draft future question type: ${questionType}`);
      }
    }
    if (!Number.isInteger(blueprint.minDraftQuestions) || blueprint.minDraftQuestions < 1) {
      addIssue(rows, 'FAIL', scope, 'minDraftQuestions must be a positive integer.');
    }
  }
  for (const topicId of topicIds) {
    if (!coveredTopicIds.has(topicId)) {
      addIssue(rows, 'FAIL', topicId, 'No question blueprint covers this topic.');
    }
  }
  return coveredTopicIds;
}

function validateGrammarMetadataV2(data, rows, topicContext, exampleIds, grammarOrders) {
  const metadataIds = new Set();
  const metadataById = new Map();
  const metadataIdsByTopicId = new Map();

  if (!data || !Array.isArray(data.metadata)) return { metadataIds, metadataById, metadataIdsByTopicId };

  for (const item of data.metadata) {
    const scope = item?.metadataId ?? 'grammar metadata ?';
    if (typeof item?.metadataId !== 'string' || !/^gmv2-[a-z0-9][a-z0-9-]*$/.test(item.metadataId)) {
      addIssue(rows, 'FAIL', scope, 'metadataId must match gmv2-<slug>.');
      continue;
    }
    if (metadataIds.has(item.metadataId)) {
      addIssue(rows, 'FAIL', scope, 'Duplicate grammar metadataId.');
    }
    metadataIds.add(item.metadataId);
    metadataById.set(item.metadataId, item);

    if (item.status !== 'draft') {
      addIssue(rows, 'FAIL', scope, 'Grammar metadata v2 records must remain draft.');
    }
    const topic = topicContext.topicsById.get(item.topicId);
    if (!topic) {
      addIssue(rows, 'FAIL', scope, 'topicId references an unknown topic.');
    } else {
      if (!metadataIdsByTopicId.has(item.topicId)) metadataIdsByTopicId.set(item.topicId, new Set());
      metadataIdsByTopicId.get(item.topicId).add(item.metadataId);
    }
    if (!LEVELS.includes(item.jlptLevel)) {
      addIssue(rows, 'FAIL', scope, 'jlptLevel is invalid.');
    }
    if (!GRAMMAR_METADATA_ROLES.has(item.coverageRole)) {
      addIssue(rows, 'FAIL', scope, 'coverageRole is invalid.');
    }
    for (const field of [
      'titleKo',
      'pattern',
      'meaningKo',
      'formationKo',
      'usageNoteKo',
      'nuanceKo',
      'commonMistakesKo',
      'koreanComparisonKo',
      'notesKo',
    ]) {
      if (!hasText(item[field])) {
        addIssue(rows, 'FAIL', scope, `${field} is required.`);
      }
    }
    if (!GRAMMAR_METADATA_REGISTERS.has(item.register)) {
      addIssue(rows, 'FAIL', scope, 'register is invalid.');
    }
    if (!Array.isArray(item.targetSkills) || item.targetSkills.length === 0) {
      addIssue(rows, 'FAIL', scope, 'targetSkills must contain at least one item.');
    }
    for (const skill of item.targetSkills ?? []) {
      if (!TARGET_SKILLS.has(skill)) {
        addIssue(rows, 'FAIL', scope, `Unknown target skill: ${skill}.`);
      }
    }
    for (const exampleId of item.exampleIds ?? []) {
      if (!exampleIds.has(exampleId)) {
        addIssue(rows, 'FAIL', scope, `exampleIds references unknown example ${exampleId}.`);
      }
    }
    if (item.jlptLevel === 'N5' && item.coverageRole !== 'split_upper_level' && (item.exampleIds ?? []).length === 0) {
      addIssue(rows, 'FAIL', scope, 'N5 primary/lower grammar metadata needs at least one example.');
    }
    for (const ref of item.existingGrammarRefs ?? []) {
      if (!grammarOrders.get(ref.level)?.has(ref.order)) {
        addIssue(rows, 'FAIL', scope, `existing grammar ref ${ref.level}:${ref.order} does not exist.`);
      }
    }
    for (const field of item.audioPolicy?.ttsTargets ?? []) {
      if (!AUDIO_FIELDS.has(field)) {
        addIssue(rows, 'FAIL', scope, `Unknown audio policy target field: ${field}.`);
      }
    }
    if (!AUDIO_TARGET_TYPES.has(item.audioPolicy?.audioTargetType)) {
      addIssue(rows, 'FAIL', scope, 'audioPolicy.audioTargetType is invalid.');
    }
    if (!GENERATION_STATUSES.has(item.audioPolicy?.generationStatus)) {
      addIssue(rows, 'FAIL', scope, 'audioPolicy.generationStatus is invalid.');
    }

    walkStrings(item, (value, path) => {
      if (FORBIDDEN_DRAFT_TEXT.test(value)) {
        addIssue(rows, 'FAIL', scope, `Forbidden placeholder text at ${path}.`);
      }
    });
  }

  for (const [metadataId, item] of metadataById) {
    for (const contrastId of item.contrastMetadataIds ?? []) {
      if (!metadataIds.has(contrastId)) {
        addIssue(rows, 'FAIL', metadataId, `contrastMetadataIds references unknown metadata ${contrastId}.`);
      }
    }
  }

  return { metadataIds, metadataById, metadataIdsByTopicId };
}

function validateTtsTargetManifest(
  data,
  rows,
  topicsById,
  exampleIds,
  seedCandidateContext,
  vocabularyMapContext,
  vocabularyOrders,
) {
  const targetIds = new Set();
  const targetById = new Map();
  const topicTargetKeys = new Set();
  const exampleTargetKeys = new Set();
  const seedScriptTargetKeys = new Set();
  const seedQuestionTargetKeys = new Set();
  if (!data || !Array.isArray(data.targets)) return { targetIds, targetById };

  for (const target of data.targets) {
    const scope = target?.targetId ?? 'tts ?';
    if (typeof target?.targetId !== 'string' || !/^tts-[a-z0-9][a-z0-9-]*$/.test(target.targetId)) {
      addIssue(rows, 'FAIL', scope, 'targetId must match tts-<slug>.');
      continue;
    }
    if (targetIds.has(target.targetId)) {
      addIssue(rows, 'FAIL', scope, 'Duplicate TTS targetId.');
    }
    targetIds.add(target.targetId);
    targetById.set(target.targetId, target);
    if (!topicsById.has(target.topicId)) {
      addIssue(rows, 'FAIL', scope, 'TTS target references an unknown topicId.');
    }
    if (!AUDIO_TARGET_TYPES.has(target.audioTargetType)) {
      addIssue(rows, 'FAIL', scope, 'audioTargetType is invalid.');
    }
    if (!AUDIO_FIELDS.has(target.audioField)) {
      addIssue(rows, 'FAIL', scope, 'audioField is invalid.');
    }
    if (!GENERATION_STATUSES.has(target.generationStatus)) {
      addIssue(rows, 'FAIL', scope, 'generationStatus is invalid.');
    }
    if (!CACHE_KEY_STRATEGIES.has(target.cacheKeyStrategy)) {
      addIssue(rows, 'FAIL', scope, 'cacheKeyStrategy is invalid.');
    }
    if (Object.hasOwn(target, 'audioReviewStatus')) {
      addIssue(rows, 'FAIL', scope, 'Use generationStatus for TTS lifecycle, not audioReviewStatus.');
    }
    if (typeof target.textSource === 'string' && target.textSource.startsWith('curriculum-topics:')) {
      const [, topicId, field] = target.textSource.split(':');
      if (!topicsById.has(topicId)) {
        addIssue(rows, 'FAIL', scope, `textSource references unknown topic ${topicId}.`);
      }
      topicTargetKeys.add(`${topicId}:${field}`);
    } else if (typeof target.textSource === 'string' && target.textSource.startsWith('vocabulary:')) {
      const [, level, rawOrder, field] = target.textSource.split(':');
      const order = Number(rawOrder);
      if (!LEVELS.includes(level)) {
        addIssue(rows, 'FAIL', scope, 'vocabulary textSource level is invalid.');
      }
      if (!Number.isInteger(order) || !vocabularyOrders.get(level)?.has(order)) {
        addIssue(rows, 'FAIL', scope, `vocabulary textSource references missing order ${level}:${rawOrder}.`);
      }
      if (field !== target.audioField) {
        addIssue(rows, 'FAIL', scope, 'vocabulary textSource field must match audioField.');
      }
      if (target.audioTargetType !== 'vocabulary') {
        addIssue(rows, 'FAIL', scope, 'vocabulary textSource targets must use vocabulary audioTargetType.');
      }
      const exactMapping = vocabularyMapContext.exactMappingByTopicId.get(target.topicId);
      if (!exactMapping) {
        addIssue(rows, 'FAIL', scope, 'vocabulary textSource requires a single exact topic vocabulary mapping.');
      } else if (exactMapping.vocabularyLevel !== level || exactMapping.vocabularyOrder !== order) {
        addIssue(rows, 'FAIL', scope, 'vocabulary textSource must match the exact topic vocabulary mapping.');
      }
      const expectedTargetId = `tts-vocabulary-${String(level).toLowerCase()}-${order}-${String(field).replace(/_/g, '-')}`;
      if (target.targetId !== expectedTargetId) {
        addIssue(rows, 'FAIL', scope, `vocabulary targetId must be ${expectedTargetId}.`);
      }
      topicTargetKeys.add(`${target.topicId}:${field}`);
    } else if (typeof target.textSource === 'string' && target.textSource.startsWith('example-bank:')) {
      const [, exampleId] = target.textSource.split(':');
      if (!exampleIds.has(exampleId)) {
        addIssue(rows, 'FAIL', scope, `textSource references unknown example ${exampleId}.`);
      }
      exampleTargetKeys.add(exampleId);
    } else if (typeof target.textSource === 'string' && target.textSource.startsWith('lesson-seed-candidates:')) {
      const [, candidateId, sourceKind, rawOrder] = target.textSource.split(':');
      const candidate = seedCandidateContext.candidateById.get(candidateId);
      const order = Number(rawOrder);
      if (!candidate) {
        addIssue(rows, 'FAIL', scope, `textSource references unknown seed candidate ${candidateId}.`);
      } else {
        if (!(candidate.sourceTopicIds ?? []).includes(target.topicId)) {
          addIssue(rows, 'FAIL', scope, 'Seed candidate TTS target topicId must match candidate sourceTopicIds.');
        }
        if (!Number.isInteger(order) || order < 1) {
          addIssue(rows, 'FAIL', scope, 'Seed candidate TTS textSource order must be a positive integer.');
        } else if (sourceKind === 'script') {
          const line = candidate.seedShape?.content_jsonb?.reading?.script?.[order - 1];
          if (!line) {
            addIssue(rows, 'FAIL', scope, `textSource references missing script line ${order}.`);
          }
          if (target.audioTargetType !== 'lesson_script' || target.audioField !== 'script_line') {
            addIssue(rows, 'FAIL', scope, 'Seed script targets must use lesson_script/script_line.');
          }
          if (line?.voice_id && target.preferredVoiceId !== line.voice_id) {
            addIssue(rows, 'FAIL', scope, 'Seed script target preferredVoiceId must match script voice_id.');
          }
          seedScriptTargetKeys.add(`${candidateId}:${order}`);
        } else if (sourceKind === 'question') {
          const question = (candidate.seedShape?.content_jsonb?.questions ?? []).find(
            (item) => item.order === order,
          );
          if (!question) {
            addIssue(rows, 'FAIL', scope, `textSource references missing question ${order}.`);
          }
          if (target.audioTargetType !== 'question_prompt' || target.audioField !== 'question_prompt') {
            addIssue(rows, 'FAIL', scope, 'Seed question targets must use question_prompt/question_prompt.');
          }
          seedQuestionTargetKeys.add(`${candidateId}:${order}`);
        } else {
          addIssue(rows, 'FAIL', scope, 'Seed candidate TTS source kind must be script or question.');
        }
      }
    } else {
      addIssue(
        rows,
        'FAIL',
        scope,
        'textSource must start with curriculum-topics:, example-bank:, or lesson-seed-candidates:.',
      );
    }
  }

  for (const [topicId, topic] of topicsById) {
    for (const field of topic.audioPolicy?.ttsTargets ?? []) {
      if (!topicTargetKeys.has(`${topicId}:${field}`)) {
        addIssue(rows, 'FAIL', topicId, `No TTS manifest target covers audio field ${field}.`);
      }
    }
  }
  for (const exampleId of exampleIds) {
    if (!exampleTargetKeys.has(exampleId)) {
      addIssue(rows, 'FAIL', exampleId, 'No TTS manifest target covers this example.');
    }
  }
  for (const [candidateId, candidate] of seedCandidateContext.candidateById) {
    if (!(candidate.validationGates ?? []).includes('AudioReadinessGate')) continue;
    const script = candidate.seedShape?.content_jsonb?.reading?.script ?? [];
    script.forEach((_, index) => {
      const order = index + 1;
      if (!seedScriptTargetKeys.has(`${candidateId}:${order}`)) {
        addIssue(rows, 'FAIL', candidateId, `No TTS manifest target covers script line ${order}.`);
      }
    });
    for (const question of candidate.seedShape?.content_jsonb?.questions ?? []) {
      if (!seedQuestionTargetKeys.has(`${candidateId}:${question.order}`)) {
        addIssue(rows, 'FAIL', candidateId, `No TTS manifest target covers question prompt ${question.order}.`);
      }
    }
  }

  return { targetIds, targetById };
}

function validateTtsReviewBatches(data, rows, ttsTargetContext) {
  const batchIds = new Set();
  const coveredTargetIds = new Set();

  if (!data || !Array.isArray(data.batches)) return;

  for (const batch of data.batches) {
    const scope = batch?.batchId ?? 'tts review batch ?';
    if (typeof batch?.batchId !== 'string' || !/^tts-review-[a-z0-9][a-z0-9-]*$/.test(batch.batchId)) {
      addIssue(rows, 'FAIL', scope, 'batchId must match tts-review-<slug>.');
      continue;
    }
    if (batchIds.has(batch.batchId)) {
      addIssue(rows, 'FAIL', scope, 'Duplicate TTS review batchId.');
    }
    batchIds.add(batch.batchId);
    if (batch.status !== 'draft') {
      addIssue(rows, 'FAIL', scope, 'TTS review batches must remain draft before export approval.');
    }
    if (!TTS_REVIEW_SURFACES.has(batch.reviewSurface)) {
      addIssue(rows, 'FAIL', scope, 'reviewSurface is invalid.');
    }
    if (!TTS_REVIEW_SOURCE_KINDS.has(batch.sourceKind)) {
      addIssue(rows, 'FAIL', scope, 'sourceKind is invalid.');
    }
    if (!Array.isArray(batch.targetIds) || batch.targetIds.length === 0) {
      addIssue(rows, 'FAIL', scope, 'targetIds must contain at least one target.');
    }
    if (batch.targetCount !== (batch.targetIds ?? []).length) {
      addIssue(rows, 'FAIL', scope, 'targetCount must match targetIds length.');
    }

    const targets = [];
    for (const targetId of batch.targetIds ?? []) {
      const target = ttsTargetContext.targetById.get(targetId);
      if (!target) {
        addIssue(rows, 'FAIL', scope, `targetIds references unknown TTS target ${targetId}.`);
        continue;
      }
      if (coveredTargetIds.has(targetId)) {
        addIssue(rows, 'FAIL', scope, `TTS target ${targetId} appears in more than one review batch.`);
      }
      coveredTargetIds.add(targetId);
      targets.push(target);
    }

    const requiredBeforePublishCount = targets.filter((target) => target.requiredBeforePublish).length;
    if (batch.requiredBeforePublishCount !== requiredBeforePublishCount) {
      addIssue(rows, 'FAIL', scope, 'requiredBeforePublishCount must match targetIds.');
    }
    const statusSummary = Object.fromEntries([...GENERATION_STATUSES].map((status) => [status, 0]));
    for (const target of targets) {
      statusSummary[target.generationStatus] = (statusSummary[target.generationStatus] ?? 0) + 1;
    }
    for (const status of GENERATION_STATUSES) {
      if (batch.generationStatusSummary?.[status] !== statusSummary[status]) {
        addIssue(rows, 'FAIL', scope, `generationStatusSummary.${status} must match targetIds.`);
      }
    }

    const adminExport = batch.adminExport ?? {};
    if (!TTS_ADMIN_EXPORT_MODES.has(adminExport.mode)) {
      addIssue(rows, 'FAIL', scope, 'adminExport.mode is invalid.');
    }
    if (!TTS_ADMIN_EXPORT_CONTENT_TYPES.has(adminExport.contentType)) {
      addIssue(rows, 'FAIL', scope, 'adminExport.contentType is invalid.');
    }
    if (batch.reviewSurface === 'admin_existing_tts' && adminExport.mode !== 'existing_admin_tts_fields') {
      addIssue(rows, 'FAIL', scope, 'admin_existing_tts batches must use existing_admin_tts_fields mode.');
    }
    if (batch.reviewSurface === 'admin_extension_required' && adminExport.mode !== 'requires_admin_extension') {
      addIssue(rows, 'FAIL', scope, 'admin_extension_required batches must use requires_admin_extension mode.');
    }
    if (adminExport.mode === 'existing_admin_tts_fields') {
      const adminFields = ADMIN_TTS_FIELDS.get(adminExport.contentType);
      if (!adminFields) {
        addIssue(rows, 'FAIL', scope, 'existing admin export must use a supported admin contentType.');
      }
      for (const mapping of adminExport.fieldMappings ?? []) {
        if (!adminFields?.has(mapping.adminField)) {
          addIssue(rows, 'FAIL', scope, `admin field ${mapping.adminField} is not supported for ${adminExport.contentType}.`);
        }
      }
      if ((adminExport.blockers ?? []).length > 0) {
        addIssue(rows, 'FAIL', scope, 'existing admin export batches must not include blockers.');
      }
    }
    if (adminExport.mode === 'requires_admin_extension' && (adminExport.blockers ?? []).length === 0) {
      addIssue(rows, 'FAIL', scope, 'admin extension batches must list at least one blocker.');
    }
    for (const blocker of adminExport.blockers ?? []) {
      if (!TTS_ADMIN_EXPORT_BLOCKERS.has(blocker)) {
        addIssue(rows, 'FAIL', scope, `Unknown admin export blocker: ${blocker}.`);
      }
    }

    const audioFieldMappings = new Map(
      (adminExport.fieldMappings ?? []).map((mapping) => [mapping.audioField, mapping.adminField]),
    );
    for (const target of targets) {
      if (!audioFieldMappings.has(target.audioField)) {
        addIssue(rows, 'FAIL', scope, `No admin field mapping covers audioField ${target.audioField}.`);
      }
    }
    if (!Array.isArray(batch.reviewerChecklist) || batch.reviewerChecklist.length === 0) {
      addIssue(rows, 'FAIL', scope, 'reviewerChecklist must not be empty.');
    }

    walkStrings(batch, (value, path) => {
      if (FORBIDDEN_DRAFT_TEXT.test(value)) {
        addIssue(rows, 'FAIL', scope, `Forbidden placeholder text at ${path}.`);
      }
    });
  }

  for (const targetId of ttsTargetContext.targetIds) {
    if (!coveredTargetIds.has(targetId)) {
      addIssue(rows, 'FAIL', targetId, 'No TTS review batch covers this target.');
    }
  }
}

function validateLessonDraftBlueprints(data, rows, topicContext, exampleIds) {
  const lessonIds = new Set();
  const lessonById = new Map();
  const nonCoveredTopicIds = new Set();
  for (const [topicId, topic] of topicContext.topicsById) {
    if (topic.coverageStatus !== 'covered') nonCoveredTopicIds.add(topicId);
  }

  if (!data || !Array.isArray(data.lessons)) return { lessonIds, lessonById };

  const coveredTopicIds = new Set();
  for (const lesson of data.lessons) {
    const scope = lesson?.lessonBlueprintId ?? 'lesson blueprint ?';
    if (
      typeof lesson?.lessonBlueprintId !== 'string' ||
      !/^ldb-[a-z0-9][a-z0-9-]*$/.test(lesson.lessonBlueprintId)
    ) {
      addIssue(rows, 'FAIL', scope, 'lessonBlueprintId must match ldb-<slug>.');
      continue;
    }
    if (lessonIds.has(lesson.lessonBlueprintId)) {
      addIssue(rows, 'FAIL', scope, 'Duplicate lessonBlueprintId.');
    }
    lessonIds.add(lesson.lessonBlueprintId);
    lessonById.set(lesson.lessonBlueprintId, lesson);
    if (lesson.status !== 'draft') {
      addIssue(rows, 'FAIL', scope, 'Generated lesson blueprints must remain draft.');
    }
    if (!TRACKS.has(lesson.track)) {
      addIssue(rows, 'FAIL', scope, 'track is invalid.');
    }
    if (!LESSON_KINDS.has(lesson.lessonKind)) {
      addIssue(rows, 'FAIL', scope, 'lessonKind is invalid.');
    }
    if (!COVERAGE_GOALS.has(lesson.coverageGoal)) {
      addIssue(rows, 'FAIL', scope, 'coverageGoal is invalid.');
    }
    if (!topicContext.topicIds.has(lesson.primaryTopicId)) {
      addIssue(rows, 'FAIL', scope, 'primaryTopicId references an unknown topic.');
    }
    if (!Array.isArray(lesson.topicIds) || !lesson.topicIds.includes(lesson.primaryTopicId)) {
      addIssue(rows, 'FAIL', scope, 'topicIds must include primaryTopicId.');
    }
    for (const topicId of lesson.topicIds ?? []) {
      if (!topicContext.topicIds.has(topicId)) {
        addIssue(rows, 'FAIL', scope, `topicIds references unknown topic ${topicId}.`);
      } else {
        coveredTopicIds.add(topicId);
      }
    }
    for (const questionType of lesson.runtimeQuestionTypes ?? []) {
      if (!CURRENT_LESSON_QUESTION_TYPES.has(questionType)) {
        addIssue(rows, 'FAIL', scope, `Unsupported runtime question type: ${questionType}.`);
      }
    }
    for (const questionType of lesson.draftFutureQuestionTypes ?? []) {
      if (!FUTURE_QUESTION_TYPES.has(questionType)) {
        addIssue(rows, 'FAIL', scope, `Unknown draft future question type: ${questionType}.`);
      }
    }
    for (const exampleId of lesson.exampleIds ?? []) {
      if (!exampleIds.has(exampleId)) {
        addIssue(rows, 'FAIL', scope, `exampleIds references unknown example ${exampleId}.`);
      }
    }
    for (const gate of lesson.validationGates ?? []) {
      if (!VALIDATION_GATES.has(gate)) {
        addIssue(rows, 'FAIL', scope, `Unknown validation gate: ${gate}.`);
      }
    }
    if (!(lesson.validationGates ?? []).includes('RuntimeQuestionCompatibilityGate')) {
      addIssue(rows, 'FAIL', scope, 'RuntimeQuestionCompatibilityGate is required.');
    }
    if (!(lesson.validationGates ?? []).includes('ExampleOriginalityGate')) {
      addIssue(rows, 'FAIL', scope, 'ExampleOriginalityGate is required.');
    }
    const topic = topicContext.topicsById.get(lesson.primaryTopicId);
    if (topic?.coverageStatus === 'partial' && lesson.coverageGoal !== 'split_partial_topic') {
      addIssue(rows, 'FAIL', scope, 'Partial topics must use split_partial_topic coverageGoal.');
    }
    if (topic?.coverageStatus === 'missing' && lesson.coverageGoal !== 'cover_missing_topic') {
      addIssue(rows, 'FAIL', scope, 'Missing topics must use cover_missing_topic coverageGoal.');
    }
  }

  for (const topicId of nonCoveredTopicIds) {
    if (!coveredTopicIds.has(topicId)) {
      addIssue(rows, 'FAIL', topicId, 'No lesson draft blueprint covers this non-covered topic.');
    }
  }
  return { lessonIds, lessonById };
}

function validateSeedCandidateQuestion(question, scope, rows) {
  const questionScope = `${scope} q${question?.order ?? '?'}`;

  if (!Number.isInteger(question?.order) || question.order < 1) {
    addIssue(rows, 'FAIL', questionScope, 'question.order must be a positive integer.');
  }
  if (!CURRENT_LESSON_QUESTION_TYPES.has(question?.type)) {
    addIssue(rows, 'FAIL', questionScope, `Unsupported runtime question type: ${question?.type}.`);
    return;
  }
  if (!hasText(question.prompt)) {
    addIssue(rows, 'FAIL', questionScope, 'prompt is required.');
  }
  if (!hasText(question.explanation)) {
    addIssue(rows, 'FAIL', questionScope, 'explanation is required.');
  }

  if (question.type === 'VOCAB_MCQ' || question.type === 'CONTEXT_CLOZE') {
    if (!Array.isArray(question.options) || question.options.length < 2) {
      addIssue(rows, 'FAIL', questionScope, 'options must contain at least 2 items.');
      return;
    }

    const optionIds = new Set();
    for (const option of question.options) {
      if (!hasText(option?.id)) {
        addIssue(rows, 'FAIL', questionScope, 'every option needs a non-empty id.');
      }
      if (!hasText(option?.text)) {
        addIssue(rows, 'FAIL', questionScope, 'every option needs non-empty text.');
      }
      if (optionIds.has(option?.id)) {
        addIssue(rows, 'FAIL', questionScope, `duplicate option id ${option.id}.`);
      }
      optionIds.add(option?.id);
    }

    if (!optionIds.has(question.correct_answer)) {
      addIssue(rows, 'FAIL', questionScope, 'correct_answer must match an option id.');
    }
  }

  if (question.type === 'SENTENCE_REORDER') {
    if (!Array.isArray(question.tokens) || question.tokens.length < 2) {
      addIssue(rows, 'FAIL', questionScope, 'tokens must contain at least 2 items.');
    }
    if (!Array.isArray(question.correct_order) || question.correct_order.length < 2) {
      addIssue(rows, 'FAIL', questionScope, 'correct_order must contain at least 2 items.');
    }
    if (!sameMultiset(question.tokens, question.correct_order)) {
      addIssue(rows, 'FAIL', questionScope, 'tokens and correct_order must contain the same values.');
    }
  }
}

function validateLessonSeedCandidates(
  data,
  rows,
  topicContext,
  exampleIds,
  lessonDraftContext,
  grammarOrders,
  vocabularyOrders,
) {
  const candidateIds = new Set();
  const candidateTopicIds = new Set();
  const candidateById = new Map();
  const candidateByTopicId = new Map();
  const targetLessonNos = new Set();

  if (!data || !Array.isArray(data.candidates)) {
    return { candidateIds, candidateTopicIds, candidateById, candidateByTopicId };
  }

  for (const candidate of data.candidates) {
    const scope = candidate?.candidateId ?? 'lesson seed candidate ?';
    if (typeof candidate?.candidateId !== 'string' || !/^lsc-[a-z0-9][a-z0-9-]*$/.test(candidate.candidateId)) {
      addIssue(rows, 'FAIL', scope, 'candidateId must match lsc-<slug>.');
      continue;
    }
    if (candidateIds.has(candidate.candidateId)) {
      addIssue(rows, 'FAIL', scope, 'Duplicate candidateId.');
    }
    candidateIds.add(candidate.candidateId);
    candidateById.set(candidate.candidateId, candidate);

    if (candidate.status !== 'draft') {
      addIssue(rows, 'FAIL', scope, 'Lesson seed candidates must remain draft before promotion.');
    }

    const lessonBlueprint = lessonDraftContext.lessonById.get(candidate.lessonBlueprintId);
    if (!lessonBlueprint) {
      addIssue(rows, 'FAIL', scope, 'lessonBlueprintId references an unknown lesson draft blueprint.');
    }

    const sourceTopicIds = candidate.sourceTopicIds ?? [];
    if (!Array.isArray(sourceTopicIds) || sourceTopicIds.length === 0) {
      addIssue(rows, 'FAIL', scope, 'sourceTopicIds must contain at least one topic.');
    }
    for (const topicId of sourceTopicIds) {
      if (!topicContext.topicIds.has(topicId)) {
        addIssue(rows, 'FAIL', scope, `sourceTopicIds references unknown topic ${topicId}.`);
      }
      if (lessonBlueprint && !lessonBlueprint.topicIds.includes(topicId)) {
        addIssue(rows, 'FAIL', scope, `source topic ${topicId} is not covered by the lesson draft blueprint.`);
      }
      candidateTopicIds.add(topicId);
      if (candidateByTopicId.has(topicId)) {
        addIssue(rows, 'FAIL', scope, `Duplicate lesson seed candidate for topic ${topicId}.`);
      }
      candidateByTopicId.set(topicId, candidate);
    }

    const candidateExampleIds = candidate.exampleIds ?? [];
    if (!Array.isArray(candidateExampleIds) || candidateExampleIds.length === 0) {
      addIssue(rows, 'FAIL', scope, 'exampleIds must contain at least one example.');
    }
    for (const exampleId of candidateExampleIds) {
      if (!exampleIds.has(exampleId)) {
        addIssue(rows, 'FAIL', scope, `exampleIds references unknown example ${exampleId}.`);
      }
      if (lessonBlueprint && !(lessonBlueprint.exampleIds ?? []).includes(exampleId)) {
        addIssue(rows, 'FAIL', scope, `example ${exampleId} is not linked by the lesson draft blueprint.`);
      }
    }

    for (const gate of candidate.validationGates ?? []) {
      if (!VALIDATION_GATES.has(gate)) {
        addIssue(rows, 'FAIL', scope, `Unknown validation gate: ${gate}.`);
      }
    }
    for (const requiredGate of [
      'ExampleOriginalityGate',
      'RuntimeQuestionCompatibilityGate',
      'KoreanLearnerGate',
    ]) {
      if (!(candidate.validationGates ?? []).includes(requiredGate)) {
        addIssue(rows, 'FAIL', scope, `${requiredGate} is required.`);
      }
    }

    const promotionTarget = candidate.promotionTarget;
    if (promotionTarget?.publishStatus !== 'DRAFT') {
      addIssue(rows, 'FAIL', scope, 'promotionTarget.publishStatus must remain DRAFT.');
    }
    if (promotionTarget?.level && !LEVELS.includes(promotionTarget.level)) {
      addIssue(rows, 'FAIL', scope, 'promotionTarget.level is invalid.');
    }
    const targetKey = `${promotionTarget?.level ?? '?'}:${promotionTarget?.lessonNo ?? '?'}`;
    if (targetLessonNos.has(targetKey)) {
      addIssue(rows, 'FAIL', scope, 'Duplicate promotionTarget lesson number.');
    }
    targetLessonNos.add(targetKey);

    const seedShape = candidate.seedShape ?? {};
    if (!hasText(seedShape.title)) addIssue(rows, 'FAIL', scope, 'seedShape.title is required.');
    if (!hasText(seedShape.subtitle)) addIssue(rows, 'FAIL', scope, 'seedShape.subtitle is required.');
    if (!hasText(seedShape.topic)) addIssue(rows, 'FAIL', scope, 'seedShape.topic is required.');
    if (!Number.isInteger(seedShape.estimated_minutes) || seedShape.estimated_minutes < 1) {
      addIssue(rows, 'FAIL', scope, 'seedShape.estimated_minutes must be a positive integer.');
    }

    const grammar = seedShape.grammar ?? {};
    if (promotionTarget?.level && grammar.level !== promotionTarget.level) {
      addIssue(rows, 'FAIL', scope, 'seedShape.grammar.level must match promotionTarget.level.');
    }
    if (!grammarOrders.get(grammar.level)?.has(grammar.grammar_order)) {
      addIssue(rows, 'FAIL', scope, `grammar order ${grammar.grammar_order} not found for ${grammar.level}.`);
    }
    for (const order of grammar.supporting_grammar_orders ?? []) {
      if (!grammarOrders.get(grammar.level)?.has(order)) {
        addIssue(rows, 'FAIL', scope, `supporting grammar order ${order} not found for ${grammar.level}.`);
      }
    }

    const vocabOrders = seedShape.vocab_orders ?? [];
    if (!Array.isArray(vocabOrders) || vocabOrders.length === 0) {
      addIssue(rows, 'FAIL', scope, 'seedShape.vocab_orders must contain at least one item.');
    }
    const seenVocabOrders = new Set();
    for (const order of vocabOrders) {
      if (!Number.isInteger(order)) {
        addIssue(rows, 'FAIL', scope, `vocabulary order must be an integer (${order}).`);
        continue;
      }
      if (seenVocabOrders.has(order)) {
        addIssue(rows, 'FAIL', scope, `Duplicate vocabulary order ${order}.`);
      }
      seenVocabOrders.add(order);
      if (!vocabularyOrders.get(promotionTarget?.level)?.has(order)) {
        addIssue(rows, 'FAIL', scope, `vocabulary order ${order} not found for ${promotionTarget?.level}.`);
      }
    }

    const reading = seedShape.content_jsonb?.reading;
    const script = reading?.script;
    if (!reading || !Array.isArray(script) || script.length < 3 || script.length > 6) {
      addIssue(rows, 'FAIL', scope, 'seedShape.content_jsonb.reading.script must contain 3-6 lines.');
    } else {
      script.forEach((line, index) => {
        const lineScope = `${scope} script[${index}]`;
        if (!hasText(line?.speaker)) addIssue(rows, 'FAIL', lineScope, 'speaker is required.');
        if (!hasText(line?.voice_id)) addIssue(rows, 'FAIL', lineScope, 'voice_id is required.');
        if (!hasText(line?.text)) addIssue(rows, 'FAIL', lineScope, 'text is required.');
        if (!hasText(line?.translation)) addIssue(rows, 'FAIL', lineScope, 'translation is required.');
      });
    }

    const questions = seedShape.content_jsonb?.questions;
    if (!Array.isArray(questions) || questions.length < 5) {
      addIssue(rows, 'FAIL', scope, 'seedShape.content_jsonb.questions must contain at least 5 questions.');
    } else {
      const questionOrders = questions.map((question) => question.order);
      const expectedQuestionOrders = questions.map((_, index) => index + 1);
      if (questionOrders.join(',') !== expectedQuestionOrders.join(',')) {
        addIssue(rows, 'FAIL', scope, 'question order must be contiguous from 1.');
      }
      for (const question of questions) validateSeedCandidateQuestion(question, scope, rows);
    }

    walkStrings(candidate, (value, path) => {
      if (FORBIDDEN_DRAFT_TEXT.test(value)) {
        addIssue(rows, 'FAIL', scope, `Forbidden placeholder text at ${path}.`);
      }
    });
  }

  return { candidateIds, candidateTopicIds, candidateById, candidateByTopicId };
}

function validateScaffoldCandidates(data, rows, topicContext, exampleIds, lessonDraftContext) {
  const scaffoldIds = new Set();
  const scaffoldTopicIds = new Set();
  const targetLessonNos = new Set();

  if (!data || !Array.isArray(data.candidates)) return { scaffoldIds, scaffoldTopicIds };

  for (const candidate of data.candidates) {
    const scope = candidate?.candidateId ?? 'scaffold candidate ?';
    if (typeof candidate?.candidateId !== 'string' || !/^scaf-[a-z0-9][a-z0-9-]*$/.test(candidate.candidateId)) {
      addIssue(rows, 'FAIL', scope, 'candidateId must match scaf-<slug>.');
      continue;
    }
    if (scaffoldIds.has(candidate.candidateId)) {
      addIssue(rows, 'FAIL', scope, 'Duplicate scaffold candidateId.');
    }
    scaffoldIds.add(candidate.candidateId);

    if (candidate.status !== 'draft') {
      addIssue(rows, 'FAIL', scope, 'Scaffold candidates must remain draft before promotion.');
    }
    if (!SCAFFOLD_TYPES.has(candidate.scaffoldType)) {
      addIssue(rows, 'FAIL', scope, 'scaffoldType is invalid.');
    }

    const lessonBlueprint = lessonDraftContext.lessonById.get(candidate.lessonBlueprintId);
    if (!lessonBlueprint) {
      addIssue(rows, 'FAIL', scope, 'lessonBlueprintId references an unknown lesson draft blueprint.');
    } else if (lessonBlueprint.lessonKind !== 'kana_scaffold') {
      addIssue(rows, 'FAIL', scope, 'Scaffold candidates must reference a kana_scaffold lesson blueprint.');
    }

    for (const topicId of candidate.sourceTopicIds ?? []) {
      const topic = topicContext.topicsById.get(topicId);
      if (!topic) {
        addIssue(rows, 'FAIL', scope, `sourceTopicIds references unknown topic ${topicId}.`);
      } else {
        scaffoldTopicIds.add(topicId);
        if (candidate.scaffoldType === 'kana' && topic.topicType !== 'kana') {
          addIssue(rows, 'FAIL', scope, 'kana scaffold must reference a kana topic.');
        }
        if (candidate.scaffoldType === 'kanji' && topic.topicType !== 'kanji') {
          addIssue(rows, 'FAIL', scope, 'kanji scaffold must reference a kanji topic.');
        }
      }
      if (lessonBlueprint && !lessonBlueprint.topicIds.includes(topicId)) {
        addIssue(rows, 'FAIL', scope, `source topic ${topicId} is not covered by the lesson draft blueprint.`);
      }
    }

    for (const exampleId of candidate.exampleIds ?? []) {
      if (!exampleIds.has(exampleId)) {
        addIssue(rows, 'FAIL', scope, `exampleIds references unknown example ${exampleId}.`);
      }
      if (lessonBlueprint && !(lessonBlueprint.exampleIds ?? []).includes(exampleId)) {
        addIssue(rows, 'FAIL', scope, `example ${exampleId} is not linked by the lesson draft blueprint.`);
      }
    }

    if (candidate.promotionTarget?.publishStatus !== 'DRAFT') {
      addIssue(rows, 'FAIL', scope, 'promotionTarget.publishStatus must remain DRAFT.');
    }
    if (candidate.promotionTarget?.track !== 'ABSOLUTE_ZERO_FOUNDATION') {
      addIssue(rows, 'FAIL', scope, 'promotionTarget.track must be ABSOLUTE_ZERO_FOUNDATION.');
    }
    if (candidate.promotionTarget?.jlptLevel !== 'ABSOLUTE_ZERO') {
      addIssue(rows, 'FAIL', scope, 'promotionTarget.jlptLevel must be ABSOLUTE_ZERO.');
    }
    const targetKey = `${candidate.promotionTarget?.track ?? '?'}:${candidate.promotionTarget?.suggestedLessonNo ?? '?'}`;
    if (targetLessonNos.has(targetKey)) {
      addIssue(rows, 'FAIL', scope, 'Duplicate scaffold promotionTarget suggestedLessonNo.');
    }
    targetLessonNos.add(targetKey);

    for (const questionType of candidate.runtimeQuestionTypes ?? []) {
      if (!CURRENT_LESSON_QUESTION_TYPES.has(questionType)) {
        addIssue(rows, 'FAIL', scope, `Unsupported runtime question type: ${questionType}.`);
      }
    }
    for (const questionType of candidate.draftFutureQuestionTypes ?? []) {
      if (!FUTURE_QUESTION_TYPES.has(questionType)) {
        addIssue(rows, 'FAIL', scope, `Unknown draft future question type: ${questionType}.`);
      }
    }
    for (const gate of candidate.validationGates ?? []) {
      if (!VALIDATION_GATES.has(gate)) {
        addIssue(rows, 'FAIL', scope, `Unknown validation gate: ${gate}.`);
      }
    }
    for (const requiredGate of [
      'ExampleOriginalityGate',
      'RuntimeQuestionCompatibilityGate',
      'KoreanLearnerGate',
      'AudioReadinessGate',
    ]) {
      if (!(candidate.validationGates ?? []).includes(requiredGate)) {
        addIssue(rows, 'FAIL', scope, `${requiredGate} is required.`);
      }
    }

    const shape = candidate.scaffoldShape ?? {};
    if (!hasText(shape.titleKo)) addIssue(rows, 'FAIL', scope, 'scaffoldShape.titleKo is required.');
    if (!hasText(shape.canDoStatementKo)) {
      addIssue(rows, 'FAIL', scope, 'scaffoldShape.canDoStatementKo is required.');
    }
    if (!Array.isArray(shape.focusItems) || shape.focusItems.length === 0) {
      addIssue(rows, 'FAIL', scope, 'scaffoldShape.focusItems must contain at least one item.');
    }
    for (const [index, item] of (shape.focusItems ?? []).entries()) {
      const itemScope = `${scope} focusItems[${index}]`;
      if (!hasText(item?.text)) addIssue(rows, 'FAIL', itemScope, 'text is required.');
      if (!hasText(item?.reading)) addIssue(rows, 'FAIL', itemScope, 'reading is required.');
      if (!hasText(item?.meaningKo)) addIssue(rows, 'FAIL', itemScope, 'meaningKo is required.');
    }

    const script = shape.reading?.script;
    if (!Array.isArray(script) || script.length < 2) {
      addIssue(rows, 'FAIL', scope, 'scaffoldShape.reading.script must contain at least two lines.');
    } else {
      script.forEach((line, index) => {
        const lineScope = `${scope} script[${index}]`;
        if (!hasText(line?.speaker)) addIssue(rows, 'FAIL', lineScope, 'speaker is required.');
        if (!hasText(line?.voice_id)) addIssue(rows, 'FAIL', lineScope, 'voice_id is required.');
        if (!hasText(line?.text)) addIssue(rows, 'FAIL', lineScope, 'text is required.');
        if (!hasText(line?.translation)) addIssue(rows, 'FAIL', lineScope, 'translation is required.');
      });
    }

    const audioPolicy = shape.audioPolicy ?? {};
    if (!AUDIO_TARGET_TYPES.has(audioPolicy.audioTargetType)) {
      addIssue(rows, 'FAIL', scope, 'scaffoldShape.audioPolicy.audioTargetType is invalid.');
    }
    if (!GENERATION_STATUSES.has(audioPolicy.generationStatus)) {
      addIssue(rows, 'FAIL', scope, 'scaffoldShape.audioPolicy.generationStatus is invalid.');
    }
    for (const field of audioPolicy.ttsTargets ?? []) {
      if (!AUDIO_FIELDS.has(field)) {
        addIssue(rows, 'FAIL', scope, `Unknown scaffold tts target field: ${field}.`);
      }
    }

    walkStrings(candidate, (value, path) => {
      if (FORBIDDEN_DRAFT_TEXT.test(value)) {
        addIssue(rows, 'FAIL', scope, `Forbidden placeholder text at ${path}.`);
      }
    });
  }

  return { scaffoldIds, scaffoldTopicIds };
}

function validateTopicAnchorPolicies(
  data,
  rows,
  topicContext,
  exampleIds,
  lessonDraftContext,
  grammarOrders,
  grammarMetadataContext,
  coverageData,
  seedCandidateContext,
  scaffoldContext,
) {
  const policyIds = new Set();
  const policyTopicIds = new Set();
  const policyById = new Map();
  const policyByTopicId = new Map();
  const priorityByTopicId = new Map();
  for (const priority of coverageData?.priorities ?? []) {
    priorityByTopicId.set(priority.topicId, priority);
  }

  if (!data || !Array.isArray(data.policies)) {
    return { policyIds, policyTopicIds, policyById, policyByTopicId };
  }

  for (const policy of data.policies) {
    const scope = policy?.policyId ?? 'topic anchor policy ?';
    if (typeof policy?.policyId !== 'string' || !/^anchor-[a-z0-9][a-z0-9-]*$/.test(policy.policyId)) {
      addIssue(rows, 'FAIL', scope, 'policyId must match anchor-<slug>.');
      continue;
    }
    if (policyIds.has(policy.policyId)) {
      addIssue(rows, 'FAIL', scope, 'Duplicate anchor policyId.');
    }
    policyIds.add(policy.policyId);
    policyById.set(policy.policyId, policy);

    if (policy.status !== 'draft') {
      addIssue(rows, 'FAIL', scope, 'Topic anchor policies must remain draft before promotion.');
    }
    if (policyTopicIds.has(policy.topicId)) {
      addIssue(rows, 'FAIL', scope, 'Duplicate anchor policy for topicId.');
    }
    policyTopicIds.add(policy.topicId);
    policyByTopicId.set(policy.topicId, policy);

    if (!topicContext.topicIds.has(policy.topicId)) {
      addIssue(rows, 'FAIL', scope, 'topicId references an unknown topic.');
    }
    const priority = priorityByTopicId.get(policy.topicId);
    if (!priority) {
      addIssue(rows, 'FAIL', scope, 'Anchor policy topic must have a coverage priority.');
    } else {
      if (priority.recommendedWave !== policy.recommendedWave) {
        addIssue(rows, 'FAIL', scope, 'recommendedWave must match coverage-priorities.');
      }
      if (priority.priority !== policy.priority) {
        addIssue(rows, 'FAIL', scope, 'priority must match coverage-priorities.');
      }
    }

    if (!ANCHOR_ROUTES.has(policy.route)) {
      addIssue(rows, 'FAIL', scope, 'route is invalid.');
    }
    const lessonBlueprint = lessonDraftContext.lessonById.get(policy.targetLessonBlueprintId);
    if (!lessonBlueprint) {
      addIssue(rows, 'FAIL', scope, 'targetLessonBlueprintId references an unknown lesson draft blueprint.');
    } else if (!lessonBlueprint.topicIds.includes(policy.topicId)) {
      addIssue(rows, 'FAIL', scope, 'target lesson blueprint does not cover topicId.');
    }

    for (const exampleId of policy.exampleIds ?? []) {
      if (!exampleIds.has(exampleId)) {
        addIssue(rows, 'FAIL', scope, `exampleIds references unknown example ${exampleId}.`);
      }
      if (lessonBlueprint && !(lessonBlueprint.exampleIds ?? []).includes(exampleId)) {
        addIssue(rows, 'FAIL', scope, `example ${exampleId} is not linked by the lesson draft blueprint.`);
      }
    }

    const decision = policy.anchorDecision ?? {};
    if (!ANCHOR_MODES.has(decision.mode)) {
      addIssue(rows, 'FAIL', scope, 'anchorDecision.mode is invalid.');
    }
    if (policy.route === 'scaffold_candidate' && decision.mode !== 'scaffold') {
      addIssue(rows, 'FAIL', scope, 'scaffold_candidate route must use scaffold mode.');
    }
    if (policy.route === 'vocab_skill_candidate' && decision.mode !== 'vocabulary_skill') {
      addIssue(rows, 'FAIL', scope, 'vocab_skill_candidate route must use vocabulary_skill mode.');
    }
    if (policy.route === 'new_grammar_metadata_v2' && decision.mode !== 'new_n5_grammar') {
      addIssue(rows, 'FAIL', scope, 'new_grammar_metadata_v2 route must use new_n5_grammar mode.');
    }
    if (policy.route === 'split_grammar_metadata_v2' && decision.mode !== 'split_n5_n4_grammar') {
      addIssue(rows, 'FAIL', scope, 'split_grammar_metadata_v2 route must use split_n5_n4_grammar mode.');
    }

    if (decision.requiresScaffoldCandidate) {
      if (!decision.scaffoldCandidateId) {
        addIssue(rows, 'FAIL', scope, 'requiresScaffoldCandidate must include scaffoldCandidateId.');
      } else if (!scaffoldContext.scaffoldIds.has(decision.scaffoldCandidateId)) {
        addIssue(rows, 'FAIL', scope, `Unknown scaffoldCandidateId ${decision.scaffoldCandidateId}.`);
      }
      if (!scaffoldContext.scaffoldTopicIds.has(policy.topicId)) {
        addIssue(rows, 'FAIL', scope, 'scaffoldCandidateId must cover the policy topicId.');
      }
    } else if (decision.scaffoldCandidateId) {
      addIssue(rows, 'FAIL', scope, 'scaffoldCandidateId is only allowed when requiresScaffoldCandidate is true.');
    }

    for (const ref of decision.existingGrammarRefs ?? []) {
      if (!grammarOrders.get(ref.level)?.has(ref.order)) {
        addIssue(rows, 'FAIL', scope, `existing grammar ref ${ref.level}:${ref.order} does not exist.`);
      }
    }
    if (decision.requiresNewGrammarMetadata && (decision.proposedMetadataIds ?? []).length === 0) {
      addIssue(rows, 'FAIL', scope, 'requiresNewGrammarMetadata needs at least one proposedMetadataId.');
    }
    if (!decision.requiresNewGrammarMetadata && (decision.proposedMetadataIds ?? []).length > 0) {
      addIssue(rows, 'FAIL', scope, 'proposedMetadataIds require requiresNewGrammarMetadata.');
    }
    const missingMetadataIds = [];
    for (const metadataId of decision.proposedMetadataIds ?? []) {
      const metadata = grammarMetadataContext.metadataById.get(metadataId);
      if (!metadata) {
        missingMetadataIds.push(metadataId);
        addIssue(rows, 'FAIL', scope, `proposed metadata ${metadataId} does not exist in grammar-metadata-v2.`);
      } else if (metadata.topicId !== policy.topicId) {
        addIssue(rows, 'FAIL', scope, `proposed metadata ${metadataId} does not reference policy topicId.`);
      }
    }
    const metadataRequirementOpen = (policy.promotionReadiness?.requiredBeforeSeedCandidate ?? []).includes(
      'grammar_metadata_v2',
    );
    if (decision.requiresNewGrammarMetadata && missingMetadataIds.length === 0 && metadataRequirementOpen) {
      addIssue(rows, 'FAIL', scope, 'grammar_metadata_v2 requirement should be removed after metadata exists.');
    }
    if (decision.requiresNewGrammarMetadata && missingMetadataIds.length > 0 && !metadataRequirementOpen) {
      addIssue(rows, 'FAIL', scope, 'Missing grammar metadata must keep grammar_metadata_v2 requirement open.');
    }

    const readiness = policy.promotionReadiness ?? {};
    if (!PROMOTION_READINESS_STATES.has(readiness.state)) {
      addIssue(rows, 'FAIL', scope, 'promotionReadiness.state is invalid.');
    }
    for (const requirement of readiness.requiredBeforeSeedCandidate ?? []) {
      if (!PROMOTION_REQUIREMENTS.has(requirement)) {
        addIssue(rows, 'FAIL', scope, `Unknown promotion requirement: ${requirement}.`);
      }
    }
    if (
      policy.route !== 'scaffold_candidate' &&
      !['blocked', 'ready_for_candidate'].includes(readiness.state)
    ) {
      addIssue(rows, 'FAIL', scope, 'Non-scaffold anchor policies must be blocked or ready_for_candidate.');
    }
    if (
      policy.route !== 'scaffold_candidate' &&
      readiness.state === 'ready_for_candidate' &&
      metadataRequirementOpen
    ) {
      addIssue(rows, 'FAIL', scope, 'ready_for_candidate cannot keep grammar_metadata_v2 open.');
    }
    if (policy.route === 'scaffold_candidate' && readiness.state !== 'ready_for_review') {
      addIssue(rows, 'FAIL', scope, 'scaffold_candidate policies should be ready_for_review after scaffold candidate creation.');
    }
    const seedCandidate = seedCandidateContext.candidateByTopicId.get(policy.topicId);
    if (seedCandidate) {
      const openStructuralRequirements = (readiness.requiredBeforeSeedCandidate ?? []).filter((requirement) =>
        ['grammar_metadata_v2', 'contrast_question_policy', 'scaffold_shape_review'].includes(requirement),
      );
      if (openStructuralRequirements.length > 0) {
        addIssue(
          rows,
          'FAIL',
          scope,
          `Anchor policy cannot coexist with a seed candidate while structural requirements remain open: ${openStructuralRequirements.join(', ')}.`,
        );
      }
      if (seedCandidate.lessonBlueprintId !== policy.targetLessonBlueprintId) {
        addIssue(rows, 'FAIL', scope, 'Seed candidate and anchor policy must reference the same lesson blueprint.');
      }
      if (!(seedCandidate.sourceTopicIds ?? []).includes(policy.topicId)) {
        addIssue(rows, 'FAIL', scope, 'Seed candidate must include the anchor policy topicId.');
      }
      for (const exampleId of policy.exampleIds ?? []) {
        if (!(seedCandidate.exampleIds ?? []).includes(exampleId)) {
          addIssue(rows, 'FAIL', scope, `Seed candidate must retain anchor example ${exampleId}.`);
        }
      }
    }

    walkStrings(policy, (value, path) => {
      if (FORBIDDEN_DRAFT_TEXT.test(value)) {
        addIssue(rows, 'FAIL', scope, `Forbidden placeholder text at ${path}.`);
      }
    });
  }

  for (const [topicId, priority] of priorityByTopicId) {
    if (
      priority.recommendedWave === 'WAVE_1_N5_PATCH' &&
      priority.priority === 'P0' &&
      !seedCandidateContext.candidateTopicIds.has(topicId) &&
      !policyTopicIds.has(topicId)
    ) {
      addIssue(rows, 'FAIL', topicId, 'P0 Wave 1 topic without a seed candidate must have an anchor policy.');
    }
  }

  return { policyIds, policyTopicIds, policyById, policyByTopicId };
}

function isLevelOrderRef(value) {
  return (
    value !== null &&
    typeof value === 'object' &&
    LEVELS.includes(value.level) &&
    Number.isInteger(value.order) &&
    value.order > 0
  );
}

function validateContrastRef(
  ref,
  rows,
  scope,
  side,
  policy,
  policyMetadataIds,
  grammarMetadataContext,
  grammarOrders,
  vocabularyOrders,
) {
  if (!CONTRAST_REF_KINDS.has(ref?.kind)) {
    addIssue(rows, 'FAIL', scope, `${side}.kind is invalid.`);
    return null;
  }
  if (!hasText(ref.label)) {
    addIssue(rows, 'FAIL', scope, `${side}.label is required.`);
  }

  if (ref.kind === 'grammar_metadata') {
    if (typeof ref.ref !== 'string') {
      addIssue(rows, 'FAIL', scope, `${side}.ref must be a grammar metadata id.`);
      return null;
    }
    const metadata = grammarMetadataContext.metadataById.get(ref.ref);
    if (!metadata) {
      addIssue(rows, 'FAIL', scope, `${side}.ref references unknown grammar metadata ${ref.ref}.`);
      return null;
    }
    if (metadata.topicId !== policy.topicId) {
      addIssue(rows, 'FAIL', scope, `${side}.ref metadata must belong to the policy topic.`);
    }
    if (!policyMetadataIds.has(ref.ref)) {
      addIssue(rows, 'FAIL', scope, `${side}.ref metadata must be listed in metadataIds.`);
    }
    return { kind: ref.kind, id: ref.ref, metadata };
  }

  if (!isLevelOrderRef(ref.ref)) {
    addIssue(rows, 'FAIL', scope, `${side}.ref must contain a valid level/order pair.`);
    return null;
  }
  if (ref.kind === 'grammar_ref' && !grammarOrders.get(ref.ref.level)?.has(ref.ref.order)) {
    addIssue(rows, 'FAIL', scope, `${side}.ref grammar ${ref.ref.level}:${ref.ref.order} does not exist.`);
  }
  if (ref.kind === 'vocabulary_ref' && !vocabularyOrders.get(ref.ref.level)?.has(ref.ref.order)) {
    addIssue(rows, 'FAIL', scope, `${side}.ref vocabulary ${ref.ref.level}:${ref.ref.order} does not exist.`);
  }

  return { kind: ref.kind, id: `${ref.ref.level}:${ref.ref.order}` };
}

function validateContrastQuestionPolicies(
  data,
  rows,
  topicContext,
  exampleIds,
  grammarMetadataContext,
  grammarOrders,
  vocabularyOrders,
  anchorPolicyContext,
  seedCandidateContext,
) {
  const policyIds = new Set();
  const policyTopicIds = new Set();
  const policiesByTopicId = new Map();

  if (!data || !Array.isArray(data.policies)) return { policyIds, policyTopicIds, policiesByTopicId };

  for (const policy of data.policies) {
    const scope = policy?.policyId ?? 'contrast policy ?';
    if (typeof policy?.policyId !== 'string' || !/^contrast-[a-z0-9][a-z0-9-]*$/.test(policy.policyId)) {
      addIssue(rows, 'FAIL', scope, 'policyId must match contrast-<slug>.');
      continue;
    }
    if (policyIds.has(policy.policyId)) {
      addIssue(rows, 'FAIL', scope, 'Duplicate contrast policyId.');
    }
    policyIds.add(policy.policyId);

    if (policy.status !== 'draft') {
      addIssue(rows, 'FAIL', scope, 'Contrast question policies must remain draft before promotion.');
    }
    if (!topicContext.topicIds.has(policy.topicId)) {
      addIssue(rows, 'FAIL', scope, 'topicId references an unknown topic.');
    }
    if (policyTopicIds.has(policy.topicId)) {
      addIssue(rows, 'FAIL', scope, 'Duplicate contrast policy for topicId.');
    }
    policyTopicIds.add(policy.topicId);
    policiesByTopicId.set(policy.topicId, policy);

    const anchorPolicy = anchorPolicyContext.policyById.get(policy.anchorPolicyId);
    if (!anchorPolicy) {
      addIssue(rows, 'FAIL', scope, 'anchorPolicyId references an unknown anchor policy.');
    } else {
      if (anchorPolicy.topicId !== policy.topicId) {
        addIssue(rows, 'FAIL', scope, 'anchorPolicyId must reference the same topicId.');
      }
      if (!anchorPolicy.anchorDecision?.requiresContrastPolicy) {
        addIssue(rows, 'FAIL', scope, 'anchor policy must require contrast policy before a contrast record is attached.');
      }
    }

    if (!CONTRAST_ROUTES.has(policy.route)) {
      addIssue(rows, 'FAIL', scope, 'route is invalid.');
    }
    if (policy.route === 'vocab_skill_contrast' && anchorPolicy?.route !== 'vocab_skill_candidate') {
      addIssue(rows, 'FAIL', scope, 'vocab_skill_contrast must attach to a vocab_skill_candidate anchor.');
    }
    if (policy.route !== 'vocab_skill_contrast' && anchorPolicy?.route === 'vocab_skill_candidate') {
      addIssue(rows, 'FAIL', scope, 'vocab_skill_candidate anchors must use vocab_skill_contrast.');
    }

    for (const exampleId of policy.sourceExampleIds ?? []) {
      if (!exampleIds.has(exampleId)) {
        addIssue(rows, 'FAIL', scope, `sourceExampleIds references unknown example ${exampleId}.`);
      }
      if (anchorPolicy && !(anchorPolicy.exampleIds ?? []).includes(exampleId)) {
        addIssue(rows, 'FAIL', scope, `source example ${exampleId} is not linked by the anchor policy.`);
      }
    }

    const metadataIds = new Set(policy.metadataIds ?? []);
    for (const metadataId of metadataIds) {
      const metadata = grammarMetadataContext.metadataById.get(metadataId);
      if (!metadata) {
        addIssue(rows, 'FAIL', scope, `metadataIds references unknown metadata ${metadataId}.`);
      } else if (metadata.topicId !== policy.topicId) {
        addIssue(rows, 'FAIL', scope, `metadata ${metadataId} must belong to policy topicId.`);
      }
    }
    const proposedMetadataIds = new Set(anchorPolicy?.anchorDecision?.proposedMetadataIds ?? []);
    if (policy.route === 'vocab_skill_contrast' && metadataIds.size > 0) {
      addIssue(rows, 'FAIL', scope, 'vocab_skill_contrast must not include grammar metadataIds.');
    }
    if (policy.route !== 'vocab_skill_contrast' && metadataIds.size === 0) {
      addIssue(rows, 'FAIL', scope, 'grammar contrast policies must include metadataIds.');
    }
    if (policy.route !== 'vocab_skill_contrast' && !sameMultiset([...metadataIds], [...proposedMetadataIds])) {
      addIssue(rows, 'FAIL', scope, 'metadataIds must match anchorDecision.proposedMetadataIds.');
    }
    if (policy.route === 'grammar_split_contrast' && metadataIds.size < 2) {
      addIssue(rows, 'FAIL', scope, 'grammar_split_contrast must include at least two metadataIds.');
    }

    for (const questionType of policy.targetRuntimeQuestionTypes ?? []) {
      if (!CURRENT_LESSON_QUESTION_TYPES.has(questionType)) {
        addIssue(rows, 'FAIL', scope, `Unsupported runtime question type: ${questionType}.`);
      }
    }
    for (const questionType of policy.draftFutureQuestionTypes ?? []) {
      if (!FUTURE_QUESTION_TYPES.has(questionType)) {
        addIssue(rows, 'FAIL', scope, `Unknown future question type: ${questionType}.`);
      }
    }
    if (!(policy.draftFutureQuestionTypes ?? []).includes('USAGE_CONTRAST')) {
      addIssue(rows, 'FAIL', scope, 'contrast policies must reserve USAGE_CONTRAST as a future question type.');
    }

    const seedCandidate = seedCandidateContext.candidateByTopicId.get(policy.topicId);
    if (seedCandidate) {
      if (anchorPolicy && seedCandidate.lessonBlueprintId !== anchorPolicy.targetLessonBlueprintId) {
        addIssue(rows, 'FAIL', scope, 'Seed candidate must use the lesson blueprint selected by the anchor policy.');
      }
      for (const exampleId of policy.sourceExampleIds ?? []) {
        if (!(seedCandidate.exampleIds ?? []).includes(exampleId)) {
          addIssue(rows, 'FAIL', scope, `Seed candidate must include contrast example ${exampleId}.`);
        }
      }
      const candidateQuestionTypes = new Set(
        (seedCandidate.seedShape?.content_jsonb?.questions ?? []).map((question) => question.type),
      );
      for (const questionType of policy.targetRuntimeQuestionTypes ?? []) {
        if (!candidateQuestionTypes.has(questionType)) {
          addIssue(rows, 'FAIL', scope, `Seed candidate must include runtime question type ${questionType}.`);
        }
      }
      if (!(seedCandidate.validationGates ?? []).includes('ContrastGate')) {
        addIssue(rows, 'FAIL', scope, 'Seed candidate must keep ContrastGate for contrast policy coverage.');
      }
    }

    for (const [index, pair] of (policy.contrastPairs ?? []).entries()) {
      const pairScope = `${scope} pair ${index + 1}`;
      const left = validateContrastRef(
        pair.left,
        rows,
        pairScope,
        'left',
        policy,
        metadataIds,
        grammarMetadataContext,
        grammarOrders,
        vocabularyOrders,
      );
      const right = validateContrastRef(
        pair.right,
        rows,
        pairScope,
        'right',
        policy,
        metadataIds,
        grammarMetadataContext,
        grammarOrders,
        vocabularyOrders,
      );
      if (!hasText(pair.focusKo)) {
        addIssue(rows, 'FAIL', pairScope, 'focusKo is required.');
      }
      if (!hasText(pair.commonMistakeKo)) {
        addIssue(rows, 'FAIL', pairScope, 'commonMistakeKo is required.');
      }
      if (left?.kind === 'grammar_metadata' && right?.kind === 'grammar_metadata') {
        const leftContrasts = new Set(left.metadata.contrastMetadataIds ?? []);
        const rightContrasts = new Set(right.metadata.contrastMetadataIds ?? []);
        if (!leftContrasts.has(right.id) && !rightContrasts.has(left.id)) {
          addIssue(rows, 'FAIL', pairScope, 'grammar metadata pair must be linked by contrastMetadataIds.');
        }
      }
    }

    for (const text of policy.questionPolicy?.mustTest ?? []) {
      if (!hasText(text)) {
        addIssue(rows, 'FAIL', scope, 'questionPolicy.mustTest items must be non-empty strings.');
      }
    }
    for (const text of policy.questionPolicy?.avoidUntilRuntimeSupport ?? []) {
      if (!hasText(text)) {
        addIssue(rows, 'FAIL', scope, 'questionPolicy.avoidUntilRuntimeSupport items must be non-empty strings.');
      }
    }
    for (const field of policy.questionPolicy?.ttsTargets ?? []) {
      if (!AUDIO_FIELDS.has(field)) {
        addIssue(rows, 'FAIL', scope, `Unknown questionPolicy TTS field: ${field}.`);
      }
    }
    if (!GENERATION_STATUSES.has(policy.questionPolicy?.generationStatus)) {
      addIssue(rows, 'FAIL', scope, 'questionPolicy.generationStatus is invalid.');
    }

    const readiness = policy.promotionReadiness ?? {};
    if (!PROMOTION_READINESS_STATES.has(readiness.state)) {
      addIssue(rows, 'FAIL', scope, 'promotionReadiness.state is invalid.');
    }
    if (readiness.state !== 'ready_for_candidate') {
      addIssue(rows, 'FAIL', scope, 'contrast policy should be ready_for_candidate after the policy is defined.');
    }
    for (const requirement of readiness.requiredBeforeSeedCandidate ?? []) {
      if (!PROMOTION_REQUIREMENTS.has(requirement)) {
        addIssue(rows, 'FAIL', scope, `Unknown promotion requirement: ${requirement}.`);
      }
    }
    if (!(readiness.requiredBeforeSeedCandidate ?? []).includes('tts_readiness_review')) {
      addIssue(rows, 'FAIL', scope, 'contrast policies must keep tts_readiness_review before seed promotion.');
    }
    if (!(readiness.requiredBeforeSeedCandidate ?? []).includes('human_curriculum_review')) {
      addIssue(rows, 'FAIL', scope, 'contrast policies must keep human_curriculum_review before seed promotion.');
    }

    walkStrings(policy, (value, path) => {
      if (FORBIDDEN_DRAFT_TEXT.test(value)) {
        addIssue(rows, 'FAIL', scope, `Forbidden placeholder text at ${path}.`);
      }
    });
  }

  for (const [topicId, anchorPolicy] of anchorPolicyContext.policyByTopicId) {
    const requiresContrast = Boolean(anchorPolicy.anchorDecision?.requiresContrastPolicy);
    const contrastStillOpen = (anchorPolicy.promotionReadiness?.requiredBeforeSeedCandidate ?? []).includes(
      'contrast_question_policy',
    );
    if (requiresContrast && !policyTopicIds.has(topicId)) {
      addIssue(rows, 'FAIL', anchorPolicy.policyId, 'Anchor policy requires contrast_question_policy but no contrast policy exists.');
    }
    if (requiresContrast && policyTopicIds.has(topicId) && contrastStillOpen) {
      addIssue(rows, 'FAIL', anchorPolicy.policyId, 'contrast_question_policy requirement should be removed after contrast policy exists.');
    }
  }

  return { policyIds, policyTopicIds, policiesByTopicId };
}

function validateCoveragePriorities(data, rows, topicContext, lessonDraftContext) {
  const priorityIds = new Set();
  const prioritizedTopicIds = new Set();
  const nonCoveredTopicIds = new Set();
  for (const [topicId, topic] of topicContext.topicsById) {
    if (topic.coverageStatus !== 'covered') nonCoveredTopicIds.add(topicId);
  }

  if (!data || !Array.isArray(data.priorities)) return;

  for (const priority of data.priorities) {
    const scope = priority?.priorityId ?? 'priority ?';
    if (typeof priority?.priorityId !== 'string' || !/^priority-[a-z0-9][a-z0-9-]*$/.test(priority.priorityId)) {
      addIssue(rows, 'FAIL', scope, 'priorityId must match priority-<slug>.');
      continue;
    }
    if (priorityIds.has(priority.priorityId)) {
      addIssue(rows, 'FAIL', scope, 'Duplicate priorityId.');
    }
    priorityIds.add(priority.priorityId);
    if (!topicContext.topicIds.has(priority.topicId)) {
      addIssue(rows, 'FAIL', scope, 'Priority references an unknown topicId.');
    } else {
      prioritizedTopicIds.add(priority.topicId);
    }
    if (!TRACKS.has(priority.track)) {
      addIssue(rows, 'FAIL', scope, 'track is invalid.');
    }
    if (!PRIORITIES.has(priority.priority)) {
      addIssue(rows, 'FAIL', scope, 'priority is invalid.');
    }
    if (!RECOMMENDED_WAVES.has(priority.recommendedWave)) {
      addIssue(rows, 'FAIL', scope, 'recommendedWave is invalid.');
    }
    if (!COVERAGE_STATUSES.has(priority.coverageStatus)) {
      addIssue(rows, 'FAIL', scope, 'coverageStatus is invalid.');
    }
    const topic = topicContext.topicsById.get(priority.topicId);
    if (topic && topic.coverageStatus !== priority.coverageStatus) {
      addIssue(rows, 'FAIL', scope, 'coverageStatus must match the referenced topic.');
    }
    for (const blocker of priority.blockers ?? []) {
      if (!PRIORITY_BLOCKERS.has(blocker)) {
        addIssue(rows, 'FAIL', scope, `Unknown blocker: ${blocker}.`);
      }
    }
    if (!(priority.blockers ?? []).includes('needs_original_examples')) {
      addIssue(rows, 'FAIL', scope, 'needs_original_examples blocker is required.');
    }
    if (!Array.isArray(priority.targetLessonBlueprintIds) || priority.targetLessonBlueprintIds.length === 0) {
      addIssue(rows, 'FAIL', scope, 'targetLessonBlueprintIds must not be empty.');
    }
    for (const lessonBlueprintId of priority.targetLessonBlueprintIds ?? []) {
      const lesson = lessonDraftContext.lessonById.get(lessonBlueprintId);
      if (!lesson) {
        addIssue(rows, 'FAIL', scope, `Unknown target lesson blueprint ${lessonBlueprintId}.`);
      } else if (!lesson.topicIds.includes(priority.topicId)) {
        addIssue(rows, 'FAIL', scope, `Target lesson ${lessonBlueprintId} does not cover topicId.`);
      }
    }
  }

  for (const topicId of nonCoveredTopicIds) {
    if (!prioritizedTopicIds.has(topicId)) {
      addIssue(rows, 'FAIL', topicId, 'No coverage priority covers this non-covered topic.');
    }
  }
}

function printRows(rows) {
  const failCount = rows.filter((row) => row.level === 'FAIL').length;
  const warnCount = rows.filter((row) => row.level === 'WARN').length;

  console.log('Curriculum contract validation summary');
  console.log(`- warnings: ${warnCount}`);
  console.log(`- failures: ${failCount}`);

  if (rows.length > 0) {
    console.log('\nFindings');
    for (const row of rows) {
      console.log(`- ${row.level} | ${row.scope} | ${row.message}`);
    }
  }

  if (failCount > 0) process.exit(1);
  console.log('\nCurriculum contract validation passed.');
}

function main() {
  const rows = [];
  validateSchemas(rows);

  const grammarOrders = grammarOrdersByLevel();
  const vocabularyOrders = vocabularyOrdersByLevel();
  const data = new Map();
  for (const file of CONTRACT_FILES) {
    data.set(file.label, validateContractShell(file, rows));
  }

  const pdfRefs = validatePdfInventory(data.get('PDF topic inventory'), rows);
  const topicContext = validateTopics(data.get('Curriculum topics'), rows, grammarOrders, pdfRefs);
  validateTopicGrammarMap(data.get('Topic grammar map'), rows, grammarOrders, topicContext.topicIds);
  const vocabularyMapContext = validateTopicVocabularyMap(
    data.get('Topic vocabulary map'),
    rows,
    vocabularyOrders,
    topicContext.topicIds,
  );
  validatePdfTopicCoverage(pdfRefs, topicContext.topicPdfRefs, rows);
  const exampleIds = validateExamples(data.get('Example bank'), rows, topicContext.topicIds);
  validateQuestionBlueprints(data.get('Question blueprints'), rows, topicContext.topicIds);
  const grammarMetadataContext = validateGrammarMetadataV2(
    data.get('Grammar metadata v2'),
    rows,
    topicContext,
    exampleIds,
    grammarOrders,
  );
  const lessonDraftContext = validateLessonDraftBlueprints(
    data.get('Lesson draft blueprints'),
    rows,
    topicContext,
    exampleIds,
  );
  const seedCandidateContext = validateLessonSeedCandidates(
    data.get('Lesson seed candidates'),
    rows,
    topicContext,
    exampleIds,
    lessonDraftContext,
    grammarOrders,
    vocabularyOrders,
  );
  const ttsTargetContext = validateTtsTargetManifest(
    data.get('TTS target manifest'),
    rows,
    topicContext.topicsById,
    exampleIds,
    seedCandidateContext,
    vocabularyMapContext,
    vocabularyOrders,
  );
  validateTtsReviewBatches(data.get('TTS review batches'), rows, ttsTargetContext);
  const scaffoldContext = validateScaffoldCandidates(
    data.get('Scaffold candidates'),
    rows,
    topicContext,
    exampleIds,
    lessonDraftContext,
  );
  const anchorPolicyContext = validateTopicAnchorPolicies(
    data.get('Topic anchor policies'),
    rows,
    topicContext,
    exampleIds,
    lessonDraftContext,
    grammarOrders,
    grammarMetadataContext,
    data.get('Coverage priorities'),
    seedCandidateContext,
    scaffoldContext,
  );
  validateContrastQuestionPolicies(
    data.get('Contrast question policies'),
    rows,
    topicContext,
    exampleIds,
    grammarMetadataContext,
    grammarOrders,
    vocabularyOrders,
    anchorPolicyContext,
    seedCandidateContext,
  );
  validateCoveragePriorities(data.get('Coverage priorities'), rows, topicContext, lessonDraftContext);

  printRows(rows);
}

main();
