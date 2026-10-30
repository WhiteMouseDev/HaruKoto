import { z } from 'zod';
import type { QuizQuestion } from '@/hooks/use-quiz';

export const QUIZ_WEB_UNSUPPORTED_MESSAGE =
  '이 퀴즈는 앱에서 이어서 학습해 주세요. 저장된 학습 기록은 유지됩니다.';
export const QUIZ_SNAPSHOT_INVALID_MESSAGE =
  '퀴즈의 저장 정보를 안전하게 불러올 수 없어요. 저장된 학습 기록은 유지됩니다.';

export class QuizSnapshotError extends Error {
  constructor(readonly reason: 'unsupported' | 'invalid') {
    super(
      reason === 'unsupported'
        ? QUIZ_WEB_UNSUPPORTED_MESSAGE
        : QUIZ_SNAPSHOT_INVALID_MESSAGE
    );
  }
}

const text = z.string().refine((value) => value.trim().length > 0);
const optionSchema = z.object({ id: text, text });
const tokenSchema = z.object({
  text,
  type: z.enum([
    'noun',
    'particle',
    'verb',
    'adjective',
    'copula',
    'adverb',
    'suffix',
  ]),
  meaning: z.string(),
  order: z.number().int().nonnegative(),
});
const modes = [
  'normal',
  'matching',
  'arrange',
  'typing',
  'cloze',
  'review',
  'smart',
  'wrong_answer_review',
] as const;
const envelopeSchema = z
  .object({
    questions: z.array(z.unknown()),
    mode: z.enum(modes).nullish(),
    stage_id: z.string().uuid().optional(),
    source_session_id: z.string().uuid().optional(),
    matchingPairs: z
      .array(z.object({ id: text, word: text, meaning: text }))
      .nullish(),
  })
  .strict();

const webQuestionSchema = z
  .object({
    questionId: z.string().uuid(),
    questionText: text,
    questionSubText: z.string().nullish(),
    hint: z.string().nullish(),
    options: z.array(optionSchema),
    correctOptionId: text,
    sentence: text.optional(),
    translation: z.string().optional(),
    explanation: z.string().nullish(),
    grammarPoint: z.string().nullish(),
    koreanSentence: text.optional(),
    japaneseSentence: text.optional(),
    tokens: z.array(tokenSchema).optional(),
    prompt: text.optional(),
    answer: text.optional(),
    distractors: z.array(text).optional(),
  })
  .passthrough();

// This recognizes a stored serializer, not a trustworthy client/origin marker.
// Its grading and retry policies belong to FastAPI. Never pass such records to
// the web's older Prisma answer/completion code, even for multiple choice.
const apiQuestionSchema = z
  .object({
    id: z.string().uuid(),
    type: z.enum([
      'VOCABULARY',
      'GRAMMAR',
      'KANJI',
      'LISTENING',
      'CLOZE',
      'SENTENCE_ARRANGE',
    ]),
    question: text,
    options: z.array(optionSchema),
    correctOptionId: z.string(),
  })
  .passthrough()
  .refine(
    (question) =>
      (question.type === 'SENTENCE_ARRANGE' &&
        question.correctOptionId === '') ||
      z.string().uuid().safeParse(question.correctOptionId).success
  )
  .refine(
    (question) =>
      question.options.every(
        (option) => z.string().uuid().safeParse(option.id).success
      ) &&
      new Set(question.options.map((option) => option.id)).size ===
        question.options.length &&
      (question.options.length === 0 ||
        question.options.some(
          (option) => option.id === question.correctOptionId
        ))
  );

function invalid(): never {
  throw new QuizSnapshotError('invalid');
}

function hasOwn(value: object, key: string): boolean {
  return Object.prototype.hasOwnProperty.call(value, key);
}

function unique(values: string[]): boolean {
  return new Set(values).size === values.length;
}

export function decodeWebQuizSnapshot(
  raw: unknown,
  totalQuestions: number,
  quizType: string
): { questions: QuizQuestion[]; mode: string } {
  let entries: unknown[];
  let storedMode: (typeof modes)[number] | null | undefined;
  if (Array.isArray(raw)) {
    entries = raw;
  } else {
    const envelope = envelopeSchema.safeParse(raw);
    if (!envelope.success) invalid();
    entries = envelope.data.questions;
    storedMode = envelope.data.mode;
    if (envelope.data.matchingPairs != null && storedMode !== 'matching')
      invalid();
  }
  if (
    !Number.isInteger(totalQuestions) ||
    totalQuestions <= 0 ||
    entries.length !== totalQuestions
  )
    invalid();

  const apiQuestions = entries.map((entry) =>
    apiQuestionSchema.safeParse(entry)
  );
  if (apiQuestions.every((question) => question.success)) {
    if (
      entries.some(
        (entry) =>
          typeof entry === 'object' &&
          entry !== null &&
          hasOwn(entry, 'questionId')
      ) ||
      !unique(apiQuestions.map((question) => question.data.id)) ||
      new Set(apiQuestions.map((question) => question.data.type)).size !== 1
    )
      invalid();
    throw new QuizSnapshotError('unsupported');
  }

  const parsed = entries.map((entry) => webQuestionSchema.safeParse(entry));
  if (
    parsed.some((question) => !question.success) ||
    entries.some(
      (entry) =>
        typeof entry === 'object' && entry !== null && hasOwn(entry, 'id')
    )
  )
    invalid();
  const questions: QuizQuestion[] = [];
  const detectedModes: string[] = [];
  for (const parsedQuestion of parsed) {
    if (!parsedQuestion.success) invalid();
    const question = parsedQuestion.data;
    let mode = quizType === 'CLOZE' ? 'cloze' : 'normal';
    if (question.options.length === 0) {
      if (
        question.koreanSentence &&
        question.japaneseSentence &&
        question.tokens &&
        question.tokens.length > 0 &&
        question.correctOptionId === question.questionId &&
        question.prompt === undefined &&
        question.answer === undefined &&
        unique(question.tokens.map((token) => String(token.order))) &&
        question.tokens.every((token) => token.order < question.tokens!.length)
      ) {
        mode = 'arrange';
      } else if (
        question.prompt &&
        question.answer &&
        question.distractors !== undefined &&
        question.correctOptionId === question.questionId &&
        question.tokens === undefined &&
        question.japaneseSentence === undefined
      ) {
        mode = 'typing';
      } else invalid();
    } else if (
      !unique(question.options.map((option) => option.id)) ||
      !question.options.some(
        (option) => option.id === question.correctOptionId
      ) ||
      question.tokens !== undefined ||
      question.answer !== undefined
    )
      invalid();
    detectedModes.push(mode);
    questions.push({
      ...question,
      questionSubText: question.questionSubText ?? null,
      hint: question.hint ?? null,
      explanation: question.explanation ?? undefined,
    });
  }
  if (
    !unique(questions.map((question) => question.questionId)) ||
    new Set(detectedModes).size !== 1
  )
    invalid();
  const detectedMode = detectedModes[0];
  if (storedMode === 'matching') throw new QuizSnapshotError('unsupported');
  if (
    storedMode != null &&
    storedMode !== detectedMode &&
    !(
      detectedMode === 'normal' &&
      ['review', 'smart', 'wrong_answer_review'].includes(storedMode)
    )
  )
    invalid();
  return { questions, mode: storedMode ?? detectedMode };
}

export function restoreWebQuizProgress<T extends { questionId: string }>(
  questions: T[],
  answeredQuestionIds: string[]
): { questions: T[]; currentIndex: number } {
  if (
    !Array.isArray(answeredQuestionIds) ||
    answeredQuestionIds.some((id) => typeof id !== 'string')
  )
    invalid();
  const ids = new Set(questions.map((question) => question.questionId));
  const answered = new Set(answeredQuestionIds);
  if (answeredQuestionIds.some((id) => !ids.has(id))) invalid();
  const saved = questions.filter((question) =>
    answered.has(question.questionId)
  );
  return {
    questions: [
      ...saved,
      ...questions.filter((question) => !answered.has(question.questionId)),
    ],
    currentIndex: saved.length,
  };
}
