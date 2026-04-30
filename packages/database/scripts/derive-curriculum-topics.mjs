import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PACKAGE_DIR = join(SCRIPT_DIR, '..');
const REPO_ROOT = join(PACKAGE_DIR, '..', '..');
const CURRICULUM_DIR = join(PACKAGE_DIR, 'data', 'curriculum');
const GRAMMAR_DIR = join(PACKAGE_DIR, 'data', 'grammar');
const VOCABULARY_DIR = join(PACKAGE_DIR, 'data', 'vocabulary');
const API_CURRICULUM_DIR = join(REPO_ROOT, 'apps', 'api', 'app', 'data', 'curriculum');

const LEVELS = ['N5', 'N4', 'N3', 'N2', 'N1'];

const TOPIC_SLUGS = {
  '001': 'kana-hiragana',
  '006': 'personal-pronouns',
  '007': 'demonstratives',
  '008': 'desu-copula',
  '009': 'nominal-negative',
  '010': 'basic-particles',
  '011': 'greetings',
  '012': 'numbers-and-counters',
  '013': 'time-and-weekdays',
  '014': 'onegai-shimasu',
  '015': 'sentence-final-yo',
  '016': 'sentence-final-ne',
  '017': 'kanji-reading-basics',
  '018': 'i-adjectives',
  '019': 'i-adjective-nominalization',
  '020': 'na-attributive-linker',
  '021': 'na-adjectives',
  '022': 'kedo-contrast',
  '023': 'verb-groups',
  '024': 'polite-verb-forms',
  '025': 'aru-iru-existence',
  '026': 'polite-form-applications',
  '027': 'particle-de',
  '028': 'nagara',
  '029': 'sugiru',
  '030': 'yasui-nikui',
  '031': 'nasai',
  '032': 'tai-desire',
  '033': 'purpose-ni-iku',
  '034': 'shi-reason-listing',
  '035': 'no-functions',
  '036': 'verb-connection-forms',
  '037': 'te-kudasai',
  '038': 'te-miru',
  '039': 'te-oku',
  '040': 'te-shimau',
  '041': 'temo-ii',
  '042': 'tewa-ikenai',
  '043': 'te-iru-progress-state',
  '044': 'shiru-wakaru',
  '045': 'hoshii',
  '046': 'tsuzukeru-compound-verbs',
  '047': 'te-iku-te-kuru',
  '048': 'te-ageru',
  '049': 'te-kureru',
  '050': 'te-morau',
  '051': 'verb-past-forms',
  '052': 'tara-conditional',
  '053': 'ta-koto-ga-aru',
  '054': 'ta-bakari',
  '055': 'ta-hou-ga-ii',
  '056': 'tari-tari-suru',
  '057': 'deshou',
  '058': 'ku-naru-ni-naru',
  '059': 'sentence-final-wa',
  '060': 'nai-form',
  '061': 'naide-kudasai',
  '062': 'prohibitive-na',
  '063': 'nakereba-naranai',
  '064': 'kamoshirenai',
  '065': 'shika-nai',
  '066': 'dake',
  '067': 'kara',
  '068': 'node',
  '069': 'potential-form',
  '070': 'adjective-sa',
  '071': 'sentence-final-zo',
  '072': 'imperative-form',
  '073': 'volitional-form',
  '074': 'sentence-final-ze',
  '075': 'to-omou',
  '076': 'kana-particle',
  '077': 'ni-suru',
  '078': 'noni',
  '079': 'noda-ndesu',
  '080': 'passive-form',
  '081': 'causative-form',
  '082': 'causative-passive-form',
  '083': 'tameni',
  '084': 'to-conditional',
  '085': 'toiu',
  '086': 'toiu-mono-wa',
  '087': 'to-quotation-or-condition',
  '088': 'ba-conditional',
  '089': 'nara-conditional',
  '090': 'tsumori',
  '091': 'souda-hearsay-appearance-a',
  '092': 'souda-hearsay-appearance-b',
  '093': 'youda',
  '094': 'rashii',
  '095': 'kitto',
  '096': 'bakari',
  '097': 'casual-contractions',
  '098': 'toiu-ka',
  '099': 'mono-functions',
  '100': 'hazu-da',
  '101': 'honorific-prefix-o-go',
  '102': 'keigo-sonkeigo-kenjougo',
};

const TOPIC_TYPE_OVERRIDES = {
  '001': 'kana',
  '006': 'vocabulary',
  '011': 'conversation',
  '012': 'vocabulary',
  '013': 'vocabulary',
  '014': 'conversation',
  '015': 'conversation',
  '016': 'conversation',
  '017': 'kanji',
  '044': 'vocabulary',
  '059': 'conversation',
  '071': 'register',
  '072': 'register',
  '074': 'register',
  '076': 'conversation',
  '095': 'vocabulary',
  '097': 'register',
  '098': 'conversation',
  '101': 'register',
  '102': 'register',
};

const GRAMMAR_MAPPINGS = {
  '007': [
    ['N5', 35, 'partial'],
    ['N5', 36, 'partial'],
    ['N5', 40, 'partial'],
    ['N5', 41, 'partial'],
  ],
  '008': [['N5', 1, 'exact']],
  '010': [
    ['N5', 31, 'partial'],
    ['N5', 32, 'partial'],
    ['N5', 33, 'partial'],
    ['N5', 37, 'partial'],
    ['N5', 42, 'partial'],
    ['N5', 43, 'partial'],
    ['N5', 44, 'partial'],
    ['N5', 46, 'partial'],
  ],
  '015': [['N5', 34, 'partial']],
  '016': [['N5', 34, 'partial']],
  '018': [['N5', 38, 'exact']],
  '020': [['N5', 39, 'partial']],
  '021': [['N5', 38, 'exact']],
  '022': [['N5', 18, 'exact']],
  '023': [
    ['N5', 45, 'partial'],
    ['N5', 47, 'partial'],
    ['N5', 49, 'related'],
  ],
  '024': [
    ['N5', 2, 'exact'],
    ['N5', 3, 'related'],
    ['N5', 4, 'related'],
    ['N5', 5, 'related'],
  ],
  '026': [
    ['N5', 11, 'related'],
    ['N5', 12, 'related'],
  ],
  '027': [['N5', 43, 'exact']],
  '028': [
    ['N5', 14, 'exact'],
    ['N4', 34, 'related'],
  ],
  '029': [
    ['N5', 24, 'exact'],
    ['N4', 36, 'related'],
  ],
  '030': [
    ['N5', 26, 'exact'],
    ['N4', 37, 'related'],
  ],
  '032': [['N5', 10, 'exact']],
  '033': [['N5', 12, 'exact']],
  '034': [
    ['N4', 24, 'exact'],
    ['N3', 23, 'related'],
  ],
  '035': [
    ['N5', 28, 'partial'],
    ['N5', 37, 'partial'],
  ],
  '036': [
    ['N5', 49, 'partial'],
    ['N5', 50, 'partial'],
    ['N4', 25, 'related'],
  ],
  '037': [['N5', 6, 'exact']],
  '038': [['N4', 4, 'exact']],
  '039': [['N4', 3, 'exact']],
  '040': [
    ['N4', 1, 'exact'],
    ['N3', 25, 'related'],
  ],
  '041': [
    ['N5', 8, 'exact'],
    ['N4', 20, 'related'],
  ],
  '042': [['N5', 9, 'exact']],
  '043': [
    ['N5', 20, 'partial'],
    ['N4', 5, 'partial'],
  ],
  '045': [['N4', 39, 'partial']],
  '046': [['N4', 35, 'exact']],
  '047': [
    ['N3', 28, 'partial'],
    ['N3', 29, 'partial'],
  ],
  '048': [['N4', 31, 'exact']],
  '049': [['N4', 30, 'exact']],
  '050': [['N4', 29, 'exact']],
  '051': [
    ['N5', 4, 'partial'],
    ['N5', 5, 'partial'],
    ['N5', 49, 'partial'],
  ],
  '052': [
    ['N4', 21, 'exact'],
    ['N3', 21, 'related'],
  ],
  '053': [['N5', 21, 'exact']],
  '054': [
    ['N3', 9, 'exact'],
    ['N4', 32, 'related'],
  ],
  '056': [['N4', 6, 'exact']],
  '057': [['N5', 23, 'exact']],
  '060': [['N5', 48, 'exact']],
  '061': [['N5', 7, 'exact']],
  '063': [['N5', 27, 'exact']],
  '067': [['N5', 17, 'partial']],
  '068': [['N3', 1, 'exact']],
  '075': [['N5', 19, 'exact']],
  '077': [['N4', 10, 'related']],
  '078': [
    ['N4', 19, 'exact'],
    ['N3', 2, 'related'],
  ],
  '080': [
    ['N4', 26, 'exact'],
    ['N3', 30, 'related'],
  ],
  '081': [
    ['N4', 27, 'exact'],
    ['N3', 31, 'related'],
  ],
  '082': [['N4', 28, 'exact']],
  '083': [
    ['N4', 17, 'partial'],
    ['N3', 15, 'related'],
  ],
  '084': [['N4', 40, 'partial']],
  '087': [
    ['N4', 40, 'partial'],
    ['N5', 19, 'related'],
  ],
  '088': [
    ['N4', 22, 'exact'],
    ['N3', 20, 'related'],
  ],
  '089': [
    ['N4', 23, 'exact'],
    ['N3', 22, 'related'],
  ],
  '090': [
    ['N5', 22, 'related'],
    ['N4', 12, 'exact'],
  ],
  '091': [
    ['N4', 14, 'partial'],
    ['N3', 13, 'partial'],
    ['N3', 14, 'partial'],
  ],
  '092': [
    ['N4', 14, 'partial'],
    ['N3', 13, 'partial'],
    ['N3', 14, 'partial'],
  ],
  '093': [['N3', 33, 'exact']],
  '094': [
    ['N4', 15, 'exact'],
    ['N3', 12, 'related'],
  ],
  '096': [['N4', 32, 'exact']],
  '100': [
    ['N4', 13, 'exact'],
    ['N3', 11, 'related'],
  ],
};

const VOCABULARY_MAPPINGS = {
  '006': [
    ['N5', 605, 'partial'],
    ['N5', 211, 'partial'],
  ],
  '012': [
    ['N5', 228, 'partial'],
    ['N5', 486, 'partial'],
    ['N5', 374, 'partial'],
    ['N5', 409, 'partial'],
    ['N5', 410, 'partial'],
  ],
  '013': [
    ['N5', 15, 'partial'],
    ['N5', 16, 'partial'],
    ['N5', 17, 'partial'],
    ['N5', 18, 'partial'],
    ['N5', 23, 'partial'],
    ['N5', 24, 'partial'],
    ['N5', 301, 'partial'],
    ['N5', 325, 'partial'],
    ['N5', 335, 'partial'],
    ['N5', 395, 'partial'],
    ['N5', 470, 'partial'],
    ['N5', 490, 'partial'],
    ['N5', 572, 'partial'],
  ],
  '017': [['N5', 309, 'exact']],
  '044': [
    ['N5', 393, 'partial'],
    ['N5', 122, 'partial'],
  ],
  '095': [['N5', 189, 'related']],
};

const CURRENT_LESSON_QUESTION_TYPES = ['VOCAB_MCQ', 'CONTEXT_CLOZE', 'SENTENCE_REORDER'];
const GENERATION_STATUSES = ['missing', 'generated', 'approved', 'rejected', 'stale'];

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, 'utf8'));
}

function readOptionalJson(filePath, fallback) {
  if (!existsSync(filePath)) return fallback;
  return readJson(filePath);
}

function writeJson(filePath, data) {
  mkdirSync(dirname(filePath), { recursive: true });
  writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`);
}

function topicIdFor(pdfRef) {
  const slug = TOPIC_SLUGS[pdfRef];
  if (!slug) throw new Error(`Missing topic slug override for pdf ${pdfRef}.`);
  return `topic-${slug}`;
}

function coverageStatusFor(action) {
  if (action === 'map_existing') return 'covered';
  if (action === 'split_topic') return 'partial';
  if (action === 'defer') return 'deferred';
  return 'missing';
}

function topicTypeFor(item) {
  return TOPIC_TYPE_OVERRIDES[item.pdfRef] ?? 'grammar';
}

function audioPolicyFor(topicType) {
  if (topicType === 'kana') {
    return {
      ttsTargets: ['japanese', 'reading'],
      defaultSpeed: 0.85,
      requiredBeforePublish: true,
      audioTargetType: 'kana',
    };
  }
  if (topicType === 'vocabulary' || topicType === 'kanji') {
    return {
      ttsTargets: ['word', 'reading', 'example_sentence'],
      defaultSpeed: 0.9,
      requiredBeforePublish: true,
      audioTargetType: 'vocabulary',
    };
  }
  if (topicType === 'conversation' || topicType === 'register') {
    return {
      ttsTargets: ['japanese', 'example_sentence', 'script_line'],
      defaultSpeed: 0.9,
      requiredBeforePublish: true,
      audioTargetType: 'example_sentence',
    };
  }
  return {
    ttsTargets: ['pattern', 'example_sentence', 'question_prompt'],
    defaultSpeed: 0.9,
    requiredBeforePublish: false,
    audioTargetType: 'grammar',
  };
}

function grammarOrderIndex() {
  const byLevel = new Map();
  for (const level of LEVELS) {
    const rows = readJson(join(GRAMMAR_DIR, `${level.toLowerCase()}-grammar.json`));
    byLevel.set(level, new Set(rows.map((row) => row.order)));
  }
  return byLevel;
}

function vocabularyOrderIndex() {
  const byLevel = new Map();
  for (const level of LEVELS) {
    const rows = readJson(join(VOCABULARY_DIR, `${level.toLowerCase()}-words.json`));
    byLevel.set(level, new Map(rows.map((row) => [row.order, row])));
  }
  return byLevel;
}

function grammarMappingsFor(item, orderIndex) {
  return (GRAMMAR_MAPPINGS[item.pdfRef] ?? []).map(([level, order, matchType]) => {
    if (!orderIndex.get(level)?.has(order)) {
      throw new Error(`Invalid grammar mapping for pdf ${item.pdfRef}: ${level} order ${order}.`);
    }
    return {
      level,
      order,
      matchType,
      notesKo: `PDF ${item.pdfRef} ${item.titleKo} coverage anchor`,
    };
  });
}

function vocabularyMappingsFor(item, orderIndex) {
  return (VOCABULARY_MAPPINGS[item.pdfRef] ?? []).map(([level, order, matchType]) => {
    const row = orderIndex.get(level)?.get(order);
    if (!row) {
      throw new Error(`Invalid vocabulary mapping for pdf ${item.pdfRef}: ${level} order ${order}.`);
    }
    return {
      level,
      order,
      word: row.word,
      reading: row.reading,
      meaningKo: row.meaningKo,
      matchType,
      notesKo: `PDF ${item.pdfRef} ${item.titleKo} vocabulary coverage anchor`,
    };
  });
}

function buildTopic(item, orderIndex) {
  const topicType = topicTypeFor(item);
  const mappedGrammarOrders = grammarMappingsFor(item, orderIndex).map(({ level, order }) => ({
    level,
    order,
  }));

  return {
    topicId: topicIdFor(item.pdfRef),
    titleKo: item.titleKo,
    canonicalPattern: item.topicCandidates[0],
    topicType,
    inferredJlptLevel: item.inferredLevels[0],
    levelConfidence: item.levelConfidence,
    coverageStatus: coverageStatusFor(item.coverageAction),
    sourceRefs: [{ type: 'pdf', ref: item.pdfRef }],
    mappedGrammarOrders,
    mappedLessonIds: [],
    prerequisiteTopicIds: [],
    contrastTopicIds: [],
    audioPolicy: audioPolicyFor(topicType),
    reviewStatus: 'needs_review',
    notesKo: item.notesKo,
  };
}

function buildGrammarMap(items, orderIndex) {
  const mappings = [];
  for (const item of items) {
    for (const mapping of grammarMappingsFor(item, orderIndex)) {
      mappings.push({
        topicId: topicIdFor(item.pdfRef),
        grammarLevel: mapping.level,
        grammarOrder: mapping.order,
        matchType: mapping.matchType,
        notesKo: mapping.notesKo,
      });
    }
  }
  return mappings;
}

function buildVocabularyMap(items, orderIndex) {
  const mappings = [];
  for (const item of items) {
    for (const mapping of vocabularyMappingsFor(item, orderIndex)) {
      mappings.push({
        topicId: topicIdFor(item.pdfRef),
        vocabularyLevel: mapping.level,
        vocabularyOrder: mapping.order,
        word: mapping.word,
        reading: mapping.reading,
        meaningKo: mapping.meaningKo,
        matchType: mapping.matchType,
        notesKo: mapping.notesKo,
      });
    }
  }
  return mappings;
}

function questionBlueprintFor(topic) {
  const common = {
    blueprintId: `qb-${topic.topicId.replace(/^topic-/, '')}`,
    topicId: topic.topicId,
    recommendedQuestionTypes: CURRENT_LESSON_QUESTION_TYPES,
    cognitiveLevels: ['recognition', 'application', 'production'],
    minDraftQuestions: topic.topicType === 'grammar' ? 5 : 3,
    audioRequired: Boolean(topic.audioPolicy?.requiredBeforePublish),
    requiresOriginalExample: true,
    reviewStatus: 'needs_review',
  };

  if (topic.topicType === 'kana') {
    return {
      ...common,
      recommendedQuestionTypes: ['VOCAB_MCQ', 'CONTEXT_CLOZE'],
      draftFutureQuestionTypes: ['KANA_READING', 'LISTENING_MCQ'],
      cognitiveLevels: ['recognition', 'application', 'listening'],
      notesKo: 'Kana 전용 문항 UI가 생기기 전까지는 기존 MCQ/CLOZE 호환 문항만 publish한다.',
    };
  }
  if (topic.topicType === 'vocabulary' || topic.topicType === 'kanji') {
    return {
      ...common,
      recommendedQuestionTypes: ['VOCAB_MCQ', 'CONTEXT_CLOZE'],
      draftFutureQuestionTypes: ['LISTENING_MCQ'],
      cognitiveLevels: ['recognition', 'application', 'listening'],
      notesKo: '어휘/읽기 topic은 기존 lesson runtime 호환 문항을 먼저 만들고 듣기는 draft로 둔다.',
    };
  }
  if (topic.topicType === 'conversation' || topic.topicType === 'register') {
    return {
      ...common,
      recommendedQuestionTypes: ['VOCAB_MCQ', 'CONTEXT_CLOZE'],
      draftFutureQuestionTypes: ['LISTENING_MCQ', 'REGISTER_CHOICE'],
      cognitiveLevels: ['recognition', 'application', 'contrast', 'listening'],
      notesKo: '회화/register topic은 맥락 선택과 듣기 문항이 필요하지만 현재 runtime에는 draft로만 둔다.',
    };
  }
  if (topic.coverageStatus === 'partial') {
    return {
      ...common,
      draftFutureQuestionTypes: ['USAGE_CONTRAST'],
      cognitiveLevels: ['recognition', 'application', 'production', 'contrast'],
      notesKo: '분리/대조가 필요한 topic이므로 유사 문법 비교 문항을 draft 후보로 둔다.',
    };
  }

  return {
    ...common,
    draftFutureQuestionTypes: [],
    notesKo: '기존 lesson runtime 호환 문항 3종을 우선 생성한다.',
  };
}

function buildQuestionBlueprints(topics) {
  return topics.map((topic) => questionBlueprintFor(topic));
}

function targetIdPart(value) {
  return value.replace(/^topic-/, '').replace(/^ex-/, '').replace(/_/g, '-');
}

function exactVocabularyMappingByTopicId(vocabularyMappings) {
  const byTopicId = new Map();
  for (const mapping of vocabularyMappings) {
    if (!byTopicId.has(mapping.topicId)) byTopicId.set(mapping.topicId, []);
    byTopicId.get(mapping.topicId).push(mapping);
  }

  const exactByTopicId = new Map();
  for (const [topicId, mappings] of byTopicId) {
    const exactMappings = mappings.filter((mapping) => mapping.matchType === 'exact');
    if (mappings.length === 1 && exactMappings.length === 1) {
      exactByTopicId.set(topicId, exactMappings[0]);
    }
  }
  return exactByTopicId;
}

function buildTopicTtsTargets(topics, vocabularyMappings) {
  const targets = [];
  const exactVocabularyByTopicId = exactVocabularyMappingByTopicId(vocabularyMappings);

  for (const topic of topics) {
    const policy = topic.audioPolicy;
    if (!policy) continue;
    const exactVocabulary = exactVocabularyByTopicId.get(topic.topicId);

    for (const field of policy.ttsTargets ?? []) {
      if (policy.audioTargetType === 'vocabulary' && exactVocabulary) {
        targets.push({
          targetId: `tts-vocabulary-${exactVocabulary.vocabularyLevel.toLowerCase()}-${exactVocabulary.vocabularyOrder}-${field.replace(/_/g, '-')}`,
          topicId: topic.topicId,
          audioTargetType: policy.audioTargetType,
          audioField: field,
          textSource: `vocabulary:${exactVocabulary.vocabularyLevel}:${exactVocabulary.vocabularyOrder}:${field}`,
          defaultSpeed: policy.defaultSpeed,
          requiredBeforePublish: policy.requiredBeforePublish,
          preferredVoiceId: policy.preferredVoiceId,
          generationStatus: 'missing',
          cacheKeyStrategy: 'provider-model-speed-field-text-hash-v1',
          notesKo: 'Exact topic vocabulary mapping target; ready for DB lookup preview before TTS generation.',
        });
        continue;
      }

      targets.push({
        targetId: `tts-${targetIdPart(topic.topicId)}-${field.replace(/_/g, '-')}`,
        topicId: topic.topicId,
        audioTargetType: policy.audioTargetType,
        audioField: field,
        textSource: `curriculum-topics:${topic.topicId}:${field}`,
        defaultSpeed: policy.defaultSpeed,
        requiredBeforePublish: policy.requiredBeforePublish,
        preferredVoiceId: policy.preferredVoiceId,
        generationStatus: 'missing',
        cacheKeyStrategy: 'provider-model-speed-field-text-hash-v1',
        notesKo: 'Curriculum manifest target only; not yet persisted to tts_audio.',
      });
    }
  }
  return targets;
}

function buildExampleTtsTargets(examples) {
  const targets = [];
  for (const example of examples) {
    if (!example.audio) continue;
    targets.push({
      targetId: `tts-${targetIdPart(example.exampleId)}-${example.audio.audioField.replace(/_/g, '-')}`,
      topicId: example.topicId,
      audioTargetType: example.audio.audioTargetType,
      audioField: example.audio.audioField,
      textSource: `example-bank:${example.exampleId}:japanese`,
      defaultSpeed: 0.9,
      requiredBeforePublish: true,
      preferredVoiceId: example.audio.preferredVoiceId,
      generationStatus: example.audio.generationStatus,
      cacheKeyStrategy: 'provider-model-speed-field-text-hash-v1',
      notesKo: 'Example bank manifest target only; not yet persisted to tts_audio.',
    });
  }
  return targets;
}

function buildSeedCandidateTtsTargets(seedCandidates) {
  const targets = [];
  for (const candidate of seedCandidates?.candidates ?? []) {
    if (!(candidate.validationGates ?? []).includes('AudioReadinessGate')) continue;
    const targetIdPrefix = targetIdPart(candidate.candidateId);
    const topicId = candidate.sourceTopicIds?.[0];
    const script = candidate.seedShape?.content_jsonb?.reading?.script ?? [];
    script.forEach((line, index) => {
      const order = index + 1;
      targets.push({
        targetId: `tts-${targetIdPrefix}-script-${order}`,
        topicId,
        audioTargetType: 'lesson_script',
        audioField: 'script_line',
        textSource: `lesson-seed-candidates:${candidate.candidateId}:script:${order}`,
        defaultSpeed: 0.9,
        requiredBeforePublish: true,
        preferredVoiceId: line.voice_id,
        generationStatus: 'missing',
        cacheKeyStrategy: 'provider-model-speed-field-text-hash-v1',
        notesKo: 'Lesson seed candidate script target only; not yet persisted to tts_audio.',
      });
    });

    const questions = candidate.seedShape?.content_jsonb?.questions ?? [];
    for (const question of questions) {
      targets.push({
        targetId: `tts-${targetIdPrefix}-question-${question.order}`,
        topicId,
        audioTargetType: 'question_prompt',
        audioField: 'question_prompt',
        textSource: `lesson-seed-candidates:${candidate.candidateId}:question:${question.order}`,
        defaultSpeed: 0.9,
        requiredBeforePublish: true,
        generationStatus: 'missing',
        cacheKeyStrategy: 'provider-model-speed-field-text-hash-v1',
        notesKo: 'Lesson seed candidate question prompt target only; not yet persisted to tts_audio.',
      });
    }
  }
  return targets;
}

function buildTtsTargetManifest(topics, examples, seedCandidates, vocabularyMappings) {
  return [
    ...buildTopicTtsTargets(topics, vocabularyMappings),
    ...buildExampleTtsTargets(examples),
    ...buildSeedCandidateTtsTargets(seedCandidates),
  ];
}

function generationStatusSummary(targets) {
  const summary = Object.fromEntries(GENERATION_STATUSES.map((status) => [status, 0]));
  for (const target of targets) {
    summary[target.generationStatus] = (summary[target.generationStatus] ?? 0) + 1;
  }
  return summary;
}

function buildTtsReviewBatch(config, allTargets) {
  const targets = allTargets.filter(config.matches);
  return {
    batchId: config.batchId,
    status: 'draft',
    reviewSurface: config.reviewSurface,
    sourceKind: config.sourceKind,
    targetIds: targets.map((target) => target.targetId),
    targetCount: targets.length,
    requiredBeforePublishCount: targets.filter((target) => target.requiredBeforePublish).length,
    generationStatusSummary: generationStatusSummary(targets),
    adminExport: config.adminExport,
    reviewerChecklist: config.reviewerChecklist,
    notesKo: config.notesKo,
  };
}

function buildTtsReviewBatches(ttsTargets) {
  const batches = [
    {
      batchId: 'tts-review-admin-vocabulary-fields',
      reviewSurface: 'admin_existing_tts',
      sourceKind: 'topic_vocabulary_fields',
      matches: (target) => target.audioTargetType === 'vocabulary',
      adminExport: {
        mode: 'existing_admin_tts_fields',
        contentType: 'vocabulary',
        fieldMappings: [
          { audioField: 'reading', adminField: 'reading' },
          { audioField: 'word', adminField: 'word' },
          { audioField: 'example_sentence', adminField: 'example_sentence' },
        ],
        blockers: [],
      },
      reviewerChecklist: [
        'Admin vocabulary detail에서 reading, word, example_sentence 필드가 생성/재생 가능한지 확인한다.',
        '생성 후 generationStatus는 approved 전까지 missing/generated로만 유지한다.',
      ],
      notesKo: '현재 admin vocabulary TTS 필드와 1:1로 매핑되는 target 묶음이다.',
    },
    {
      batchId: 'tts-review-admin-grammar-fields',
      reviewSurface: 'admin_existing_tts',
      sourceKind: 'topic_grammar_fields',
      matches: (target) =>
        target.audioTargetType === 'grammar' &&
        ['pattern', 'example_sentence'].includes(target.audioField),
      adminExport: {
        mode: 'existing_admin_tts_fields',
        contentType: 'grammar',
        fieldMappings: [
          { audioField: 'pattern', adminField: 'pattern' },
          { audioField: 'example_sentence', adminField: 'example_sentences' },
        ],
        blockers: [],
      },
      reviewerChecklist: [
        'Admin grammar detail에서 pattern과 example_sentences 필드 매핑을 확인한다.',
        'example_sentence target은 admin API의 example_sentences 필드로 export한다.',
      ],
      notesKo: '현재 admin grammar TTS 필드로 처리 가능한 grammar target 묶음이다.',
    },
    {
      batchId: 'tts-review-gap-grammar-question-prompts',
      reviewSurface: 'admin_extension_required',
      sourceKind: 'topic_grammar_question_prompts',
      matches: (target) => target.audioTargetType === 'grammar' && target.audioField === 'question_prompt',
      adminExport: {
        mode: 'requires_admin_extension',
        contentType: 'grammar',
        fieldMappings: [{ audioField: 'question_prompt', adminField: 'question_prompt' }],
        blockers: ['admin_tts_field_gap'],
      },
      reviewerChecklist: [
        'question_prompt는 현재 admin grammar TTS 필드에 없으므로 UI/API 확장 전에는 생성하지 않는다.',
        '승격 전 prompt 오디오가 실제로 필요한지 lesson UX에서 재확인한다.',
      ],
      notesKo: '문법 prompt 오디오는 현재 admin TTS 필드에 없는 확장 후보이다.',
    },
    {
      batchId: 'tts-review-gap-kana-fields',
      reviewSurface: 'admin_extension_required',
      sourceKind: 'topic_kana_fields',
      matches: (target) => target.audioTargetType === 'kana',
      adminExport: {
        mode: 'requires_admin_extension',
        contentType: 'kana',
        fieldMappings: [
          { audioField: 'japanese', adminField: 'japanese' },
          { audioField: 'reading', adminField: 'reading' },
        ],
        blockers: ['admin_content_type_gap'],
      },
      reviewerChecklist: [
        'Kana target은 현재 admin content type에 없으므로 kana review surface가 생긴 뒤 생성한다.',
        'reading 필드는 기존 kana TTS API와 중복되지 않는지 확인한다.',
      ],
      notesKo: 'Kana scaffold target은 admin content type 확장이 필요한 묶음이다.',
    },
    {
      batchId: 'tts-review-gap-example-sentence-fields',
      reviewSurface: 'admin_extension_required',
      sourceKind: 'example_sentence_fields',
      matches: (target) => target.audioTargetType === 'example_sentence',
      adminExport: {
        mode: 'requires_admin_extension',
        contentType: 'example_sentence_pool',
        fieldMappings: [
          { audioField: 'example_sentence', adminField: 'example_sentence' },
          { audioField: 'japanese', adminField: 'japanese' },
          { audioField: 'script_line', adminField: 'script_line' },
        ],
        blockers: ['admin_content_type_gap'],
      },
      reviewerChecklist: [
        'Example sentence 계열 target은 아직 단일 admin content type이 아니므로 seed promotion 또는 별도 review surface를 먼저 정한다.',
        'PDF 원문 예문이 섞이지 않았는지 originality review와 함께 확인한다.',
      ],
      notesKo: 'ExampleBank와 conversation/register 예문 오디오는 promotion 전 별도 admin review surface가 필요하다.',
    },
    {
      batchId: 'tts-review-gap-seed-script-lines',
      reviewSurface: 'admin_extension_required',
      sourceKind: 'seed_candidate_script_lines',
      matches: (target) => target.audioTargetType === 'lesson_script',
      adminExport: {
        mode: 'requires_admin_extension',
        contentType: 'lesson_seed_candidate',
        fieldMappings: [{ audioField: 'script_line', adminField: 'script_line' }],
        blockers: ['lesson_seed_admin_surface_gap'],
      },
      reviewerChecklist: [
        'Seed candidate script line은 voice_id와 speaker가 함께 검수되어야 한다.',
        '공식 lesson JSON 승격 전 script line별 TTS 생성/재생 UI가 있는지 확인한다.',
      ],
      notesKo: 'Lesson seed reading script line 오디오는 seed candidate review surface가 필요한 묶음이다.',
    },
    {
      batchId: 'tts-review-gap-seed-question-prompts',
      reviewSurface: 'admin_extension_required',
      sourceKind: 'seed_candidate_question_prompts',
      matches: (target) => target.audioTargetType === 'question_prompt',
      adminExport: {
        mode: 'requires_admin_extension',
        contentType: 'lesson_seed_candidate',
        fieldMappings: [{ audioField: 'question_prompt', adminField: 'question_prompt' }],
        blockers: ['lesson_seed_admin_surface_gap'],
      },
      reviewerChecklist: [
        'Question prompt TTS가 실제 학습 UX에서 재생되는지 확인한 뒤 생성 우선순위를 정한다.',
        '문항 prompt는 정답/해설 오디오와 구분해 관리한다.',
      ],
      notesKo: 'Seed candidate question prompt 오디오는 lesson seed review surface가 필요한 묶음이다.',
    },
  ].map((config) => buildTtsReviewBatch(config, ttsTargets));

  const coveredTargetIds = new Set(batches.flatMap((batch) => batch.targetIds));
  if (coveredTargetIds.size !== ttsTargets.length) {
    throw new Error(`TTS review batches cover ${coveredTargetIds.size}/${ttsTargets.length} targets.`);
  }
  return batches;
}

function trackForTopic(topic) {
  if (topic.topicId.includes('honorific') || topic.topicId.includes('keigo')) {
    return 'BUSINESS_KEIGO';
  }
  if (topic.topicType === 'register' || topic.inferredJlptLevel === 'CONVERSATION') {
    return 'CONVERSATION_REGISTER';
  }
  if (topic.inferredJlptLevel === 'ABSOLUTE_ZERO') {
    return 'ABSOLUTE_ZERO_FOUNDATION';
  }
  if (topic.inferredJlptLevel === 'N5') {
    return 'N5_REINFORCEMENT';
  }
  if (topic.inferredJlptLevel === 'N4') {
    return 'N4_FOUNDATION';
  }
  return 'N3_PLUS_EXTENSION';
}

function recommendedWaveForTrack(track) {
  if (track === 'ABSOLUTE_ZERO_FOUNDATION' || track === 'N5_REINFORCEMENT') {
    return 'WAVE_1_N5_PATCH';
  }
  if (track === 'N4_FOUNDATION') {
    return 'WAVE_2_N4_FOUNDATION';
  }
  if (track === 'N3_PLUS_EXTENSION') {
    return 'WAVE_3_N3_PLUS';
  }
  return 'WAVE_4_REGISTER_BUSINESS';
}

function priorityForTopic(topic, track) {
  if (track === 'ABSOLUTE_ZERO_FOUNDATION') return 'P0';
  if (track === 'N5_REINFORCEMENT') return 'P0';
  if (track === 'N4_FOUNDATION') return topic.coverageStatus === 'partial' ? 'P1' : 'P2';
  if (track === 'CONVERSATION_REGISTER') return 'P2';
  return 'P3';
}

function lessonKindForTopic(topic, track) {
  if (topic.topicType === 'kana' || track === 'ABSOLUTE_ZERO_FOUNDATION') return 'kana_scaffold';
  if (track === 'BUSINESS_KEIGO') return 'business';
  if (track === 'CONVERSATION_REGISTER') return 'register';
  if (topic.coverageStatus === 'partial') return 'reinforcement';
  if (track === 'N3_PLUS_EXTENSION') return 'bridge';
  return 'new_lesson';
}

function estimatedMinutesForTrack(track) {
  if (track === 'ABSOLUTE_ZERO_FOUNDATION') return 8;
  if (track === 'N5_REINFORCEMENT') return 10;
  if (track === 'N4_FOUNDATION') return 12;
  return 15;
}

function coverageGoalForTopic(topic) {
  if (topic.coverageStatus === 'missing') return 'cover_missing_topic';
  if (topic.coverageStatus === 'partial') return 'split_partial_topic';
  if (topic.coverageStatus === 'covered') return 'strengthen_existing_topic';
  return 'prepare_future_runtime';
}

function blockersForTopic(topic, track, questionBlueprint) {
  const blockers = ['needs_original_examples', 'needs_lesson_slot', 'needs_human_review'];
  if (topic.audioPolicy?.requiredBeforePublish) {
    blockers.push('needs_tts_decision');
  }
  if (
    track === 'CONVERSATION_REGISTER' ||
    track === 'BUSINESS_KEIGO' ||
    (questionBlueprint.draftFutureQuestionTypes ?? []).length > 0
  ) {
    blockers.push('needs_runtime_support');
  }
  return [...new Set(blockers)];
}

function lessonBlueprintIdFor(topic) {
  return `ldb-${topic.topicId.replace(/^topic-/, '')}`;
}

function topicExamplesByTopicId(examples) {
  const byTopicId = new Map();
  for (const example of examples) {
    if (!byTopicId.has(example.topicId)) byTopicId.set(example.topicId, []);
    byTopicId.get(example.topicId).push(example.exampleId);
  }
  return byTopicId;
}

function validationGatesFor(topic, track) {
  const gates = ['ExampleOriginalityGate', 'RuntimeQuestionCompatibilityGate', 'KoreanLearnerGate'];
  if (topic.audioPolicy?.requiredBeforePublish) gates.push('AudioReadinessGate');
  if (topic.coverageStatus === 'partial') gates.push('ContrastGate');
  if (track === 'CONVERSATION_REGISTER' || track === 'BUSINESS_KEIGO') gates.push('RegisterGate');
  return gates;
}

function buildLessonDraftBlueprints(topics, questionBlueprints, examples) {
  const questionBlueprintByTopicId = new Map(
    questionBlueprints.map((blueprint) => [blueprint.topicId, blueprint]),
  );
  const examplesByTopicId = topicExamplesByTopicId(examples);

  return topics
    .filter((topic) => topic.coverageStatus !== 'covered')
    .map((topic) => {
      const track = trackForTopic(topic);
      const questionBlueprint = questionBlueprintByTopicId.get(topic.topicId);
      if (!questionBlueprint) throw new Error(`Missing question blueprint for ${topic.topicId}.`);
      const lessonKind = lessonKindForTopic(topic, track);
      const exampleIds = examplesByTopicId.get(topic.topicId) ?? [];
      return {
        lessonBlueprintId: lessonBlueprintIdFor(topic),
        status: 'draft',
        track,
        jlptLevel: topic.inferredJlptLevel,
        lessonKind,
        titleKo: `${topic.titleKo} ${topic.coverageStatus === 'partial' ? '보강' : '도입'}`,
        primaryTopicId: topic.topicId,
        topicIds: [topic.topicId],
        estimatedMinutes: estimatedMinutesForTrack(track),
        targetQuestionCount: questionBlueprint.minDraftQuestions,
        runtimeQuestionTypes: questionBlueprint.recommendedQuestionTypes,
        draftFutureQuestionTypes: questionBlueprint.draftFutureQuestionTypes ?? [],
        exampleIds,
        ttsRequired: Boolean(topic.audioPolicy?.requiredBeforePublish || exampleIds.length > 0),
        coverageGoal: coverageGoalForTopic(topic),
        validationGates: validationGatesFor(topic, track),
        notesKo: '실제 lesson JSON 생성 전 단계의 초안이다. PDF 원문/예문을 복제하지 않고 신규 예문과 문항으로 작성한다.',
      };
    });
}

function buildCoveragePriorities(lessonDrafts, topics, questionBlueprints) {
  const topicById = new Map(topics.map((topic) => [topic.topicId, topic]));
  const questionBlueprintByTopicId = new Map(
    questionBlueprints.map((blueprint) => [blueprint.topicId, blueprint]),
  );
  return lessonDrafts.map((lesson) => {
    const topic = topicById.get(lesson.primaryTopicId);
    if (!topic) throw new Error(`Missing topic for lesson draft ${lesson.lessonBlueprintId}.`);
    const questionBlueprint = questionBlueprintByTopicId.get(topic.topicId);
    const track = lesson.track;
    return {
      priorityId: `priority-${lesson.lessonBlueprintId.replace(/^ldb-/, '')}`,
      topicId: topic.topicId,
      track,
      priority: priorityForTopic(topic, track),
      recommendedWave: recommendedWaveForTrack(track),
      coverageStatus: topic.coverageStatus,
      rationaleKo:
        topic.coverageStatus === 'partial'
          ? '기존 grammar와 일부 연결되어 있으나 PDF coverage 기준으로 용법 분리와 대조 학습이 필요하다.'
          : 'PDF coverage에는 있으나 현재 HaruKoto 기준 데이터에 독립 topic/lesson coverage가 부족하다.',
      blockers: blockersForTopic(topic, track, questionBlueprint),
      targetLessonBlueprintIds: [lesson.lessonBlueprintId],
      notesKo: '우선순위는 현재 lesson runtime 호환성과 N5 파일럿 보강 가치를 기준으로 산정했다.',
    };
  });
}

function printSummary(topics, grammarMappings, vocabularyMappings, blueprints, ttsTargets, ttsReviewBatches, lessonDrafts, priorities) {
  const coverage = {};
  const types = {};
  const waves = {};
  for (const topic of topics) {
    coverage[topic.coverageStatus] = (coverage[topic.coverageStatus] ?? 0) + 1;
    types[topic.topicType] = (types[topic.topicType] ?? 0) + 1;
  }
  for (const priority of priorities) {
    waves[priority.recommendedWave] = (waves[priority.recommendedWave] ?? 0) + 1;
  }
  console.log('Derived curriculum topic contracts');
  console.log(`- topics: ${topics.length}`);
  console.log(`- grammar mappings: ${grammarMappings.length}`);
  console.log(`- vocabulary mappings: ${vocabularyMappings.length}`);
  console.log(`- question blueprints: ${blueprints.length}`);
  console.log(`- tts targets: ${ttsTargets.length}`);
  console.log(`- tts review batches: ${ttsReviewBatches.length}`);
  console.log(`- lesson draft blueprints: ${lessonDrafts.length}`);
  console.log(`- coverage priorities: ${priorities.length}`);
  console.log('- api topic grammar bundle: apps/api/app/data/curriculum/topic-grammar-map.json');
  console.log('- api topic vocabulary bundle: apps/api/app/data/curriculum/topic-vocabulary-map.json');
  console.log('- api tts target bundle: apps/api/app/data/curriculum/tts-target-manifest.json');
  console.log('- api tts review bundle: apps/api/app/data/curriculum/tts-review-batches.json');
  console.log(`- coverage: ${JSON.stringify(coverage)}`);
  console.log(`- topicTypes: ${JSON.stringify(types)}`);
  console.log(`- priorityWaves: ${JSON.stringify(waves)}`);
}

function main() {
  const inventory = readJson(join(CURRICULUM_DIR, 'pdf-topic-inventory.json'));
  const exampleBank = readJson(join(CURRICULUM_DIR, 'example-bank.json'));
  const seedCandidates = readOptionalJson(join(CURRICULUM_DIR, 'lesson-seed-candidates.json'), {
    candidates: [],
  });
  const orderIndex = grammarOrderIndex();
  const vocabularyIndex = vocabularyOrderIndex();
  const topics = inventory.items.map((item) => buildTopic(item, orderIndex));
  const mappings = buildGrammarMap(inventory.items, orderIndex);
  const vocabularyMappings = buildVocabularyMap(inventory.items, vocabularyIndex);
  const blueprints = buildQuestionBlueprints(topics);
  const ttsTargets = buildTtsTargetManifest(topics, exampleBank.examples, seedCandidates, vocabularyMappings);
  const ttsReviewBatches = buildTtsReviewBatches(ttsTargets);
  const lessonDrafts = buildLessonDraftBlueprints(topics, blueprints, exampleBank.examples);
  const priorities = buildCoveragePriorities(lessonDrafts, topics, blueprints);

  mkdirSync(CURRICULUM_DIR, { recursive: true });
  writeJson(join(CURRICULUM_DIR, 'curriculum-topics.json'), {
    schemaVersion: 1,
    status: 'draft',
    topics,
  });
  writeJson(join(CURRICULUM_DIR, 'topic-grammar-map.json'), {
    schemaVersion: 1,
    status: 'draft',
    mappings,
  });
  writeJson(join(API_CURRICULUM_DIR, 'topic-grammar-map.json'), {
    schemaVersion: 1,
    status: 'draft',
    mappings,
  });
  writeJson(join(CURRICULUM_DIR, 'topic-vocabulary-map.json'), {
    schemaVersion: 1,
    status: 'draft',
    mappings: vocabularyMappings,
  });
  writeJson(join(API_CURRICULUM_DIR, 'topic-vocabulary-map.json'), {
    schemaVersion: 1,
    status: 'draft',
    mappings: vocabularyMappings,
  });
  writeJson(join(CURRICULUM_DIR, 'question-blueprints.json'), {
    schemaVersion: 1,
    status: 'draft',
    blueprints,
  });
  writeJson(join(CURRICULUM_DIR, 'tts-target-manifest.json'), {
    schemaVersion: 1,
    status: 'draft',
    targets: ttsTargets,
  });
  writeJson(join(API_CURRICULUM_DIR, 'tts-target-manifest.json'), {
    schemaVersion: 1,
    status: 'draft',
    targets: ttsTargets,
  });
  writeJson(join(CURRICULUM_DIR, 'tts-review-batches.json'), {
    schemaVersion: 1,
    status: 'draft',
    batches: ttsReviewBatches,
  });
  writeJson(join(API_CURRICULUM_DIR, 'tts-review-batches.json'), {
    schemaVersion: 1,
    status: 'draft',
    batches: ttsReviewBatches,
  });
  writeJson(join(CURRICULUM_DIR, 'lesson-draft-blueprints.json'), {
    schemaVersion: 1,
    status: 'draft',
    lessons: lessonDrafts,
  });
  writeJson(join(CURRICULUM_DIR, 'coverage-priorities.json'), {
    schemaVersion: 1,
    status: 'draft',
    priorities,
  });

  printSummary(topics, mappings, vocabularyMappings, blueprints, ttsTargets, ttsReviewBatches, lessonDrafts, priorities);
}

main();
