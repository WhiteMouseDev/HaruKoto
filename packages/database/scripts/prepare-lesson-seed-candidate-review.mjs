import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PACKAGE_DIR = join(SCRIPT_DIR, '..');
const DATA_DIR = join(PACKAGE_DIR, 'data');
const LESSONS_DIR = join(DATA_DIR, 'lessons');
const VOCAB_DIR = join(DATA_DIR, 'vocabulary');
const GRAMMAR_DIR = join(DATA_DIR, 'grammar');
const CURRICULUM_DIR = join(DATA_DIR, 'curriculum');
const DEFAULT_OUT_DIR = join(CURRICULUM_DIR, 'lesson-seed-candidate-review');
const LEVELS = new Set(['N5', 'N4', 'N3', 'N2', 'N1']);

function usage() {
  return [
    'Usage: node scripts/prepare-lesson-seed-candidate-review.mjs [--level N4] [--candidate <candidateId>] [--out <dir>] [--include-promoted]',
    '',
    'Generates reviewer-editable packets from unpromoted lesson seed candidates.',
    'The packet is preparation evidence only; reviewerDecision starts as PENDING.',
  ].join('\n');
}

function parseArgs(argv) {
  const args = {
    level: 'N4',
    outDir: DEFAULT_OUT_DIR,
    includePromoted: false,
    candidateIds: [],
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--') continue;
    if (arg === '--level') {
      args.level = argv[index + 1]?.toUpperCase();
      index += 1;
      continue;
    }
    if (arg.startsWith('--level=')) {
      args.level = arg.slice('--level='.length).toUpperCase();
      continue;
    }
    if (arg === '--out') {
      const value = argv[index + 1];
      if (!value || value.startsWith('--')) throw new Error('--out requires a directory path');
      args.outDir = resolve(process.cwd(), value);
      index += 1;
      continue;
    }
    if (arg.startsWith('--out=')) {
      args.outDir = resolve(process.cwd(), arg.slice('--out='.length));
      continue;
    }
    if (arg === '--include-promoted') {
      args.includePromoted = true;
      continue;
    }
    if (arg === '--candidate') {
      const value = argv[index + 1];
      if (!value || value.startsWith('--')) throw new Error('--candidate requires a candidateId');
      args.candidateIds.push(value);
      index += 1;
      continue;
    }
    if (arg.startsWith('--candidate=')) {
      args.candidateIds.push(arg.slice('--candidate='.length));
      continue;
    }
    if (arg === '--help' || arg === '-h') {
      args.help = true;
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  if (!LEVELS.has(args.level ?? '')) {
    throw new Error('--level must be one of N1, N2, N3, N4, N5');
  }
  for (const candidateId of args.candidateIds) {
    if (!/^lsc-[a-z0-9][a-z0-9-]*$/.test(candidateId)) {
      throw new Error('--candidate must match lsc-<slug>');
    }
  }
  return args;
}

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, 'utf8'));
}

function writeJson(filePath, data) {
  mkdirSync(dirname(filePath), { recursive: true });
  writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`, 'utf8');
}

function relativePath(filePath) {
  return filePath.replace(`${PACKAGE_DIR}/`, '').replaceAll('\\', '/');
}

function listJsonFiles(dirPath) {
  if (!existsSync(dirPath)) return [];
  return readdirSync(dirPath)
    .filter((name) => name.endsWith('.json'))
    .sort()
    .map((name) => join(dirPath, name));
}

function loadRowsByOrder(dirPath, level) {
  const byOrder = new Map();
  const fileName = dirPath === VOCAB_DIR ? `${level.toLowerCase()}-words.json` : `${level.toLowerCase()}-grammar.json`;
  const rows = readJson(join(dirPath, fileName));
  for (const row of rows) {
    if (row?.jlptLevel === level && Number.isInteger(row.order)) {
      byOrder.set(row.order, row);
    }
  }
  return byOrder;
}

function loadExamplesById() {
  const examples = readJson(join(CURRICULUM_DIR, 'example-bank.json')).examples ?? [];
  return new Map(examples.map((example) => [example.exampleId, example]));
}

function loadTopicsById() {
  const topics = readJson(join(CURRICULUM_DIR, 'curriculum-topics.json')).topics ?? [];
  return new Map(topics.map((topic) => [topic.topicId, topic]));
}

function loadTtsTargetByTextSource() {
  const manifest = readJson(join(CURRICULUM_DIR, 'tts-target-manifest.json'));
  return new Map(manifest.targets.map((target) => [target.textSource, target]));
}

function loadPromotedLessonsByKey(level) {
  const promotedLessons = new Map();
  const levelDir = join(LESSONS_DIR, level.toLowerCase());
  for (const filePath of listJsonFiles(levelDir)) {
    const chapter = readJson(filePath);
    for (const lesson of chapter.lessons ?? []) {
      promotedLessons.set(`${level}:${lesson.lesson_no}:${lesson.title}`, lesson);
    }
  }
  return promotedLessons;
}

function promotionKey(candidate) {
  const target = candidate.promotionTarget;
  if (!target?.level || !Number.isInteger(target.lessonNo) || !candidate.seedShape?.title) return null;
  return `${target.level}:${target.lessonNo}:${candidate.seedShape.title}`;
}

function ttsTargetFor(targetByTextSource, textSource) {
  const target = targetByTextSource.get(textSource);
  return {
    targetId: target?.targetId ?? null,
    textSource,
    audioTargetType: target?.audioTargetType ?? null,
    audioField: target?.audioField ?? null,
    generationStatus: target?.generationStatus ?? null,
    preferredVoiceId: target?.preferredVoiceId ?? null,
  };
}

function buildQuestion(question, ttsTarget) {
  const base = {
    order: question.order,
    type: question.type,
    cognitiveLevel: question.cognitive_level ?? null,
    prompt: question.prompt,
    explanation: question.explanation ?? null,
    ttsTarget,
  };

  if (question.type === 'SENTENCE_REORDER') {
    return {
      ...base,
      tokens: question.tokens ?? [],
      correctOrder: question.correct_order ?? [],
    };
  }

  const correctOption = (question.options ?? []).find((option) => option.id === question.correct_answer);
  return {
    ...base,
    options: question.options ?? [],
    correctAnswer: question.correct_answer ?? null,
    correctOptionText: correctOption?.text ?? null,
  };
}

function reviewerChecklistForCandidate(candidate) {
  const scriptCount = candidate.seedShape?.content_jsonb?.reading?.script?.length ?? 0;
  const questionCount = candidate.seedShape?.content_jsonb?.questions?.length ?? 0;
  return [
    '후보가 공식 lesson으로 승격되기 전에 topic coverage와 promotionTarget이 맞는지 확인한다.',
    '일본어 예문과 대화문이 자연스럽고 PDF 원문 복제가 아닌지 확인한다.',
    '한국어 번역, 해설, distractor가 한국어 학습자 기준으로 명확한지 확인한다.',
    '문항 정답과 해설이 prompt/options/token order와 일치하는지 확인한다.',
    `TTS review target이 example ${candidate.exampleIds?.length ?? 0}개, script ${scriptCount}개, question ${questionCount}개를 모두 덮는지 확인한다.`,
  ];
}

function buildCandidateReviewRow(candidate, context) {
  const { examplesById, grammarByOrder, promotedLessonsByKey, targetByTextSource, topicsById, vocabByOrder } = context;
  const seedShape = candidate.seedShape ?? {};
  const grammarOrder = seedShape.grammar?.grammar_order;
  const grammarRef = grammarByOrder.get(grammarOrder);
  const script = seedShape.content_jsonb?.reading?.script ?? [];
  const questions = seedShape.content_jsonb?.questions ?? [];
  const candidateId = candidate.candidateId;
  const promotedLesson = promotedLessonsByKey.get(promotionKey(candidate));
  const promotedLessonId = promotedLesson?.lesson_id ?? null;
  const lessonSeedSourceId = promotedLessonId ?? candidateId;
  const lessonSeedSourcePrefix = promotedLessonId ? 'lesson-seeds' : 'lesson-seed-candidates';

  const examples = (candidate.exampleIds ?? []).map((exampleId) => {
    const example = examplesById.get(exampleId);
    return {
      exampleId,
      topicId: example?.topicId ?? null,
      japanese: example?.japanese ?? null,
      reading: example?.reading ?? null,
      korean: example?.korean ?? null,
      sourceKind: example?.sourceKind ?? null,
      originalityStatus: example?.originalityStatus ?? null,
      reviewStatus: example?.reviewStatus ?? null,
      ttsTarget: ttsTargetFor(targetByTextSource, `example-bank:${exampleId}:japanese`),
    };
  });

  const scriptLines = script.map((line, index) => {
    const order = index + 1;
    return {
      order,
      speaker: line.speaker,
      voiceId: line.voice_id,
      text: line.text,
      translationKo: line.translation,
      ttsTarget: ttsTargetFor(targetByTextSource, `${lessonSeedSourcePrefix}:${lessonSeedSourceId}:script:${order}`),
    };
  });

  const reviewQuestions = questions.map((question) =>
    buildQuestion(
      question,
      ttsTargetFor(targetByTextSource, `${lessonSeedSourcePrefix}:${lessonSeedSourceId}:question:${question.order}`),
    ),
  );

  return {
    reviewId: `lesson-seed-candidate-review-${candidateId}`,
    reviewerDecision: 'PENDING',
    reviewerNotes: '',
    candidateId,
    candidateStatus: candidate.status,
    promotedLessonId,
    lessonBlueprintId: candidate.lessonBlueprintId,
    sourceTopics: (candidate.sourceTopicIds ?? []).map((topicId) => {
      const topic = topicsById.get(topicId);
      return {
        topicId,
        titleKo: topic?.titleKo ?? null,
        coverageStatus: topic?.coverageStatus ?? null,
        inferredJlptLevel: topic?.inferredJlptLevel ?? null,
        reviewStatus: topic?.reviewStatus ?? null,
      };
    }),
    promotionTarget: candidate.promotionTarget,
    title: seedShape.title,
    subtitle: seedShape.subtitle ?? null,
    topic: seedShape.topic,
    estimatedMinutes: seedShape.estimated_minutes,
    grammar: {
      order: grammarOrder,
      pattern: seedShape.grammar?.pattern ?? null,
      meaningKo: seedShape.grammar?.meaning_ko ?? null,
      referencePattern: grammarRef?.pattern ?? null,
      referenceMeaningKo: grammarRef?.meaningKo ?? null,
    },
    vocabulary: (seedShape.vocab_orders ?? []).map((order) => {
      const vocab = vocabByOrder.get(order);
      return {
        order,
        word: vocab?.word ?? null,
        reading: vocab?.reading ?? null,
        meaningKo: vocab?.meaningKo ?? null,
        partOfSpeech: vocab?.partOfSpeech ?? null,
      };
    }),
    examples,
    reading: {
      scene: seedShape.content_jsonb?.reading?.scene ?? null,
      highlights: seedShape.content_jsonb?.reading?.highlights ?? [],
      script: scriptLines,
    },
    questions: reviewQuestions,
    automatedSummary: {
      examples: examples.length,
      scriptLines: scriptLines.length,
      questions: reviewQuestions.length,
      exampleTtsTargets: examples.filter((example) => example.ttsTarget.targetId).length,
      scriptTtsTargets: scriptLines.filter((line) => line.ttsTarget.targetId).length,
      questionTtsTargets: reviewQuestions.filter((question) => question.ttsTarget.targetId).length,
      vocabularyLinks: seedShape.vocab_orders?.length ?? 0,
      grammarLinked: grammarRef ? true : false,
    },
    validationGates: candidate.validationGates ?? [],
    notesKo: candidate.notesKo ?? '',
    reviewerChecklist: reviewerChecklistForCandidate(candidate),
  };
}

export function buildCandidatePacket(level, options = {}) {
  const includePromoted = options.includePromoted ?? false;
  const candidateIds = new Set(options.candidateIds ?? []);
  const candidates = readJson(join(CURRICULUM_DIR, 'lesson-seed-candidates.json')).candidates ?? [];
  const promotedLessonsByKey = loadPromotedLessonsByKey(level);
  const context = {
    examplesById: loadExamplesById(),
    grammarByOrder: loadRowsByOrder(GRAMMAR_DIR, level),
    promotedLessonsByKey,
    targetByTextSource: loadTtsTargetByTextSource(),
    topicsById: loadTopicsById(),
    vocabByOrder: loadRowsByOrder(VOCAB_DIR, level),
  };

  const reviewRows = candidates
    .filter((candidate) => candidate.promotionTarget?.level === level)
    .filter((candidate) => {
      if (candidateIds.size > 0) return candidateIds.has(candidate.candidateId);
      return includePromoted || !promotedLessonsByKey.has(promotionKey(candidate));
    })
    .sort((left, right) => {
      const leftNo = left.promotionTarget?.lessonNo ?? 0;
      const rightNo = right.promotionTarget?.lessonNo ?? 0;
      return leftNo - rightNo || left.candidateId.localeCompare(right.candidateId);
    })
    .map((candidate) => buildCandidateReviewRow(candidate, context));

  const summary = reviewRows.reduce(
    (acc, row) => {
      acc.candidates += 1;
      acc.examples += row.automatedSummary.examples;
      acc.questions += row.automatedSummary.questions;
      acc.scriptLines += row.automatedSummary.scriptLines;
      acc.vocabularyLinks += row.automatedSummary.vocabularyLinks;
      acc.grammarLinks += row.automatedSummary.grammarLinked ? 1 : 0;
      acc.exampleTtsTargets += row.automatedSummary.exampleTtsTargets;
      acc.scriptTtsTargets += row.automatedSummary.scriptTtsTargets;
      acc.questionTtsTargets += row.automatedSummary.questionTtsTargets;
      return acc;
    },
    {
      candidates: 0,
      examples: 0,
      questions: 0,
      scriptLines: 0,
      vocabularyLinks: 0,
      grammarLinks: 0,
      exampleTtsTargets: 0,
      scriptTtsTargets: 0,
      questionTtsTargets: 0,
    },
  );

  return {
    schemaVersion: 1,
    status: 'draft',
    reviewKind: 'lesson_seed_candidate_curriculum_review',
    level,
    includePromoted,
    summary,
    sourceFiles: [
      'data/curriculum/lesson-seed-candidates.json',
      'data/curriculum/example-bank.json',
      'data/curriculum/curriculum-topics.json',
      'data/curriculum/tts-target-manifest.json',
      `data/grammar/${level.toLowerCase()}-grammar.json`,
      `data/vocabulary/${level.toLowerCase()}-words.json`,
    ],
    reviewerInstructions: [
      'APPROVED, NEEDS_EDIT, REJECTED 중 하나로 reviewerDecision을 바꾼다.',
      'NEEDS_EDIT 또는 REJECTED이면 reviewerNotes에 수정 근거를 남긴다.',
      '이 파일은 공식 lesson 승격 전 candidate review packet이다.',
      '승격 후에는 공식 lesson human review packet을 별도로 생성한다.',
    ],
    reviewRows,
  };
}

export function preserveReviewerState(packet, outFile) {
  if (!existsSync(outFile)) return packet;

  const previous = readJson(outFile);
  const previousByReviewId = new Map((previous.reviewRows ?? []).map((row) => [row.reviewId, row]));
  return {
    ...packet,
    reviewRows: packet.reviewRows.map((row) => {
      const previousRow = previousByReviewId.get(row.reviewId);
      if (!previousRow) return row;
      return {
        ...row,
        reviewerDecision: previousRow.reviewerDecision ?? row.reviewerDecision,
        reviewerNotes: previousRow.reviewerNotes ?? row.reviewerNotes,
      };
    }),
  };
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

  const outFile = join(args.outDir, `${args.level.toLowerCase()}-candidate-review.json`);
  const packet = preserveReviewerState(
    buildCandidatePacket(args.level, { includePromoted: args.includePromoted, candidateIds: args.candidateIds }),
    outFile,
  );
  writeJson(outFile, packet);
  console.log(`Wrote ${relativePath(outFile)}`);
  console.log(`- candidates: ${packet.summary.candidates}`);
  console.log(`- example TTS targets: ${packet.summary.exampleTtsTargets}/${packet.summary.examples}`);
  console.log(`- script TTS targets: ${packet.summary.scriptTtsTargets}/${packet.summary.scriptLines}`);
  console.log(`- question TTS targets: ${packet.summary.questionTtsTargets}/${packet.summary.questions}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main();
}
