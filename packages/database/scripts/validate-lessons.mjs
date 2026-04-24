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

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, 'utf8'));
}

function listJsonFiles(dirPath) {
  if (!existsSync(dirPath)) return [];
  return readdirSync(dirPath)
    .filter((name) => name.endsWith('.json'))
    .sort()
    .map((name) => join(dirPath, name));
}

function loadContentByOrder(dirPath, label) {
  const byLevel = new Map();

  for (const filePath of listJsonFiles(dirPath)) {
    const rows = readJson(filePath);
    if (!Array.isArray(rows)) {
      throw new Error(`${label} file must contain an array: ${filePath}`);
    }

    for (const row of rows) {
      if (!row?.jlptLevel || !Number.isInteger(row.order)) continue;
      if (!byLevel.has(row.jlptLevel)) byLevel.set(row.jlptLevel, new Map());
      byLevel.get(row.jlptLevel).set(row.order, row);
    }
  }

  return byLevel;
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

function validateQuestion(question, context, errors) {
  const prefix = `${context} q${question?.order ?? '?'}`;

  if (!Number.isInteger(question?.order) || question.order < 1) {
    errors.push(`${prefix}: question.order must be a positive integer`);
  }

  if (!QUESTION_TYPES.has(question?.type)) {
    errors.push(`${prefix}: unsupported question type ${question?.type}`);
    return;
  }

  if (typeof question.prompt !== 'string' || question.prompt.trim() === '') {
    errors.push(`${prefix}: prompt is required`);
  }

  if (question.type === 'VOCAB_MCQ' || question.type === 'CONTEXT_CLOZE') {
    if (!Array.isArray(question.options) || question.options.length < 2) {
      errors.push(`${prefix}: options must contain at least 2 items`);
      return;
    }

    const optionIds = new Set();
    for (const option of question.options) {
      if (typeof option?.id !== 'string' || option.id.trim() === '') {
        errors.push(`${prefix}: every option needs a non-empty id`);
      }
      if (typeof option?.text !== 'string' || option.text.trim() === '') {
        errors.push(`${prefix}: every option needs non-empty text`);
      }
      if (optionIds.has(option?.id)) {
        errors.push(`${prefix}: duplicate option id ${option.id}`);
      }
      optionIds.add(option?.id);
    }

    if (!optionIds.has(question.correct_answer)) {
      errors.push(`${prefix}: correct_answer must match an option id`);
    }
  }

  if (question.type === 'SENTENCE_REORDER') {
    if (!Array.isArray(question.tokens) || question.tokens.length < 2) {
      errors.push(`${prefix}: tokens must contain at least 2 items`);
    }
    if (!Array.isArray(question.correct_order) || question.correct_order.length < 2) {
      errors.push(`${prefix}: correct_order must contain at least 2 items`);
    }
    if (!sameMultiset(question.tokens, question.correct_order)) {
      errors.push(`${prefix}: tokens and correct_order must contain the same values`);
    }
  }
}

function validateLessonFile(filePath, vocabByLevel, grammarByLevel, totals, errors, warnings) {
  const relativePath = filePath.replace(`${PACKAGE_DIR}/`, '');
  const data = readJson(filePath);
  const meta = data?.meta;
  const lessons = data?.lessons;

  if (!meta || typeof meta !== 'object') {
    errors.push(`${relativePath}: meta is required`);
    return;
  }
  if (!Array.isArray(lessons)) {
    errors.push(`${relativePath}: lessons must be an array`);
    return;
  }

  totals.chapters += 1;
  totals.lessons += lessons.length;

  const level = meta.jlpt_level;
  if (typeof level !== 'string' || level.trim() === '') {
    errors.push(`${relativePath}: meta.jlpt_level is required`);
  }
  if (!Number.isInteger(meta.part_no) || meta.part_no < 1) {
    errors.push(`${relativePath}: meta.part_no must be a positive integer`);
  }
  if (!Number.isInteger(meta.chapter_no) || meta.chapter_no < 1) {
    errors.push(`${relativePath}: meta.chapter_no must be a positive integer`);
  }
  if (meta.lesson_count !== lessons.length) {
    errors.push(`${relativePath}: meta.lesson_count ${meta.lesson_count} != lessons.length ${lessons.length}`);
  }
  if (!ALLOWED_META_STATUSES.has(meta.status)) {
    errors.push(`${relativePath}: unsupported meta.status ${meta.status}`);
  } else if (meta.status === 'DRAFT') {
    warnings.push(`${relativePath}: meta.status is DRAFT; seed publish behavior must be explicit for pilot use`);
  }

  const expectedChapterLessonNos = lessons.map((_, index) => index + 1);
  const actualChapterLessonNos = lessons.map((lesson) => lesson.chapter_lesson_no);
  if (actualChapterLessonNos.join(',') !== expectedChapterLessonNos.join(',')) {
    errors.push(`${relativePath}: chapter_lesson_no must be contiguous from 1`);
  }

  const lessonNos = new Set();
  for (const lesson of lessons) {
    const context = `${relativePath} ${lesson?.lesson_id ?? `lesson-${lesson?.lesson_no ?? '?'}`}`;

    if (typeof lesson?.lesson_id !== 'string' || lesson.lesson_id.trim() === '') {
      errors.push(`${context}: lesson_id is required`);
    }
    if (!Number.isInteger(lesson?.lesson_no) || lesson.lesson_no < 1) {
      errors.push(`${context}: lesson_no must be a positive integer`);
    } else if (lessonNos.has(lesson.lesson_no)) {
      errors.push(`${context}: duplicate lesson_no ${lesson.lesson_no}`);
    } else {
      lessonNos.add(lesson.lesson_no);
    }
    if (typeof lesson?.title !== 'string' || lesson.title.trim() === '') {
      errors.push(`${context}: title is required`);
    }
    if (typeof lesson?.topic !== 'string' || lesson.topic.trim() === '') {
      errors.push(`${context}: topic is required`);
    }
    if (!Number.isInteger(lesson?.estimated_minutes) || lesson.estimated_minutes < 1) {
      errors.push(`${context}: estimated_minutes must be a positive integer`);
    }

    const vocabOrders = lesson?.vocab_orders;
    if (!Array.isArray(vocabOrders) || vocabOrders.length < 1) {
      errors.push(`${context}: vocab_orders must contain at least one item`);
    } else {
      const seenVocabOrders = new Set();
      for (const order of vocabOrders) {
        totals.vocabLinks += 1;
        if (!Number.isInteger(order)) {
          errors.push(`${context}: vocab order must be an integer (${order})`);
          continue;
        }
        if (seenVocabOrders.has(order)) {
          errors.push(`${context}: duplicate vocab order ${order}`);
        }
        seenVocabOrders.add(order);
        if (!vocabByLevel.get(level)?.has(order)) {
          errors.push(`${context}: vocabulary order ${order} not found for ${level}`);
        }
      }
    }

    const grammarOrder = lesson?.grammar?.grammar_order;
    if (grammarOrder == null) {
      errors.push(`${context}: grammar.grammar_order is required`);
    } else {
      totals.grammarLinks += 1;
      if (!Number.isInteger(grammarOrder)) {
        errors.push(`${context}: grammar.grammar_order must be an integer`);
      } else if (!grammarByLevel.get(level)?.has(grammarOrder)) {
        errors.push(`${context}: grammar order ${grammarOrder} not found for ${level}`);
      }
    }

    const reading = lesson?.content_jsonb?.reading;
    if (!reading || !Array.isArray(reading.script) || reading.script.length < 1) {
      errors.push(`${context}: content_jsonb.reading.script must contain at least one line`);
    }

    const questions = lesson?.content_jsonb?.questions;
    if (!Array.isArray(questions) || questions.length < 5) {
      errors.push(`${context}: content_jsonb.questions must contain at least 5 questions`);
    } else {
      totals.questions += questions.length;
      const questionOrders = questions.map((question) => question.order);
      const expectedQuestionOrders = questions.map((_, index) => index + 1);
      if (questionOrders.join(',') !== expectedQuestionOrders.join(',')) {
        errors.push(`${context}: question order must be contiguous from 1`);
      }
      for (const question of questions) validateQuestion(question, context, errors);
    }
  }
}

function main() {
  const vocabByLevel = loadContentByOrder(VOCAB_DIR, 'Vocabulary');
  const grammarByLevel = loadContentByOrder(GRAMMAR_DIR, 'Grammar');
  const totals = {
    chapters: 0,
    lessons: 0,
    questions: 0,
    vocabLinks: 0,
    grammarLinks: 0,
  };
  const errors = [];
  const warnings = [];

  if (!existsSync(LESSONS_DIR)) {
    errors.push(`Lessons directory not found: ${LESSONS_DIR}`);
  } else {
    for (const levelDir of readdirSync(LESSONS_DIR).sort()) {
      const levelPath = join(LESSONS_DIR, levelDir);
      for (const filePath of listJsonFiles(levelPath)) {
        validateLessonFile(filePath, vocabByLevel, grammarByLevel, totals, errors, warnings);
      }
    }
  }

  console.log('Lesson data validation summary');
  console.log(`- chapters: ${totals.chapters}`);
  console.log(`- lessons: ${totals.lessons}`);
  console.log(`- questions: ${totals.questions}`);
  console.log(`- vocabulary links: ${totals.vocabLinks}`);
  console.log(`- grammar links: ${totals.grammarLinks}`);

  if (warnings.length > 0) {
    console.log('\nWarnings');
    for (const warning of warnings) console.log(`- ${warning}`);
  }

  if (errors.length > 0) {
    console.error('\nErrors');
    for (const error of errors) console.error(`- ${error}`);
    process.exit(1);
  }

  console.log('\nLesson data validation passed.');
}

main();
