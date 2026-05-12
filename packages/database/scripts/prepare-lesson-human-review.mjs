import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PACKAGE_DIR = join(SCRIPT_DIR, '..');
const DATA_DIR = join(PACKAGE_DIR, 'data');
const LESSONS_DIR = join(DATA_DIR, 'lessons');
const VOCAB_DIR = join(DATA_DIR, 'vocabulary');
const GRAMMAR_DIR = join(DATA_DIR, 'grammar');
const CURRICULUM_DIR = join(DATA_DIR, 'curriculum');
const DEFAULT_OUT_DIR = join(CURRICULUM_DIR, 'lesson-human-review');

function usage() {
  return [
    'Usage: node scripts/prepare-lesson-human-review.mjs [--level N4] [--out <dir>]',
    '',
    'Generates reviewer-editable lesson review packets from official lesson JSON.',
    'The packet is preparation evidence only; reviewerDecision starts as PENDING.',
  ].join('\n');
}

function parseArgs(argv) {
  const args = {
    level: 'N4',
    outDir: DEFAULT_OUT_DIR,
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
      if (!value || value.startsWith('--')) {
        throw new Error('--out requires a directory path');
      }
      args.outDir = resolve(process.cwd(), value);
      index += 1;
      continue;
    }
    if (arg.startsWith('--out=')) {
      args.outDir = resolve(process.cwd(), arg.slice('--out='.length));
      continue;
    }
    if (arg === '--help' || arg === '-h') {
      args.help = true;
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  if (!/^N[1-5]$/.test(args.level ?? '')) {
    throw new Error('--level must be one of N1, N2, N3, N4, N5');
  }
  if (!args.outDir) {
    throw new Error('--out requires a directory path');
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
  const filePath = join(dirPath, fileName);
  const rows = readJson(filePath);
  for (const row of rows) {
    if (row?.jlptLevel === level && Number.isInteger(row.order)) {
      byOrder.set(row.order, row);
    }
  }
  return byOrder;
}

function loadTtsTargetByTextSource() {
  const manifest = readJson(join(CURRICULUM_DIR, 'tts-target-manifest.json'));
  return new Map(manifest.targets.map((target) => [target.textSource, target]));
}

function ttsTargetFor(targetByTextSource, lessonId, sourceKind, order) {
  const textSource = `lesson-seeds:${lessonId}:${sourceKind}:${order}`;
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

function reviewerChecklistForLesson(lesson) {
  return [
    '문법 도입 순서가 N4 pilot의 선행 지식과 맞는지 확인한다.',
    '대화문 일본어가 자연스럽고 PDF 원문 복제가 아닌지 확인한다.',
    '한국어 번역과 해설이 한국어 학습자 기준으로 명확한지 확인한다.',
    '문항 정답과 해설이 prompt/options와 일치하는지 확인한다.',
    `TTS review target이 script ${lesson.content_jsonb?.reading?.script?.length ?? 0}개와 question ${
      lesson.content_jsonb?.questions?.length ?? 0
    }개를 모두 덮는지 확인한다.`,
  ];
}

function buildReviewRow(chapter, lesson, vocabByOrder, grammarByOrder, targetByTextSource) {
  const grammarOrder = lesson.grammar?.grammar_order;
  const grammarRef = grammarByOrder.get(grammarOrder);
  const script = lesson.content_jsonb?.reading?.script ?? [];
  const questions = lesson.content_jsonb?.questions ?? [];
  const scriptLines = script.map((line, index) => {
    const order = index + 1;
    return {
      order,
      speaker: line.speaker,
      voiceId: line.voice_id,
      text: line.text,
      translationKo: line.translation,
      ttsTarget: ttsTargetFor(targetByTextSource, lesson.lesson_id, 'script', order),
    };
  });
  const reviewQuestions = questions.map((question) =>
    buildQuestion(question, ttsTargetFor(targetByTextSource, lesson.lesson_id, 'question', question.order)),
  );

  return {
    reviewId: `lesson-human-review-${lesson.lesson_id}`,
    reviewerDecision: 'PENDING',
    reviewerNotes: '',
    lessonId: lesson.lesson_id,
    lessonNo: lesson.lesson_no,
    chapterId: chapter.meta.chapter_id,
    chapterTitle: chapter.meta.chapter_title,
    title: lesson.title,
    subtitle: lesson.subtitle ?? null,
    topic: lesson.topic,
    estimatedMinutes: lesson.estimated_minutes,
    grammar: {
      order: grammarOrder,
      pattern: lesson.grammar?.pattern ?? null,
      meaningKo: lesson.grammar?.meaning_ko ?? null,
      referencePattern: grammarRef?.pattern ?? null,
      referenceMeaningKo: grammarRef?.meaningKo ?? null,
    },
    vocabulary: (lesson.vocab_orders ?? []).map((order) => {
      const vocab = vocabByOrder.get(order);
      return {
        order,
        word: vocab?.word ?? null,
        reading: vocab?.reading ?? null,
        meaningKo: vocab?.meaningKo ?? null,
        lessonLabel: lesson.vocab_detail?.[String(order)] ?? null,
      };
    }),
    reading: {
      scene: lesson.content_jsonb?.reading?.scene ?? null,
      highlights: lesson.content_jsonb?.reading?.highlights ?? [],
      script: scriptLines,
    },
    questions: reviewQuestions,
    automatedSummary: {
      scriptLines: scriptLines.length,
      questions: reviewQuestions.length,
      scriptTtsTargets: scriptLines.filter((line) => line.ttsTarget.targetId).length,
      questionTtsTargets: reviewQuestions.filter((question) => question.ttsTarget.targetId).length,
      vocabularyLinks: lesson.vocab_orders?.length ?? 0,
      grammarLinked: grammarRef ? true : false,
    },
    reviewerChecklist: reviewerChecklistForLesson(lesson),
  };
}

function buildPacket(level) {
  const levelDir = join(LESSONS_DIR, level.toLowerCase());
  const lessonFiles = listJsonFiles(levelDir);
  const vocabByOrder = loadRowsByOrder(VOCAB_DIR, level);
  const grammarByOrder = loadRowsByOrder(GRAMMAR_DIR, level);
  const targetByTextSource = loadTtsTargetByTextSource();
  const chapters = lessonFiles.map((filePath) => ({
    filePath,
    data: readJson(filePath),
  }));
  const reviewRows = chapters.flatMap((chapter) =>
    (chapter.data.lessons ?? []).map((lesson) =>
      buildReviewRow(chapter.data, lesson, vocabByOrder, grammarByOrder, targetByTextSource),
    ),
  );
  const summary = reviewRows.reduce(
    (acc, row) => {
      acc.lessons += 1;
      acc.questions += row.automatedSummary.questions;
      acc.scriptLines += row.automatedSummary.scriptLines;
      acc.vocabularyLinks += row.automatedSummary.vocabularyLinks;
      acc.grammarLinks += row.automatedSummary.grammarLinked ? 1 : 0;
      acc.scriptTtsTargets += row.automatedSummary.scriptTtsTargets;
      acc.questionTtsTargets += row.automatedSummary.questionTtsTargets;
      return acc;
    },
    {
      chapters: chapters.length,
      lessons: 0,
      questions: 0,
      scriptLines: 0,
      vocabularyLinks: 0,
      grammarLinks: 0,
      scriptTtsTargets: 0,
      questionTtsTargets: 0,
    },
  );

  return {
    schemaVersion: 1,
    status: 'draft',
    reviewKind: 'lesson_human_curriculum_review',
    level,
    summary,
    sourceFiles: chapters.map((chapter) => relativePath(chapter.filePath)),
    reviewerInstructions: [
      'APPROVED, NEEDS_EDIT, REJECTED 중 하나로 reviewerDecision을 바꾼다.',
      'NEEDS_EDIT 또는 REJECTED이면 reviewerNotes에 수정 근거를 남긴다.',
      '이 파일은 승인 원장이 아니라 review packet이다. 최종 승인 상태는 별도 운영 기록에 남긴다.',
    ],
    reviewRows,
  };
}

function preserveReviewerState(packet, outFile) {
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

  const outFile = join(args.outDir, `${args.level.toLowerCase()}-pilot-review.json`);
  const packet = preserveReviewerState(buildPacket(args.level), outFile);
  writeJson(outFile, packet);
  console.log(`Wrote ${relativePath(outFile)}`);
  console.log(`- lessons: ${packet.summary.lessons}`);
  console.log(`- script TTS targets: ${packet.summary.scriptTtsTargets}/${packet.summary.scriptLines}`);
  console.log(`- question TTS targets: ${packet.summary.questionTtsTargets}/${packet.summary.questions}`);
}

main();
