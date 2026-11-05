// @vitest-environment node
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { POST as answer } from '@/app/api/v1/quiz/answer/route';
import { POST as kanaAnswer } from '@/app/api/v1/kana/quiz/answer/route';
import { PATCH as updateProfile } from '@/app/api/v1/user/profile/route';

const mocks = vi.hoisted(() => ({
  enabled: true,
  getUser: vi.fn(),
  transaction: vi.fn(),
  preflight: vi.fn(),
  tx: {
    $queryRaw: vi.fn(),
    quizSession: { findUnique: vi.fn(), update: vi.fn() },
    quizAnswer: { findFirst: vi.fn(), create: vi.fn(), findUnique: vi.fn() },
    vocabulary: { findMany: vi.fn() },
    grammar: { findMany: vi.fn() },
    userVocabProgress: { findUnique: vi.fn(), upsert: vi.fn() },
    userGrammarProgress: { findUnique: vi.fn(), upsert: vi.fn() },
    userKanaProgress: { findUnique: vi.fn(), upsert: vi.fn(), update: vi.fn() },
    dailyProgress: { upsert: vi.fn(), findUnique: vi.fn() },
    user: { update: vi.fn() },
  },
}));
vi.mock('@harukoto/database', () => ({
  prisma: {
    quizSession: { findUnique: mocks.preflight },
    $transaction: mocks.transaction,
  },
}));
vi.mock('@/lib/supabase/server', () => ({
  createClient: async () => ({ auth: { getUser: mocks.getUser } }),
}));
vi.mock('@/lib/study-day-policy', () => ({
  get ANSWERED_STUDY_DAY_RECOGNITION_ENABLED() {
    return mocks.enabled;
  },
}));

const userId = '10000000-0000-4000-8000-000000000001';
const sessionId = '10000000-0000-4000-8000-000000000002';
const questionId = '10000000-0000-4000-8000-000000000003';
const snapshot = (kana: boolean) => ({
  id: sessionId,
  userId,
  quizType: kana ? 'KANA' : 'VOCABULARY',
  totalQuestions: 1,
  correctCount: 0,
  completedAt: null,
  questionsData: [
    {
      questionId,
      questionText: 'あ',
      options: [
        { id: 'right', text: 'a' },
        { id: 'wrong', text: 'i' },
      ],
      correctOptionId: 'right',
    },
  ],
});
const lockedUser = () => ({
  id: userId,
  experiencePoints: 77,
  level: 1,
  streakCount: 4,
  longestStreak: 9,
  lastStudyDate: new Date('2026-11-01T01:00:00Z'),
  dailyGoal: 10,
  app_settings: null,
});
const attemptId = '10000000-0000-4000-8000-000000000090';
const nextAttemptId = '10000000-0000-4000-8000-000000000091';
const request = (selectedOptionId = 'wrong', previousAttemptId: string | null = null) =>
  new Request('http://localhost/api/v1/quiz/answer', {
    method: 'POST',
    body: JSON.stringify({
      sessionId,
      attemptId: previousAttemptId ? nextAttemptId : attemptId,
      previousAttemptId,
      questionId,
      selectedOptionId,
      timeSpentSeconds: 2,
    }),
  });

beforeEach(() => {
  vi.resetAllMocks();
  vi.useFakeTimers();
  vi.setSystemTime(new Date('2026-11-02T01:00:00.123Z'));
  mocks.enabled = true;
  mocks.getUser.mockResolvedValue({ data: { user: { id: userId } } });
  mocks.tx.$queryRaw.mockResolvedValue([lockedUser()]);
  mocks.tx.quizAnswer.findFirst.mockResolvedValue(null);
  mocks.tx.quizAnswer.findUnique.mockResolvedValue(null);
  for (const reader of [mocks.tx.vocabulary, mocks.tx.grammar]) reader.findMany.mockImplementation(async ({ where }) => where.id.in.map((id: string) => ({ id })));
  mocks.tx.userVocabProgress.findUnique.mockResolvedValue(null);
  mocks.tx.userKanaProgress.findUnique.mockResolvedValue(null);
  mocks.transaction.mockImplementation(
    async (run: (tx: typeof mocks.tx) => Promise<unknown>) => run(mocks.tx)
  );
});
afterEach(() => vi.useRealTimers());

describe('daily goal trophy compatibility', () => {
  const goals = {
    grammar: 5,
    sentence: 15,
    earnedByMonth: { '2026-10': [23], '2026-11': [1] },
  };
  const existingSettings = {
    showFurigana: true,
    dailyCategoryGoalsV1: goals,
  };
  const earnedSettings = {
    ...existingSettings,
    dailyCategoryGoalsV1: {
      ...goals,
      earnedByMonth: { ...goals.earnedByMonth, '2026-11': [1, 2] },
    },
  };

  function mockCount(count: number) {
    mocks.tx.$queryRaw.mockImplementation(async (sql: TemplateStringsArray) =>
      sql.join(' ').includes('COUNT(DISTINCT')
        ? [{ count }]
        : [{ ...lockedUser(), app_settings: existingSettings }]
    );
  }

  it('stores a trophy on an accepted web answer at the word target', async () => {
    mocks.preflight.mockResolvedValue(snapshot(false));
    mocks.tx.quizSession.findUnique.mockResolvedValue(snapshot(false));
    mockCount(10);

    expect((await answer(request())).status).toBe(200);
    const [sql, countedUser, category, start, end] =
      mocks.tx.$queryRaw.mock.calls[2];
    expect(sql.join(' ')).toContain('answer.question_type = session.quiz_type');
    expect(sql.join(' ')).toContain("answer.question_type = 'CLOZE'");
    expect(sql.join(' ')).toContain("'id', answer.question_id::text, 'type', 'CLOZE'");
    expect([countedUser, category, start, end]).toEqual([
      userId,
      'VOCABULARY',
      Date.parse('2026-11-01T15:00:00Z') / 1000,
      Date.parse('2026-11-02T15:00:00Z') / 1000,
    ]);
    expect(mocks.tx.user.update).toHaveBeenLastCalledWith({
      where: { id: userId },
      data: { app_settings: earnedSettings },
    });
  });

  it('credits an intentional wrong retry after KST midnight but does not credit its transport replay', async () => {
    mocks.preflight.mockResolvedValue(snapshot(false));
    mocks.tx.quizSession.findUnique.mockResolvedValue(snapshot(false));
    mockCount(10);
    mocks.tx.quizAnswer.findFirst.mockResolvedValue({
      id: attemptId,
      isCorrect: false,
      answeredAt: new Date('2026-11-02T14:59:59.999Z'),
    });
    vi.setSystemTime(new Date('2026-11-02T15:00:00Z'));

    expect((await answer(request('wrong', attemptId))).status).toBe(200);
    const saved = mocks.tx.quizAnswer.create.mock.calls[0][0].data;
    expect(saved).toMatchObject({ id: nextAttemptId, isCorrect: false });
    expect(mocks.tx.dailyProgress.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          userId_date: { userId, date: new Date('2026-11-03T00:00:00Z') },
        },
        update: { activity_recorded: true, studyDayCredited: true },
      })
    );
    expect(mocks.tx.user.update).toHaveBeenLastCalledWith({
      where: { id: userId },
      data: {
        app_settings: {
          ...existingSettings,
          dailyCategoryGoalsV1: {
            ...goals,
            earnedByMonth: { ...goals.earnedByMonth, '2026-11': [1, 3] },
          },
        },
      },
    });

    mocks.tx.quizAnswer.findUnique.mockResolvedValue(saved);
    vi.setSystemTime(new Date('2026-11-03T15:00:00Z'));
    expect((await answer(request('wrong', attemptId))).status).toBe(200);
    expect(mocks.tx.quizAnswer.create).toHaveBeenCalledTimes(1);
    expect(mocks.tx.dailyProgress.upsert).toHaveBeenCalledTimes(1);
    expect(mocks.tx.user.update).toHaveBeenCalledTimes(2);
  });

  it('awards from the changed word target only when today was a study day', async () => {
    const changeGoal = () =>
      updateProfile(
        new Request('http://localhost/api/v1/user/profile', {
          method: 'PATCH',
          body: JSON.stringify({ dailyGoal: 5 }),
        })
      );
    mockCount(5);
    mocks.tx.dailyProgress.findUnique
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({ studyDayCredited: true });

    expect((await changeGoal()).status).toBe(200);
    expect(mocks.tx.user.update.mock.calls[0][0].data).toEqual({ dailyGoal: 5 });
    expect((await changeGoal()).status).toBe(200);
    expect(mocks.tx.user.update.mock.calls[1][0].data).toEqual({
      dailyGoal: 5,
      app_settings: earnedSettings,
    });
  });
});

describe.each([
  ['normal', answer, false],
  ['kana', kanaAnswer, true],
] as const)('%s answer attendance', (_name, handler, kana) => {
  beforeEach(() => {
    mocks.preflight.mockResolvedValue(snapshot(kana));
    mocks.tx.quizSession.findUnique.mockResolvedValue(snapshot(kana));
  });

  it('atomically recognizes a first wrong answer without awarding XP or completing a goal', async () => {
    expect((await handler(request())).status).toBe(200);
    const saved = mocks.tx.quizAnswer.create.mock.calls[0][0].data;
    expect(saved).toMatchObject({
      isCorrect: false,
      answeredAt: new Date('2026-11-02T01:00:00.123Z'),
    });
    expect(mocks.tx.quizSession.update).not.toHaveBeenCalled();
    expect(mocks.tx.dailyProgress.upsert).toHaveBeenCalledWith({
      where: {
        userId_date: { userId, date: new Date('2026-11-02T00:00:00Z') },
      },
      create: {
        userId,
        date: new Date('2026-11-02T00:00:00Z'),
        activity_recorded: true,
        studyDayCredited: true,
      },
      update: { activity_recorded: true, studyDayCredited: true },
    });
    expect(mocks.tx.user.update).toHaveBeenCalledWith({
      where: { id: userId },
      data: {
        streakCount: 5,
        longestStreak: 9,
        lastStudyDate: saved.answeredAt,
      },
    });
    expect(mocks.transaction).toHaveBeenCalledTimes(1);
  });

  it('preserves same-day wrong-to-correct matching retries and SRS without duplicating attendance', async () => {
    expect((await handler(request())).status).toBe(200);
    mocks.tx.quizAnswer.findFirst.mockResolvedValue({
      id: attemptId,
      isCorrect: false,
      answeredAt: new Date('2026-11-02T01:00:00.123Z'),
    });
    vi.setSystemTime(new Date('2026-11-02T01:00:01Z'));
    expect((await handler(request('right', attemptId))).status).toBe(200);
    expect(mocks.tx.quizAnswer.create).toHaveBeenCalledTimes(2);
    expect(mocks.tx.quizSession.update).toHaveBeenCalledTimes(1);
    expect(
      (kana ? mocks.tx.userKanaProgress : mocks.tx.userVocabProgress).upsert
    ).toHaveBeenCalledTimes(2);
    expect(mocks.tx.dailyProgress.upsert).toHaveBeenCalledTimes(1);
    expect(mocks.tx.user.update).toHaveBeenCalledTimes(1);
  });

  it('does not infer attendance from a same-day pre-activation answer', async () => {
    mocks.tx.quizAnswer.findFirst.mockResolvedValue({
      id: attemptId,
      isCorrect: false,
      answeredAt: new Date('2026-11-02T01:00:00Z'),
    });
    expect((await handler(request('right', attemptId))).status).toBe(200);
    expect(mocks.tx.quizAnswer.create).toHaveBeenCalledTimes(1);
    expect(mocks.tx.dailyProgress.upsert).not.toHaveBeenCalled();
    expect(mocks.tx.user.update).not.toHaveBeenCalled();
  });

  it('keeps the compatibility gate OFF while still saving answers and SRS', async () => {
    mocks.enabled = false;
    expect((await handler(request())).status).toBe(200);
    expect(mocks.tx.quizAnswer.create).toHaveBeenCalledTimes(1);
    expect(mocks.tx.dailyProgress.upsert).not.toHaveBeenCalled();
    expect(mocks.tx.user.update).not.toHaveBeenCalled();
  });

  it('does not acknowledge a failed attendance transaction', async () => {
    mocks.tx.dailyProgress.upsert.mockRejectedValue(
      new Error('day write unavailable')
    );
    const logged = vi.spyOn(console, 'error').mockImplementation(() => {});
    expect((await handler(request())).status).toBe(500);
    expect(mocks.transaction).toHaveBeenCalledTimes(1);
    expect(mocks.tx.user.update).not.toHaveBeenCalled();
    logged.mockRestore();
  });

  it('waits for the user mutex before the session and uses a fresh KST instant', async () => {
    let release!: (value: ReturnType<typeof lockedUser>[]) => void;
    mocks.tx.$queryRaw.mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          release = resolve;
        })
    );
    vi.setSystemTime(new Date('2026-11-02T14:59:59.999Z'));
    const pending = handler(request());
    for (let i = 0; i < 20 && !release; i++) await Promise.resolve();
    expect(release).toBeDefined();
    expect(mocks.tx.quizSession.findUnique).not.toHaveBeenCalled();
    expect(mocks.tx.quizAnswer.create).not.toHaveBeenCalled();
    vi.setSystemTime(new Date('2026-11-02T15:00:00Z'));
    release([lockedUser()]);
    expect((await pending).status).toBe(200);
    const queries = mocks.tx.$queryRaw.mock.calls.map((call) =>
      call[0].join(' ')
    );
    expect(queries[0]).toContain('FOR NO KEY UPDATE');
    expect(queries[1]).toContain('FOR UPDATE');
    expect(mocks.tx.quizAnswer.create.mock.calls[0][0].data.answeredAt).toEqual(
      new Date('2026-11-02T15:00:00Z')
    );
    expect(
      mocks.tx.dailyProgress.upsert.mock.calls[0][0].where.userId_date.date
    ).toEqual(new Date('2026-11-03T00:00:00Z'));
  });

  it('rejects an API-origin serializer before any transaction or answer write', async () => {
    mocks.preflight.mockResolvedValue({
      ...snapshot(kana),
      questionsData: [
        {
          id: questionId,
          type: 'VOCABULARY',
          question: '映画',
          options: [{ id: questionId, text: '영화' }],
          correctOptionId: questionId,
        },
      ],
    });
    expect((await handler(request())).status).toBe(kana ? 400 : 409);
    expect(mocks.transaction).not.toHaveBeenCalled();
  });

  it('does not begin a transaction without authentication', async () => {
    mocks.getUser.mockResolvedValue({ data: { user: null } });
    expect((await handler(request())).status).toBe(401);
    expect(mocks.transaction).not.toHaveBeenCalled();
  });
});

it('refuses a fresh late web answer without changing a finished session', async () => {
  const completed = {
    ...snapshot(false),
    completedAt: new Date('2026-11-01T01:00:00Z'),
  };
  mocks.preflight.mockResolvedValue(completed);
  mocks.tx.quizSession.findUnique.mockResolvedValue(completed);
  expect((await answer(request())).status).toBe(409);
  expect(mocks.tx.quizAnswer.create).not.toHaveBeenCalled();
  expect(mocks.tx.dailyProgress.upsert).not.toHaveBeenCalled();
});
