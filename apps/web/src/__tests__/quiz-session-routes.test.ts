import { beforeEach, describe, expect, it, vi } from 'vitest';
import { POST as resume } from '@/app/api/v1/quiz/resume/route';
import { POST as answer } from '@/app/api/v1/quiz/answer/route';
import { POST as complete } from '@/app/api/v1/quiz/complete/route';
import {
  QUIZ_SNAPSHOT_INVALID_MESSAGE,
  QUIZ_WEB_UNSUPPORTED_MESSAGE,
} from '@/lib/quiz-session-snapshot';

const mocks = vi.hoisted(() => {
  const tx = {
    user: { findUniqueOrThrow: vi.fn(), update: vi.fn() },
    dailyProgress: { upsert: vi.fn() },
  };
  return {
    getUser: vi.fn(),
    tx,
    prisma: {
      quizSession: { findUnique: vi.fn(), update: vi.fn(), count: vi.fn() },
      quizAnswer: { create: vi.fn() },
      userVocabProgress: { findUnique: vi.fn(), upsert: vi.fn() },
      userGrammarProgress: { findUnique: vi.fn(), upsert: vi.fn() },
      user: { findUnique: vi.fn(), update: vi.fn() },
      dailyProgress: { aggregate: vi.fn(), upsert: vi.fn() },
      notification: { createMany: vi.fn() },
      $transaction: vi.fn(),
    },
    achievements: vi.fn(),
  };
});
vi.mock('@/lib/supabase/server', () => ({
  createClient: async () => ({ auth: { getUser: mocks.getUser } }),
}));
vi.mock('@harukoto/database', () => ({ prisma: mocks.prisma }));
vi.mock('@/lib/gamification', () => ({
  calculateLevel: () => ({ level: 1, currentXp: 10, xpForNext: 100 }),
  updateStreak: () => ({ streakCount: 1, longestStreak: 1 }),
  checkAndGrantAchievements: mocks.achievements,
}));

const userId = '10000000-0000-4000-8000-000000000001';
const sessionId = '10000000-0000-4000-8000-000000000002';
const questionId = '10000000-0000-4000-8000-000000000003';
const otherId = '10000000-0000-4000-8000-000000000004';
const thirdId = '10000000-0000-4000-8000-000000000005';
const pairId = '10000000-0000-4000-8000-000000000006';
const nativeQuestion = (id = questionId) => ({
  questionId: id,
  questionText: '映画',
  questionSubText: 'えいが',
  hint: null,
  options: [
    { id: 'right', text: '영화' },
    { id: 'wrong', text: '음악' },
  ],
  correctOptionId: 'right',
});
const apiQuestion = () => ({
  id: questionId,
  type: 'VOCABULARY',
  question: '映画',
  options: [
    { id: pairId, text: '영화' },
    { id: otherId, text: '음악' },
  ],
  correctOptionId: pairId,
});
const nativeSession = () => ({
  id: sessionId,
  userId,
  quizType: 'VOCABULARY',
  totalQuestions: 1,
  correctCount: 0,
  completedAt: null,
  questionsData: [nativeQuestion()],
  answers: [],
});
const request = (body: Record<string, unknown>) =>
  new Request('http://localhost/api/v1/quiz', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
const answerBody = (
  questionType = 'VOCABULARY',
  selectedOptionId = 'right'
) => ({
  sessionId,
  questionId,
  selectedOptionId,
  questionType,
  timeSpentSeconds: 2,
});
const writes = () => [
  mocks.prisma.quizSession.update,
  mocks.prisma.quizAnswer.create,
  mocks.prisma.userVocabProgress.upsert,
  mocks.prisma.userGrammarProgress.upsert,
  mocks.prisma.user.update,
  mocks.prisma.dailyProgress.upsert,
  mocks.prisma.notification.createMany,
  mocks.prisma.$transaction,
  mocks.tx.user.update,
  mocks.tx.dailyProgress.upsert,
];
const noWrites = () =>
  writes().forEach((write) => expect(write).not.toHaveBeenCalled());

beforeEach(() => {
  vi.resetAllMocks();
  mocks.getUser.mockResolvedValue({ data: { user: { id: userId } } });
  mocks.prisma.quizSession.findUnique.mockResolvedValue(nativeSession());
  mocks.prisma.userVocabProgress.findUnique.mockResolvedValue(null);
  mocks.prisma.userGrammarProgress.findUnique.mockResolvedValue(null);
  mocks.prisma.quizSession.count.mockResolvedValue(1);
  mocks.prisma.dailyProgress.aggregate.mockResolvedValue({
    _sum: { wordsStudied: 1 },
  });
  mocks.tx.user.findUniqueOrThrow.mockResolvedValue({
    experiencePoints: 0,
    level: 1,
    lastStudyDate: null,
    streakCount: 0,
    longestStreak: 0,
  });
  mocks.prisma.$transaction.mockImplementation(
    async (execute: (tx: typeof mocks.tx) => Promise<unknown>) =>
      execute(mocks.tx)
  );
  mocks.achievements.mockResolvedValue([]);
});

const apiCases = [
  ['API multiple choice array', [apiQuestion()]],
  ['API normal envelope', { mode: 'normal', questions: [apiQuestion()] }],
  ['API smart envelope', { mode: 'smart', questions: [apiQuestion()] }],
  [
    'API wrong-review envelope',
    {
      mode: 'wrong_answer_review',
      source_session_id: thirdId,
      questions: [apiQuestion()],
    },
  ],
  [
    'API legacy matching',
    [{ ...apiQuestion(), options: [], word: '映画', meaningKo: '영화' }],
  ],
  [
    'API new matching',
    {
      mode: 'matching',
      questions: [{ ...apiQuestion(), options: [] }],
      matchingPairs: [{ id: pairId, word: '映画', meaning: '영화' }],
    },
  ],
  [
    'API legacy arrange',
    [
      {
        ...apiQuestion(),
        type: 'SENTENCE_ARRANGE',
        options: [],
        correctOptionId: '',
        japaneseSentence: '映画を見ます',
        tokens: ['映画', 'を', '見ます'],
      },
    ],
  ],
  [
    'API new arrange',
    {
      mode: 'arrange',
      questions: [
        {
          ...apiQuestion(),
          type: 'SENTENCE_ARRANGE',
          options: [],
          correctOptionId: '',
          japaneseSentence: '映画を見ます',
          tokens: ['映画', 'を', '見ます'],
        },
      ],
    },
  ],
] as const;

describe.each([
  ['resume', resume],
  ['answer', answer],
  ['complete', complete],
] as const)('%s BFF preservation guard', (name, handler) => {
  it.each(apiCases)(
    'refuses %s before any session, answer, SRS or XP write',
    async (_, questionsData) => {
      const session = { ...nativeSession(), questionsData };
      const before = JSON.stringify(session);
      mocks.prisma.quizSession.findUnique.mockResolvedValue(session);
      const response = await handler(
        request(name === 'answer' ? answerBody() : { sessionId })
      );
      expect(response.status).toBe(409);
      expect(await response.json()).toEqual({
        error: QUIZ_WEB_UNSUPPORTED_MESSAGE,
      });
      noWrites();
      expect(JSON.stringify(session)).toBe(before);
    }
  );

  it('refuses a full-length mixed serializer without changing the stored rows', async () => {
    mocks.prisma.quizSession.findUnique.mockResolvedValue({
      ...nativeSession(),
      totalQuestions: 2,
      questionsData: [nativeQuestion(), { ...apiQuestion(), id: otherId }],
    });
    const response = await handler(
      request(name === 'answer' ? answerBody() : { sessionId })
    );
    expect(response.status).toBe(409);
    expect(await response.json()).toEqual({
      error: QUIZ_SNAPSHOT_INVALID_MESSAGE,
    });
    noWrites();
  });

  it('keeps authentication before the snapshot/record lookup', async () => {
    mocks.getUser.mockResolvedValue({ data: { user: null } });
    expect(
      (await handler(request(name === 'answer' ? answerBody() : { sessionId })))
        .status
    ).toBe(401);
    expect(mocks.prisma.quizSession.findUnique).not.toHaveBeenCalled();
    noWrites();
  });
});

describe('native web resume', () => {
  it('returns the native envelope as an array with original IDs and canonical first saved answers', async () => {
    const session = {
      ...nativeSession(),
      totalQuestions: 3,
      questionsData: {
        mode: 'review',
        questions: [
          nativeQuestion(),
          nativeQuestion(otherId),
          nativeQuestion(thirdId),
        ],
      },
      answers: [
        { questionId: thirdId, isCorrect: true },
        { questionId: thirdId, isCorrect: false },
        { questionId, isCorrect: false },
      ],
    };
    const before = JSON.stringify(session);
    mocks.prisma.quizSession.findUnique.mockResolvedValue(session);
    const response = await resume(request({ sessionId }));
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      questions: session.questionsData.questions,
      mode: 'review',
      answeredQuestionIds: [thirdId, questionId],
      correctCount: 1,
      totalQuestions: 3,
    });
    expect(JSON.stringify(session)).toBe(before);
    noWrites();
  });

  it('rejects a saved answer for a different snapshot', async () => {
    mocks.prisma.quizSession.findUnique.mockResolvedValue({
      ...nativeSession(),
      answers: [{ questionId: otherId, isCorrect: true }],
    });
    expect((await resume(request({ sessionId }))).status).toBe(409);
    noWrites();
  });

  it('keeps missing/completed session statuses without a write', async () => {
    mocks.prisma.quizSession.findUnique.mockResolvedValueOnce(null);
    expect((await resume(request({ sessionId }))).status).toBe(404);
    mocks.prisma.quizSession.findUnique.mockResolvedValueOnce({
      ...nativeSession(),
      completedAt: new Date(),
    });
    expect((await resume(request({ sessionId }))).status).toBe(400);
    noWrites();
  });
});

describe('native web answers', () => {
  it.each(['VOCABULARY', 'GRAMMAR', 'CLOZE'])(
    'keeps the existing %s grading and SRS branch',
    async (questionType) => {
      mocks.prisma.quizSession.findUnique.mockResolvedValue({
        ...nativeSession(),
        quizType: questionType,
      });
      const response = await answer(request(answerBody(questionType)));
      expect(response.status).toBe(200);
      expect(mocks.prisma.quizAnswer.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          questionId,
          selectedOptionId: 'right',
          isCorrect: true,
          questionType,
        }),
      });
      expect(mocks.prisma.quizSession.update).toHaveBeenCalledWith({
        where: { id: sessionId },
        data: { correctCount: { increment: 1 } },
      });
      expect(mocks.prisma.userVocabProgress.upsert).toHaveBeenCalledTimes(
        questionType === 'VOCABULARY' ? 1 : 0
      );
      expect(mocks.prisma.userGrammarProgress.upsert).toHaveBeenCalledTimes(
        questionType === 'GRAMMAR' ? 1 : 0
      );
    }
  );

  it('keeps native typing answers', async () => {
    const question = {
      ...nativeQuestion(),
      options: [],
      correctOptionId: questionId,
      prompt: '영화',
      answer: 'えいが',
      distractors: ['か'],
    };
    mocks.prisma.quizSession.findUnique.mockResolvedValue({
      ...nativeSession(),
      questionsData: [question],
    });
    expect(
      (await answer(request(answerBody('VOCABULARY', questionId)))).status
    ).toBe(200);
    expect(mocks.prisma.quizAnswer.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ isCorrect: true }),
    });
    expect(mocks.prisma.userVocabProgress.upsert).toHaveBeenCalledTimes(1);
  });

  it('keeps native arrange answers and does not create a vocabulary SRS row', async () => {
    const question = {
      ...nativeQuestion(),
      options: [],
      correctOptionId: questionId,
      koreanSentence: '영화를 봅니다',
      japaneseSentence: '映画を見ます',
      tokens: [{ text: '映画', type: 'noun', meaning: '영화', order: 0 }],
    };
    mocks.prisma.quizSession.findUnique.mockResolvedValue({
      ...nativeSession(),
      quizType: 'SENTENCE_ARRANGE',
      questionsData: [question],
    });
    expect(
      (await answer(request(answerBody('SENTENCE_ARRANGE', questionId)))).status
    ).toBe(200);
    expect(mocks.prisma.quizAnswer.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ isCorrect: true }),
    });
    expect(mocks.prisma.userVocabProgress.upsert).not.toHaveBeenCalled();
    expect(mocks.prisma.userGrammarProgress.upsert).not.toHaveBeenCalled();
  });

  it('refuses another user before revealing or parsing their snapshot', async () => {
    mocks.prisma.quizSession.findUnique.mockResolvedValue({
      ...nativeSession(),
      userId: otherId,
    });
    expect((await answer(request(answerBody()))).status).toBe(403);
    noWrites();
  });

  it('does not store a fabricated question ID as a wrong answer', async () => {
    expect(
      (await answer(request({ ...answerBody(), questionId: otherId }))).status
    ).toBe(409);
    noWrites();
  });
});

describe('native web completion', () => {
  it('keeps the existing completion transaction for a supported native snapshot', async () => {
    mocks.prisma.quizSession.findUnique.mockResolvedValue({
      ...nativeSession(),
      correctCount: 1,
    });
    mocks.prisma.quizSession.update.mockResolvedValue({
      ...nativeSession(),
      correctCount: 1,
      answers: [{ timeSpentSeconds: 2 }],
    });
    const response = await complete(request({ sessionId }));
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      totalQuestions: 1,
      correctCount: 1,
      xpEarned: 10,
    });
    expect(mocks.prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(mocks.tx.dailyProgress.upsert).toHaveBeenCalledTimes(1);
    expect(mocks.tx.user.update).toHaveBeenCalledTimes(1);
  });

  it('keeps the cached result for old completed native records without a snapshot', async () => {
    mocks.prisma.quizSession.findUnique.mockResolvedValue({
      ...nativeSession(),
      correctCount: 1,
      completedAt: new Date(),
      questionsData: null,
    });
    mocks.prisma.user.findUnique.mockResolvedValue({ experiencePoints: 100 });
    const response = await complete(request({ sessionId }));
    expect(response.status).toBe(200);
    noWrites();
  });
});
