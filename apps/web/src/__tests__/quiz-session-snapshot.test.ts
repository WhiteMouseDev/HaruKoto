import { describe, expect, it } from 'vitest';
import {
  decodeWebQuizSnapshot,
  QuizSnapshotError,
  QUIZ_SNAPSHOT_INVALID_MESSAGE,
  QUIZ_WEB_UNSUPPORTED_MESSAGE,
  restoreWebQuizProgress,
} from '@/lib/quiz-session-snapshot';

const ids = [
  '10000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000003',
];
const webQuestion = (id = ids[0]) => ({
  questionId: id,
  questionText: '映画',
  questionSubText: 'えいが',
  hint: null,
  options: [
    { id: 'correct', text: '영화' },
    { id: 'other', text: '음악' },
  ],
  correctOptionId: 'correct',
});
const apiQuestion = (id = ids[0]) => ({
  id,
  type: 'VOCABULARY',
  question: '映画',
  options: [
    { id: ids[2], text: '영화' },
    { id: ids[1], text: '음악' },
  ],
  correctOptionId: ids[2],
});
const arrangeQuestion = () => ({
  ...webQuestion(),
  questionText: '영화를 봅니다.',
  koreanSentence: '영화를 봅니다.',
  japaneseSentence: '映画を見ます。',
  options: [],
  correctOptionId: ids[0],
  tokens: [
    { text: '映画', type: 'noun', meaning: '영화', order: 0 },
    { text: 'を', type: 'particle', meaning: '', order: 1 },
    { text: '見ます', type: 'verb', meaning: '봅니다', order: 2 },
  ],
});

describe('stored web quiz compatibility', () => {
  it.each(['VOCABULARY', 'GRAMMAR', 'KANJI', 'LISTENING'])(
    'preserves a native multiple-choice snapshot and category %s without rewriting it',
    (category) => {
      const raw = [webQuestion()];
      const before = JSON.stringify(raw);
      expect(decodeWebQuizSnapshot(raw, 1, category)).toEqual({
        questions: raw,
        mode: 'normal',
      });
      expect(JSON.stringify(raw)).toBe(before);
    }
  );

  it('normalizes a known native envelope without changing option IDs', () => {
    const raw = {
      questions: [webQuestion()],
      mode: 'review',
      stage_id: ids[1],
    };
    const before = JSON.stringify(raw);
    expect(decodeWebQuizSnapshot(raw, 1, 'VOCABULARY')).toEqual({
      questions: raw.questions,
      mode: 'review',
    });
    expect(JSON.stringify(raw)).toBe(before);
  });

  it('preserves native cloze display fields and non-UUID option IDs', () => {
    const question = {
      ...webQuestion(),
      sentence: '映画を{blank}。',
      translation: '영화를 봅니다.',
      explanation: '설명',
    };
    expect(decodeWebQuizSnapshot([question], 1, 'CLOZE')).toEqual({
      questions: [question],
      mode: 'cloze',
    });
  });

  it('keeps native arrange tokens and permits a stored permutation', () => {
    const question = arrangeQuestion();
    question.tokens = [
      question.tokens[2],
      question.tokens[0],
      question.tokens[1],
    ];
    expect(decodeWebQuizSnapshot([question], 1, 'SENTENCE_ARRANGE')).toEqual({
      questions: [question],
      mode: 'arrange',
    });
  });

  it('keeps native typing answers rather than opening an empty multiple-choice screen', () => {
    const question = {
      ...webQuestion(),
      options: [],
      correctOptionId: ids[0],
      prompt: '영화',
      answer: 'えいが',
      distractors: ['か'],
    };
    expect(decodeWebQuizSnapshot([question], 1, 'VOCABULARY')).toEqual({
      questions: [question],
      mode: 'typing',
    });
  });

  it.each([
    ['array', [apiQuestion()]],
    ['normal envelope', { mode: 'normal', questions: [apiQuestion()] }],
    ['smart envelope', { mode: 'smart', questions: [apiQuestion()] }],
    [
      'wrong-review envelope',
      {
        mode: 'wrong_answer_review',
        source_session_id: ids[2],
        questions: [apiQuestion()],
      },
    ],
    [
      'legacy matching',
      [{ ...apiQuestion(), options: [], word: '映画', meaningKo: '영화' }],
    ],
    [
      'new matching',
      {
        mode: 'matching',
        matchingPairs: [{ id: ids[2], word: '映画', meaning: '영화' }],
        questions: [{ ...apiQuestion(), options: [] }],
      },
    ],
    [
      'legacy arrange',
      [
        {
          ...apiQuestion(),
          type: 'SENTENCE_ARRANGE',
          options: [],
          correctOptionId: '',
          tokens: ['映画'],
          japaneseSentence: '映画',
        },
      ],
    ],
    [
      'new arrange',
      {
        mode: 'arrange',
        questions: [
          {
            ...apiQuestion(),
            type: 'SENTENCE_ARRANGE',
            options: [],
            correctOptionId: '',
            tokens: ['映画'],
            japaneseSentence: '映画',
          },
        ],
      },
    ],
  ])(
    'does not hand the known API serializer (%s) to the legacy web grader',
    (_, raw) => {
      const before = JSON.stringify(raw);
      expect(() => decodeWebQuizSnapshot(raw, 1, 'VOCABULARY')).toThrow(
        QUIZ_WEB_UNSUPPORTED_MESSAGE
      );
      expect(JSON.stringify(raw)).toBe(before);
    }
  );

  it.each([
    ['empty', []],
    ['count mismatch', [webQuestion(), webQuestion(ids[1])]],
    ['mixed serializers', [webQuestion(), apiQuestion(ids[1])]],
    ['ambiguous IDs', [{ ...webQuestion(), id: ids[1] }]],
    ['duplicate question', [webQuestion(), webQuestion()]],
    ['invalid option', [{ ...webQuestion(), correctOptionId: 'missing' }]],
    [
      'duplicate option',
      [
        {
          ...webQuestion(),
          options: [
            { id: 'correct', text: '영화' },
            { id: 'correct', text: '음악' },
          ],
        },
      ],
    ],
    ['unknown mode', { mode: 'future', questions: [webQuestion()] }],
    [
      'unknown metadata',
      { mode: 'normal', futureFormat: true, questions: [webQuestion()] },
    ],
    ['native empty special', [{ ...webQuestion(), options: [] }]],
    ['mode mismatch', { mode: 'arrange', questions: [webQuestion()] }],
    [
      'invalid token positions',
      [
        {
          ...arrangeQuestion(),
          tokens: [{ text: '映画', type: 'noun', meaning: '', order: 2 }],
        },
      ],
    ],
  ])('rejects %s without mutating the stored data', (_, raw) => {
    const before = JSON.stringify(raw);
    expect(() => decodeWebQuizSnapshot(raw, 1, 'VOCABULARY')).toThrow(
      QUIZ_SNAPSHOT_INVALID_MESSAGE
    );
    expect(JSON.stringify(raw)).toBe(before);
  });

  it('rejects a full-length mixed or duplicate snapshot, rather than only its count', () => {
    expect(() =>
      decodeWebQuizSnapshot(
        [webQuestion(), apiQuestion(ids[1])],
        2,
        'VOCABULARY'
      )
    ).toThrow(QuizSnapshotError);
    expect(() =>
      decodeWebQuizSnapshot([webQuestion(), webQuestion()], 2, 'VOCABULARY')
    ).toThrow(QuizSnapshotError);
    expect(() =>
      decodeWebQuizSnapshot(
        [apiQuestion(), { ...apiQuestion(ids[1]), type: 'GRAMMAR' }],
        2,
        'VOCABULARY'
      )
    ).toThrow(QUIZ_SNAPSHOT_INVALID_MESSAGE);
  });
});

describe('saved question IDs', () => {
  it('skips saved questions in arbitrary order, deduplicates old answers and keeps unsaved source order', () => {
    const questions = ids.map((questionId) => ({ questionId }));
    const before = JSON.stringify(questions);
    expect(restoreWebQuizProgress(questions, [ids[2], ids[2], ids[0]])).toEqual(
      {
        questions: [questions[0], questions[2], questions[1]],
        currentIndex: 2,
      }
    );
    expect(JSON.stringify(questions)).toBe(before);
  });

  it('keeps the all-saved state for explicit completion without creating a new quiz', () => {
    const questions = ids.map((questionId) => ({ questionId }));
    expect(restoreWebQuizProgress(questions, ids).currentIndex).toBe(3);
  });

  it('rejects an answer referring to a different snapshot', () => {
    expect(() => restoreWebQuizProgress([webQuestion()], [ids[1]])).toThrow(
      QUIZ_SNAPSHOT_INVALID_MESSAGE
    );
  });
});
