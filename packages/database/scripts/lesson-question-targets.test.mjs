import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { validateQuestionSrsTarget } from './lib/lesson-question-targets.mjs';

const packageDir = join(dirname(fileURLToPath(import.meta.url)), '..');
const dataDir = join(packageDir, 'data');
const readJson = (path) => JSON.parse(readFileSync(path, 'utf8'));
const catalogs = { vocabularyByLevel: new Map(), grammarByLevel: new Map() };
for (const [key, directory] of [
  ['vocabularyByLevel', 'vocabulary'],
  ['grammarByLevel', 'grammar'],
]) {
  for (const name of readdirSync(join(dataDir, directory)).filter((name) =>
    name.endsWith('.json')
  )) {
    for (const row of readJson(join(dataDir, directory, name))) {
      if (!catalogs[key].has(row.jlptLevel))
        catalogs[key].set(row.jlptLevel, new Map());
      catalogs[key].get(row.jlptLevel).set(row.order, row);
    }
  }
}
const context = { level: 'N5', ...catalogs };
const chapters = readdirSync(join(dataDir, 'lessons')).flatMap((level) =>
  readdirSync(join(dataDir, 'lessons', level))
    .filter((name) => name.endsWith('.json'))
    .map((name) => readJson(join(dataDir, 'lessons', level, name)))
);
const lessons = new Map(
  chapters.flatMap((chapter) =>
    chapter.lessons.map((lesson) => [lesson.lesson_id, lesson])
  )
);

function question(lessonId, order) {
  return lessons
    .get(lessonId)
    .content_jsonb.questions.find((row) => row.order === order);
}

test('accepts explicitly reviewed targets independently of question type and position', () => {
  assert.deepEqual(
    validateQuestionSrsTarget(
      { order: 2, type: 'VOCAB_MCQ', vocabulary_order: 7 },
      context
    ),
    []
  );
  assert.deepEqual(
    validateQuestionSrsTarget(
      { type: 'VOCAB_MCQ', grammar_order: 58 },
      context
    ),
    []
  );
  assert.deepEqual(
    validateQuestionSrsTarget(
      { type: 'CONTEXT_CLOZE', vocabulary_order: 179 },
      context
    ),
    []
  );
});

test('requires an explicit decision; presentation order cannot supply the target', () => {
  for (const source of [
    { order: 1 },
    { type: 'VOCAB_MCQ' },
    { order: 3, type: 'CONTEXT_CLOZE' },
  ]) {
    assert.match(
      validateQuestionSrsTarget(source, context).join(' '),
      /exactly one/
    );
  }
});

test('rejects conflicting references and source database UUIDs', () => {
  assert.match(
    validateQuestionSrsTarget(
      { vocabulary_order: 7, grammar_order: 1 },
      context
    ).join(' '),
    /exactly one/
  );
  for (const field of ['vocabulary_id', 'grammar_id']) {
    assert.match(
      validateQuestionSrsTarget(
        {
          vocabulary_order: 7,
          [field]: '00000000-0000-0000-0000-000000000001',
        },
        context
      ).join(' '),
      /not database UUIDs/
    );
  }
});

test('validates positive integer references against the lesson level catalog', () => {
  for (const invalid of [null, false, true, 0, -1, 1.5, '7']) {
    assert.match(
      validateQuestionSrsTarget({ vocabulary_order: invalid }, context).join(
        ' '
      ),
      /positive integer/
    );
  }
  assert.match(
    validateQuestionSrsTarget({ grammar_order: 99999 }, context).join(' '),
    /not found for N5/
  );
  assert.match(
    validateQuestionSrsTarget(
      { grammar_order: 1 },
      { ...context, level: 'UNKNOWN' }
    ).join(' '),
    /not found for UNKNOWN/
  );
});

test('distinguishes intentional unresolved targets from missing or contradictory metadata', () => {
  assert.deepEqual(
    validateQuestionSrsTarget(
      {
        srs_skip_reason:
          'No unique curriculum target for this combined expression.',
      },
      context
    ),
    []
  );
  for (const reason of ['', '   ', false, null]) {
    assert.match(
      validateQuestionSrsTarget({ srs_skip_reason: reason }, context).join(' '),
      /non-empty review reason/
    );
  }
  assert.match(
    validateQuestionSrsTarget(
      { grammar_order: 1, srs_skip_reason: 'Unresolved' },
      context
    ).join(' '),
    /cannot be combined/
  );
});

test('student question and grammar exercises cannot regress to item-list positions', () => {
  const first = lessons.get('HN5-001');
  assert.equal(
    first.vocab_orders[1],
    605,
    'the second display item is 私, not the second question target'
  );
  assert.equal(question('HN5-001', 2).vocabulary_order, 7);
  assert.equal(catalogs.vocabularyByLevel.get('N5').get(7).word, '学生');
  for (const order of [3, 4, 5])
    assert.equal(question('HN5-001', order).grammar_order, 1);
});

test('retains semantic exceptions: support grammar, vocabulary cloze, and grammar-shaped vocabulary question', () => {
  const expected = [
    ['HN5-031', 3, 'grammar_order', 32],
    ['HN5-032', 4, 'grammar_order', 37],
    ['HN5-033', 1, 'grammar_order', 58],
    ['HN5-034', 2, 'vocabulary_order', 5],
    ['HN5-036', 3, 'vocabulary_order', 547],
    ['HN5-038', 3, 'vocabulary_order', 199],
    ['HN5-041', 4, 'grammar_order', 12],
    ['HN5-042', 2, 'vocabulary_order', 162],
    ['HN5-045', 3, 'vocabulary_order', 122],
    ['HN5-048', 4, 'grammar_order', 33],
    ['HN4-012', 4, 'vocabulary_order', 41],
    ['HN4-016', 3, 'vocabulary_order', 650],
    ['HN4-016', 4, 'grammar_order', 12],
  ];
  for (const [lessonId, order, field, expectedOrder] of expected) {
    assert.equal(
      question(lessonId, order)[field],
      expectedOrder,
      `${lessonId} q${order}`
    );
  }
});

test('all 405 source questions have valid decisions matching the recorded semantic review', () => {
  const review = readJson(
    join(dataDir, 'curriculum', 'lesson-question-target-review.json')
  );
  const reviewedLessons = new Map(
    review.lessons.map((lesson) => [lesson.lesson_id, lesson])
  );
  assert.equal(lessons.size, 81);
  assert.equal(reviewedLessons.size, lessons.size);
  const counts = {
    questions: 0,
    vocabulary_order: 0,
    grammar_order: 0,
    intentionally_skipped: 0,
  };
  for (const chapter of chapters) {
    const level = chapter.meta.jlpt_level;
    for (const lesson of chapter.lessons) {
      const record = reviewedLessons.get(lesson.lesson_id);
      assert.equal(record.level, level);
      assert.equal(
        record.targets.length,
        lesson.content_jsonb.questions.length
      );
      for (const source of lesson.content_jsonb.questions) {
        const label = `${lesson.lesson_id} q${source.order}`;
        assert.deepEqual(
          validateQuestionSrsTarget(source, { level, ...catalogs }),
          [],
          label
        );
        const reviewed = record.targets.find(
          (target) => target.question_order === source.order
        );
        assert.ok(
          reviewed?.rationale.trim(),
          `${label} needs a review rationale`
        );
        for (const field of [
          'vocabulary_order',
          'grammar_order',
          'srs_skip_reason',
        ]) {
          assert.equal(source[field], reviewed[field], `${label} ${field}`);
        }
        counts.questions += 1;
        if (source.srs_skip_reason) {
          counts.intentionally_skipped += 1;
          assert.equal(reviewed.reference_label, null);
        } else {
          const field = source.vocabulary_order
            ? 'vocabulary_order'
            : 'grammar_order';
          const catalog =
            field === 'vocabulary_order'
              ? catalogs.vocabularyByLevel
              : catalogs.grammarByLevel;
          const reference = catalog.get(level).get(source[field]);
          assert.equal(
            reviewed.reference_label,
            reference.word ?? reference.pattern,
            label
          );
          counts[field] += 1;
        }
      }
    }
  }
  assert.deepEqual(counts, {
    questions: 405,
    vocabulary_order: 189,
    grammar_order: 211,
    intentionally_skipped: 5,
  });
  for (const [key, value] of Object.entries(counts))
    assert.equal(review.summary[key], value);
  assert.equal(review.intentional_skips.length, 5);
});
