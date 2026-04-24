import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PACKAGE_DIR = join(SCRIPT_DIR, '..');
const DATA_DIR = join(PACKAGE_DIR, 'data');
const LESSONS_DIR = join(DATA_DIR, 'lessons');
const VOCAB_DIR = join(DATA_DIR, 'vocabulary');
const GRAMMAR_DIR = join(DATA_DIR, 'grammar');

const ALLOWED_META_STATUSES = new Set(['DRAFT', 'PILOT', 'PUBLISHED']);
const QUESTION_TYPES = new Set(['VOCAB_MCQ', 'CONTEXT_CLOZE', 'SENTENCE_REORDER']);
const COGNITIVE_LEVELS = new Set(['인식', '적용', '산출유사']);
const PLACEHOLDER_RE = /\b(TODO|TBD|FIXME|PLACEHOLDER|LOREM)\b|임시|테스트용/i;
const GRAMMAR_TEACHING_PATTERN_ALIASES = new Map([
  [20, new Set(['〜ている'])],
  [35, new Set(['これ / それ / あれ'])],
  [36, new Set(['この / その / あの + 名詞'])],
  [37, new Set(['名詞 + の + 名詞'])],
  [38, new Set(['い形容詞 / な形容詞 + です'])],
  [39, new Set(['い形容詞 + 名詞 / な形容詞 + な + 名詞'])],
  [40, new Set(['ここ / そこ / あそこ'])],
  [42, new Set(['〜に ある / いる'])],
  [45, new Set(['動詞の辞書形 (る動詞 / う動詞)'])],
  [47, new Set(['する / 来る (불규칙 동사)'])],
  [48, new Set(['〜ない / 〜ません'])],
  [49, new Set(['Verb て-form'])],
  [50, new Set(['Verb+て、Verb'])],
  [51, new Set(['Verb+てから'])],
  [54, new Set(['もう〜ました'])],
]);

const CHECKS = [
  {
    name: 'Data load',
    scope: 'lesson/reference files',
    pass: 'All requested JSON files were loaded.',
  },
  {
    name: 'Chapter metadata',
    scope: 'chapter meta',
    pass: 'Chapter metadata is internally consistent.',
  },
  {
    name: 'Reference links',
    scope: 'vocabulary/grammar orders',
    pass: 'Lesson vocabulary and grammar orders resolve to reference data.',
  },
  {
    name: 'Reading script',
    scope: 'content_jsonb.reading',
    pass: 'Reading scripts have complete speaker, voice, text, and translation fields.',
  },
  {
    name: 'Questions',
    scope: 'content_jsonb.questions',
    pass: 'Question contracts and answer keys are structurally valid.',
  },
  {
    name: 'Learning quality heuristics',
    scope: 'lesson content',
    pass: 'Pilot lessons meet baseline duration, density, and explanation heuristics.',
  },
  {
    name: 'Publish status',
    scope: 'meta.status',
    pass: 'Lesson files use an explicit pilot/production status.',
  },
];

function parseArgs(argv) {
  const args = {
    level: 'N5',
    strictWarnings: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--') {
      continue;
    }
    if (arg === '--level') {
      args.level = argv[index + 1]?.toUpperCase();
      index += 1;
      continue;
    }
    if (arg.startsWith('--level=')) {
      args.level = arg.slice('--level='.length).toUpperCase();
      continue;
    }
    if (arg === '--strict-warnings') {
      args.strictWarnings = true;
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

  return args;
}

function usage() {
  console.log(`Usage: node scripts/lesson-quality-gate.mjs [--level N5] [--strict-warnings]

Runs a PASS/WARN/FAIL content quality gate for lesson JSON data.

Options:
  --level <N1-N5>       JLPT level to inspect. Defaults to N5.
  --strict-warnings     Exit non-zero when warnings are present.
`);
}

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, 'utf8'));
}

function relativePath(filePath) {
  return filePath.replace(`${PACKAGE_DIR}/`, '');
}

function listJsonFiles(dirPath) {
  if (!existsSync(dirPath)) return [];
  return readdirSync(dirPath)
    .filter((name) => name.endsWith('.json'))
    .sort()
    .map((name) => join(dirPath, name));
}

function addIssue(rows, status, check, scope, detail) {
  rows.push({ status, check, scope, detail });
}

function truncateList(items, limit = 8) {
  if (items.length <= limit) return items.join(', ');
  return `${items.slice(0, limit).join(', ')} and ${items.length - limit} more`;
}

function hasText(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function normalize(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function isAcceptedGrammarPattern(lessonPattern, referencePattern, grammarOrder) {
  const normalizedLesson = normalize(lessonPattern);
  const normalizedReference = normalize(referencePattern);
  if (normalizedLesson === normalizedReference) return true;

  const aliases = GRAMMAR_TEACHING_PATTERN_ALIASES.get(grammarOrder);
  return aliases?.has(normalizedLesson) === true;
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

function inspectPlaceholders(value, path, matches) {
  if (typeof value === 'string') {
    if (PLACEHOLDER_RE.test(value)) matches.push(path);
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((item, index) => inspectPlaceholders(item, `${path}[${index}]`, matches));
    return;
  }
  if (value && typeof value === 'object') {
    for (const [key, item] of Object.entries(value)) {
      inspectPlaceholders(item, `${path}.${key}`, matches);
    }
  }
}

function loadReferenceByOrder(dirPath, level, label, rows) {
  const byOrder = new Map();
  const duplicateOrders = [];

  for (const filePath of listJsonFiles(dirPath)) {
    let records;
    try {
      records = readJson(filePath);
    } catch (error) {
      addIssue(rows, 'FAIL', 'Data load', relativePath(filePath), `Cannot parse ${label} JSON: ${error.message}`);
      continue;
    }

    if (!Array.isArray(records)) {
      addIssue(rows, 'FAIL', 'Data load', relativePath(filePath), `${label} file must contain an array.`);
      continue;
    }

    for (const record of records) {
      if (record?.jlptLevel !== level) continue;
      if (!Number.isInteger(record.order)) {
        addIssue(rows, 'FAIL', 'Reference links', relativePath(filePath), `${label} record has invalid order.`);
        continue;
      }
      if (byOrder.has(record.order)) duplicateOrders.push(record.order);
      byOrder.set(record.order, record);
    }
  }

  if (duplicateOrders.length > 0) {
    addIssue(
      rows,
      'FAIL',
      'Reference links',
      label,
      `Duplicate ${label} orders for ${level}: ${truncateList([...new Set(duplicateOrders)].map(String))}`,
    );
  }

  if (byOrder.size === 0) {
    addIssue(rows, 'FAIL', 'Reference links', label, `No ${level} ${label} records were found.`);
  }

  return byOrder;
}

function validateQuestion(question, context, rows) {
  const prefix = `${context} q${question?.order ?? '?'}`;

  if (!Number.isInteger(question?.order) || question.order < 1) {
    addIssue(rows, 'FAIL', 'Questions', prefix, 'question.order must be a positive integer.');
  }
  if (!QUESTION_TYPES.has(question?.type)) {
    addIssue(rows, 'FAIL', 'Questions', prefix, `Unsupported question type: ${question?.type}`);
    return;
  }
  if (!hasText(question.prompt)) {
    addIssue(rows, 'FAIL', 'Questions', prefix, 'Prompt is required.');
  }
  if (!hasText(question.explanation)) {
    addIssue(rows, 'WARN', 'Learning quality heuristics', prefix, 'Explanation is missing.');
  }
  if (question.cognitive_level != null && !COGNITIVE_LEVELS.has(question.cognitive_level)) {
    addIssue(rows, 'WARN', 'Learning quality heuristics', prefix, `Unexpected cognitive_level: ${question.cognitive_level}`);
  }

  if (question.type === 'VOCAB_MCQ' || question.type === 'CONTEXT_CLOZE') {
    if (!Array.isArray(question.options) || question.options.length < 2) {
      addIssue(rows, 'FAIL', 'Questions', prefix, 'Options must contain at least 2 items.');
      return;
    }

    const optionIds = new Set();
    const optionTexts = new Set();
    for (const option of question.options) {
      if (!hasText(option?.id)) {
        addIssue(rows, 'FAIL', 'Questions', prefix, 'Every option needs a non-empty id.');
      }
      if (!hasText(option?.text)) {
        addIssue(rows, 'FAIL', 'Questions', prefix, 'Every option needs non-empty text.');
      }
      if (optionIds.has(option?.id)) {
        addIssue(rows, 'FAIL', 'Questions', prefix, `Duplicate option id: ${option.id}`);
      }
      if (optionTexts.has(option?.text)) {
        addIssue(rows, 'FAIL', 'Questions', prefix, `Duplicate option text: ${option.text}`);
      }
      optionIds.add(option?.id);
      optionTexts.add(option?.text);
    }

    if (!optionIds.has(question.correct_answer)) {
      addIssue(rows, 'FAIL', 'Questions', prefix, 'correct_answer must match an option id.');
    }
  }

  if (question.type === 'SENTENCE_REORDER') {
    if (!Array.isArray(question.tokens) || question.tokens.length < 2) {
      addIssue(rows, 'FAIL', 'Questions', prefix, 'tokens must contain at least 2 items.');
    }
    if (!Array.isArray(question.correct_order) || question.correct_order.length < 2) {
      addIssue(rows, 'FAIL', 'Questions', prefix, 'correct_order must contain at least 2 items.');
    }
    if (!sameMultiset(question.tokens, question.correct_order)) {
      addIssue(rows, 'FAIL', 'Questions', prefix, 'tokens and correct_order must contain the same values.');
    }
  }
}

function validateLessonFile(filePath, level, vocabByOrder, grammarByOrder, state, rows) {
  const rel = relativePath(filePath);
  let data;
  try {
    data = readJson(filePath);
  } catch (error) {
    addIssue(rows, 'FAIL', 'Data load', rel, `Cannot parse lesson JSON: ${error.message}`);
    return;
  }

  const meta = data?.meta;
  const lessons = data?.lessons;
  if (!meta || typeof meta !== 'object') {
    addIssue(rows, 'FAIL', 'Chapter metadata', rel, 'meta is required.');
    return;
  }
  if (!Array.isArray(lessons)) {
    addIssue(rows, 'FAIL', 'Chapter metadata', rel, 'lessons must be an array.');
    return;
  }

  state.chapters += 1;
  state.lessons += lessons.length;

  if (meta.jlpt_level !== level) {
    addIssue(rows, 'FAIL', 'Chapter metadata', rel, `meta.jlpt_level ${meta.jlpt_level} does not match ${level}.`);
  }
  if (!Number.isInteger(meta.part_no) || meta.part_no < 1) {
    addIssue(rows, 'FAIL', 'Chapter metadata', rel, 'meta.part_no must be a positive integer.');
  }
  if (!Number.isInteger(meta.chapter_no) || meta.chapter_no < 1) {
    addIssue(rows, 'FAIL', 'Chapter metadata', rel, 'meta.chapter_no must be a positive integer.');
  }
  if (meta.lesson_count !== lessons.length) {
    addIssue(rows, 'FAIL', 'Chapter metadata', rel, `meta.lesson_count ${meta.lesson_count} != lessons.length ${lessons.length}.`);
  }
  if (!ALLOWED_META_STATUSES.has(meta.status)) {
    addIssue(rows, 'FAIL', 'Publish status', rel, `Unsupported meta.status: ${meta.status}`);
  } else if (meta.status === 'DRAFT') {
    state.draftFiles.push(rel);
  }

  const expectedChapterLessonNos = lessons.map((_, index) => index + 1);
  const actualChapterLessonNos = lessons.map((lesson) => lesson.chapter_lesson_no);
  if (actualChapterLessonNos.join(',') !== expectedChapterLessonNos.join(',')) {
    addIssue(rows, 'FAIL', 'Chapter metadata', rel, 'chapter_lesson_no must be contiguous from 1.');
  }

  for (const lesson of lessons) {
    const context = `${rel} ${lesson?.lesson_id ?? `lesson-${lesson?.lesson_no ?? '?'}`}`;
    const placeholderMatches = [];
    inspectPlaceholders(lesson, context, placeholderMatches);
    if (placeholderMatches.length > 0) {
      addIssue(rows, 'FAIL', 'Learning quality heuristics', context, `Placeholder text found at ${truncateList(placeholderMatches)}.`);
    }

    if (!hasText(lesson?.lesson_id)) {
      addIssue(rows, 'FAIL', 'Chapter metadata', context, 'lesson_id is required.');
    } else if (state.lessonIds.has(lesson.lesson_id)) {
      addIssue(rows, 'FAIL', 'Chapter metadata', context, `Duplicate lesson_id: ${lesson.lesson_id}`);
    } else {
      state.lessonIds.add(lesson.lesson_id);
    }

    if (!Number.isInteger(lesson?.lesson_no) || lesson.lesson_no < 1) {
      addIssue(rows, 'FAIL', 'Chapter metadata', context, 'lesson_no must be a positive integer.');
    } else if (state.lessonNos.has(lesson.lesson_no)) {
      addIssue(rows, 'FAIL', 'Chapter metadata', context, `Duplicate lesson_no: ${lesson.lesson_no}`);
    } else {
      state.lessonNos.add(lesson.lesson_no);
    }

    if (!hasText(lesson?.title)) {
      addIssue(rows, 'FAIL', 'Chapter metadata', context, 'title is required.');
    }
    if (!hasText(lesson?.topic)) {
      addIssue(rows, 'FAIL', 'Chapter metadata', context, 'topic is required.');
    }
    if (!Number.isInteger(lesson?.estimated_minutes) || lesson.estimated_minutes < 1) {
      addIssue(rows, 'FAIL', 'Learning quality heuristics', context, 'estimated_minutes must be a positive integer.');
    } else if (lesson.estimated_minutes < 8 || lesson.estimated_minutes > 12) {
      addIssue(rows, 'WARN', 'Learning quality heuristics', context, `estimated_minutes ${lesson.estimated_minutes} is outside the 8-12 minute pilot target.`);
    }

    const vocabOrders = lesson?.vocab_orders;
    if (!Array.isArray(vocabOrders) || vocabOrders.length < 1) {
      addIssue(rows, 'FAIL', 'Reference links', context, 'vocab_orders must contain at least one item.');
    } else {
      state.vocabLinks += vocabOrders.length;
      if (vocabOrders.length < 4 || vocabOrders.length > 8) {
        addIssue(rows, 'WARN', 'Learning quality heuristics', context, `vocab_orders length ${vocabOrders.length} is outside the 4-8 item target.`);
      }

      const seenVocabOrders = new Set();
      for (const order of vocabOrders) {
        if (!Number.isInteger(order)) {
          addIssue(rows, 'FAIL', 'Reference links', context, `vocab order must be an integer: ${order}`);
          continue;
        }
        if (seenVocabOrders.has(order)) {
          addIssue(rows, 'FAIL', 'Reference links', context, `Duplicate vocab order: ${order}`);
        }
        seenVocabOrders.add(order);

        const vocab = vocabByOrder.get(order);
        if (!vocab) {
          addIssue(rows, 'FAIL', 'Reference links', context, `Vocabulary order ${order} not found for ${level}.`);
          continue;
        }
        if (!lesson.vocab_detail?.[String(order)]) {
          addIssue(rows, 'WARN', 'Learning quality heuristics', context, `vocab_detail is missing order ${order}.`);
        }
      }
    }

    const grammarOrder = lesson?.grammar?.grammar_order;
    if (grammarOrder == null) {
      addIssue(rows, 'FAIL', 'Reference links', context, 'grammar.grammar_order is required.');
    } else if (!Number.isInteger(grammarOrder)) {
      addIssue(rows, 'FAIL', 'Reference links', context, 'grammar.grammar_order must be an integer.');
    } else {
      state.grammarLinks += 1;
      const grammar = grammarByOrder.get(grammarOrder);
      if (!grammar) {
        addIssue(rows, 'FAIL', 'Reference links', context, `Grammar order ${grammarOrder} not found for ${level}.`);
      } else if (
        hasText(lesson?.grammar?.pattern) &&
        !isAcceptedGrammarPattern(lesson.grammar.pattern, grammar.pattern, grammarOrder)
      ) {
        addIssue(
          rows,
          'WARN',
          'Learning quality heuristics',
          context,
          `Lesson grammar pattern "${lesson.grammar.pattern}" differs from reference "${grammar.pattern}".`,
        );
      }
    }

    const reading = lesson?.content_jsonb?.reading;
    const script = reading?.script;
    if (!reading || !Array.isArray(script) || script.length < 1) {
      addIssue(rows, 'FAIL', 'Reading script', context, 'content_jsonb.reading.script must contain at least one line.');
    } else {
      state.scriptLines += script.length;
      if (script.length < 3 || script.length > 6) {
        addIssue(rows, 'WARN', 'Learning quality heuristics', context, `reading.script length ${script.length} is outside the 3-6 line target.`);
      }
      if (!hasText(reading.scene)) {
        addIssue(rows, 'WARN', 'Learning quality heuristics', context, 'reading.scene is missing.');
      }
      script.forEach((line, lineIndex) => {
        const lineScope = `${context} script[${lineIndex}]`;
        if (!hasText(line?.speaker)) addIssue(rows, 'FAIL', 'Reading script', lineScope, 'speaker is required.');
        if (!hasText(line?.voice_id)) addIssue(rows, 'FAIL', 'Reading script', lineScope, 'voice_id is required.');
        if (!hasText(line?.text)) addIssue(rows, 'FAIL', 'Reading script', lineScope, 'text is required.');
        if (!hasText(line?.translation)) addIssue(rows, 'FAIL', 'Reading script', lineScope, 'translation is required.');
      });
      if (!Array.isArray(reading.highlights) || reading.highlights.length < 1) {
        addIssue(rows, 'WARN', 'Learning quality heuristics', context, 'reading.highlights should contain at least one item.');
      }
    }

    const questions = lesson?.content_jsonb?.questions;
    if (!Array.isArray(questions) || questions.length < 5) {
      addIssue(rows, 'FAIL', 'Questions', context, 'content_jsonb.questions must contain at least 5 questions.');
    } else {
      state.questions += questions.length;
      if (questions.length !== 5) {
        addIssue(rows, 'WARN', 'Learning quality heuristics', context, `questions length ${questions.length} differs from the N5 pilot target of 5.`);
      }

      const questionOrders = questions.map((question) => question.order);
      const expectedQuestionOrders = questions.map((_, index) => index + 1);
      if (questionOrders.join(',') !== expectedQuestionOrders.join(',')) {
        addIssue(rows, 'FAIL', 'Questions', context, 'Question order must be contiguous from 1.');
      }

      const prompts = new Set();
      const objectiveCorrectAnswers = [];
      for (const question of questions) {
        if (hasText(question?.prompt)) {
          if (prompts.has(question.prompt)) {
            addIssue(rows, 'WARN', 'Learning quality heuristics', context, `Duplicate question prompt: ${question.prompt}`);
          }
          prompts.add(question.prompt);
        }
        if (question?.type === 'VOCAB_MCQ' || question?.type === 'CONTEXT_CLOZE') {
          objectiveCorrectAnswers.push(question.correct_answer);
        }
        validateQuestion(question, context, rows);
      }

      const answerSet = new Set(objectiveCorrectAnswers.filter(Boolean));
      if (objectiveCorrectAnswers.length >= 3 && answerSet.size === 1) {
        state.answerBiasLessons.push(`${lesson.lesson_id} (${objectiveCorrectAnswers[0]})`);
      }
    }
  }
}

function addAggregateIssues(state, rows) {
  if (state.draftFiles.length > 0) {
    addIssue(
      rows,
      'WARN',
      'Publish status',
      'meta.status',
      `DRAFT files are included in the pilot gate: ${truncateList(state.draftFiles)}`,
    );
  }

  if (state.answerBiasLessons.length > 0) {
    addIssue(
      rows,
      'WARN',
      'Learning quality heuristics',
      'answer key balance',
      `Objective questions use one repeated correct option within a lesson: ${truncateList(state.answerBiasLessons)}`,
    );
  }

  if (state.lessons > 0) {
    const expectedLessonNos = Array.from({ length: state.lessons }, (_, index) => index + 1);
    const actualLessonNos = [...state.lessonNos].sort((left, right) => left - right);
    if (actualLessonNos.join(',') !== expectedLessonNos.join(',')) {
      addIssue(rows, 'FAIL', 'Chapter metadata', 'lesson_no', 'lesson_no must be globally contiguous for the selected level.');
    }
  }
}

function addPassRows(rows) {
  for (const check of CHECKS) {
    if (!rows.some((row) => row.check === check.name)) {
      addIssue(rows, 'PASS', check.name, check.scope, check.pass);
    }
  }
}

function escapeCell(value) {
  return String(value).replaceAll('|', '\\|').replace(/\s+/g, ' ').trim();
}

function printReport(level, state, rows, strictWarnings) {
  const counts = {
    PASS: rows.filter((row) => row.status === 'PASS').length,
    WARN: rows.filter((row) => row.status === 'WARN').length,
    FAIL: rows.filter((row) => row.status === 'FAIL').length,
  };
  const overall = counts.FAIL > 0 ? 'FAIL' : counts.WARN > 0 ? 'WARN' : 'PASS';

  console.log(`# ${level} Lesson Content Quality Gate`);
  console.log('');
  console.log(`- overall: ${overall}`);
  console.log(`- chapters: ${state.chapters}`);
  console.log(`- lessons: ${state.lessons}`);
  console.log(`- questions: ${state.questions}`);
  console.log(`- reading script lines: ${state.scriptLines}`);
  console.log(`- vocabulary links: ${state.vocabLinks}`);
  console.log(`- grammar links: ${state.grammarLinks}`);
  console.log(`- checks: ${counts.PASS} PASS / ${counts.WARN} WARN / ${counts.FAIL} FAIL`);
  if (strictWarnings) console.log('- strict warnings: enabled');
  console.log('');
  console.log('| Status | Check | Scope | Detail |');
  console.log('|---|---|---|---|');
  for (const row of rows.sort((left, right) => {
    const order = { FAIL: 0, WARN: 1, PASS: 2 };
    return order[left.status] - order[right.status] || left.check.localeCompare(right.check);
  })) {
    console.log(`| ${row.status} | ${escapeCell(row.check)} | ${escapeCell(row.scope)} | ${escapeCell(row.detail)} |`);
  }

  return { overall, counts };
}

function main() {
  let args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    usage();
    process.exit(2);
  }

  if (args.help) {
    usage();
    return;
  }

  const rows = [];
  const levelDir = join(LESSONS_DIR, args.level.toLowerCase());
  const lessonFiles = listJsonFiles(levelDir);
  if (lessonFiles.length === 0) {
    addIssue(rows, 'FAIL', 'Data load', relativePath(levelDir), `No lesson files found for ${args.level}.`);
  }

  const vocabByOrder = loadReferenceByOrder(VOCAB_DIR, args.level, 'vocabulary', rows);
  const grammarByOrder = loadReferenceByOrder(GRAMMAR_DIR, args.level, 'grammar', rows);
  const state = {
    chapters: 0,
    lessons: 0,
    questions: 0,
    scriptLines: 0,
    vocabLinks: 0,
    grammarLinks: 0,
    lessonIds: new Set(),
    lessonNos: new Set(),
    draftFiles: [],
    answerBiasLessons: [],
  };

  for (const filePath of lessonFiles) {
    validateLessonFile(filePath, args.level, vocabByOrder, grammarByOrder, state, rows);
  }

  addAggregateIssues(state, rows);
  addPassRows(rows);
  const result = printReport(args.level, state, rows, args.strictWarnings);

  if (result.counts.FAIL > 0 || (args.strictWarnings && result.counts.WARN > 0)) {
    process.exit(1);
  }
}

main();
