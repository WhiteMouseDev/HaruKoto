// @vitest-environment node
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { POST as startQuiz } from '@/app/api/v1/quiz/start/route';
import { POST as completeQuiz } from '@/app/api/v1/quiz/complete/route';
import { POST as completeKana } from '@/app/api/v1/kana/quiz/complete/route';
import { POST as completeStage } from '@/app/api/v1/kana/stage-complete/route';
import { KANA_REWARDS, REWARDS } from '@/lib/constants';

const mocks = vi.hoisted(() => ({
  getUser: vi.fn(),
  achievements: vi.fn(),
  prisma: {
    quizSession: { findUnique: vi.fn(), findMany: vi.fn() },
    vocabulary: { findMany: vi.fn() },
    kanaLearningStage: { findUnique: vi.fn() },
    user: { findUnique: vi.fn() },
    $transaction: vi.fn(),
  },
}));
vi.mock('@harukoto/database', () => ({ prisma: mocks.prisma }));
vi.mock('@/lib/supabase/server', () => ({
  createClient: async () => ({ auth: { getUser: mocks.getUser } }),
}));
vi.mock('@/lib/gamification', async (original) => ({
  ...(await original<typeof import('@/lib/gamification')>()),
  checkAndGrantAchievements: mocks.achievements,
}));
const userId = '10000000-0000-4000-8000-000000000001';
const sessionId = '10000000-0000-4000-8000-000000000002';
const questionId = '10000000-0000-4000-8000-000000000003';
const stageId = '10000000-0000-4000-8000-000000000004';
const nextId = '10000000-0000-4000-8000-000000000005';
const stage = { id: stageId, kanaType: 'HIRAGANA', stageNumber: 1 };
const event = {
  type: 'achievement',
  title: '학습',
  body: '완료',
  emoji: 'book',
};
const initial = () => ({
  user: {
    id: userId,
    experiencePoints: 70,
    level: 1,
    streakCount: 1,
    longestStreak: 1,
    lastStudyDate: new Date('2026-11-01T01:00:00Z'),
  },
  session: {
    id: sessionId,
    userId,
    quizType: 'KANA',
    totalQuestions: 1,
    correctCount: 1,
    completedAt: null as Date | null,
    questionsData: [
      {
        questionId,
        questionText: 'あ',
        options: [{ id: 'right', text: '아' }],
        correctOptionId: 'right',
      },
    ],
    answers: [{ questionId, isCorrect: true, timeSpentSeconds: 2, answeredAt: new Date() }],
  },
  stages: {} as Record<
    string,
    {
      isCompleted?: boolean;
      isUnlocked?: boolean;
      quizScore?: number;
      completedAt?: Date;
    }
  >,
  daily: [] as Record<string, unknown>[],
  notifications: [] as unknown[],
});
let stored: ReturnType<typeof initial>;
let failure: string | null;
let tail: Promise<unknown>;
let mutationCount: number;
const fault = (operation: string) => {
  if (failure === operation) {
    failure = null;
    throw new Error(`injected ${operation}`);
  }
};
function client(draft: ReturnType<typeof initial>) {
  return {
    $queryRaw: vi.fn(async (parts: TemplateStringsArray) =>
      parts.join('').includes('FROM public.users') ? [draft.user] : []
    ),
    quizSession: {
      findUnique: vi.fn(async () => draft.session),
      update: vi.fn(async ({ data }: { data: { completedAt: Date } }) => {
        mutationCount++;
        Object.assign(draft.session, data);
        fault('session');
        return draft.session;
      }),
      count: vi.fn(async () => 1),
    },
    quizAnswer: { findMany: vi.fn(async () => draft.session.answers) },
    dailyProgress: {
      findUnique: vi.fn(async () => draft.daily[0] ?? null),
      upsert: vi.fn(async ({ create }: { create: Record<string, unknown> }) => {
        mutationCount++;
        draft.daily.push(create);
        fault('daily');
      }),
      aggregate: vi.fn(async () => ({ _sum: { wordsStudied: 1 } })),
    },
    user: {
      update: vi.fn(async ({ data }: { data: Record<string, unknown> }) => {
        mutationCount++;
        const { experiencePoints, ...rest } = data;
        Object.assign(draft.user, rest);
        if (typeof experiencePoints === 'number')
          draft.user.experiencePoints = experiencePoints;
        else if (
          experiencePoints &&
          typeof experiencePoints === 'object' &&
          'increment' in experiencePoints
        ) {
          draft.user.experiencePoints += Number(experiencePoints.increment);
        }
        fault('user');
      }),
    },
    kanaLearningStage: {
      findUnique: vi.fn(async () => ({ id: nextId })),
      count: vi.fn(async () => 10),
    },
    userKanaStage: {
      findUnique: vi.fn(
        async ({ where }: { where: { userId_stageId: { stageId: string } } }) =>
          draft.stages[where.userId_stageId.stageId] ?? null
      ),
      upsert: vi.fn(
        async ({
          where,
          create,
        }: {
          where: { userId_stageId: { stageId: string } };
          create: Record<string, unknown>;
        }) => {
          mutationCount++;
          draft.stages[where.userId_stageId.stageId] = create;
          fault(where.userId_stageId.stageId === stageId ? 'stage' : 'unlock');
        }
      ),
      count: vi.fn(async () => 0),
    },
    userKanaProgress: { count: vi.fn(async () => 0) },
    notification: {
      createMany: vi.fn(async ({ data }: { data: unknown[] }) => {
        mutationCount++;
        draft.notifications.push(...data);
        fault('notification');
      }),
    },
  };
}
const cases = [
  {
    name: 'normal quiz',
    handler: completeQuiz,
    body: { sessionId },
    xp: REWARDS.QUIZ_XP_PER_CORRECT,
    failures: ['session', 'daily', 'user', 'achievement', 'notification'],
  },
  {
    name: 'kana quiz',
    handler: completeKana,
    body: { sessionId },
    xp: REWARDS.QUIZ_XP_PER_CORRECT + KANA_REWARDS.QUIZ_PERFECT_XP,
    failures: ['session', 'daily', 'user', 'achievement', 'notification'],
  },
  {
    name: 'kana stage',
    handler: completeStage,
    body: { stageId, quizScore: 85 },
    xp: KANA_REWARDS.STAGE_COMPLETE_XP,
    failures: [
      'stage',
      'unlock',
      'daily',
      'user',
      'achievement',
      'notification',
    ],
  },
];
const request = (body: object) =>
  new Request('http://localhost/complete', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
beforeEach(() => {
  vi.resetAllMocks();
  vi.useFakeTimers();
  vi.setSystemTime(new Date('2026-11-02T01:00:00Z'));
  vi.spyOn(console, 'error').mockImplementation(() => {});
  stored = initial();
  failure = null;
  mutationCount = 0;
  tail = Promise.resolve();
  mocks.getUser.mockResolvedValue({ data: { user: { id: userId } } });
  mocks.prisma.quizSession.findUnique.mockImplementation(async () =>
    structuredClone(stored.session)
  );
  mocks.prisma.quizSession.findMany.mockImplementation(async () =>
    stored.session.completedAt ? [] : [{ id: sessionId }]
  );
  mocks.prisma.vocabulary.findMany.mockResolvedValue([]);
  mocks.prisma.kanaLearningStage.findUnique.mockResolvedValue(stage);
  mocks.prisma.user.findUnique.mockImplementation(async () =>
    structuredClone(stored.user)
  );
  // Commit and rollback are modeled here; actual row locks/transactions are also
  // verified separately against a disposable PostgreSQL with the real Prisma client.
  mocks.prisma.$transaction.mockImplementation(
    (execute: (tx: ReturnType<typeof client>) => Promise<unknown>) => {
      const operation = tail.then(async () => {
        const draft = structuredClone(stored);
        const response = await execute(client(draft));
        stored = draft;
        return response;
      });
      tail = operation.catch(() => {});
      return operation;
    }
  );
  mocks.achievements.mockImplementation(async (_user, _context, tx) => {
    expect(tx).toHaveProperty('quizSession');
    fault('achievement');
    return [event];
  });
});
afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
});

describe.each(cases)(
  '$name completion atomicity',
  ({ handler, body, xp, failures, name }) => {
    it('commits once and preserves the saved date/score after response loss and next-day replay', async () => {
      expect((await handler(request(body))).status).toBe(200);
      const committed = structuredClone(stored);
      expect(stored.user.experiencePoints).toBe(70 + xp);
      expect(stored.daily).toHaveLength(1);
      expect(stored.notifications).toHaveLength(1);
      mutationCount = 0;
      vi.setSystemTime(new Date('2026-11-03T01:00:00Z'));
      const replay = await handler(request(body));
      expect(replay.status).toBe(200);
      expect((await replay.json()).events).toEqual([]);
      expect(stored).toEqual(committed);
      expect(mutationCount).toBe(0);
    });
    it('rechecks completion after competing requests wait, awarding once', async () => {
      const responses = await Promise.all([
        handler(request(body)),
        handler(request(body)),
      ]);
      expect(responses.map((response) => response.status)).toEqual([200, 200]);
      expect(stored.user.experiencePoints).toBe(70 + xp);
      expect(stored.daily).toHaveLength(1);
      expect(stored.notifications).toHaveLength(1);
      expect(mocks.achievements).toHaveBeenCalledOnce();
    });
    it.each(failures)(
      'rolls back all durable effects after %s fails and retries the same request',
      async (point) => {
        const before = structuredClone(stored);
        failure = point;
        expect((await handler(request(body))).status).toBe(500);
        expect(stored).toEqual(before);
        expect((await handler(request(body))).status).toBe(200);
        expect(stored.user.experiencePoints).toBe(70 + xp);
        expect(stored.daily).toHaveLength(1);
        expect(stored.notifications).toHaveLength(1);
      }
    );
    if (name !== 'kana stage')
      it('retains read-only completed legacy sessions without backfill or rewards', async () => {
        stored.session.completedAt = new Date('2026-10-30T01:00:00Z');
        stored.session.questionsData =
          null as unknown as typeof stored.session.questionsData;
        const before = structuredClone(stored);
        expect((await handler(request(body))).status).toBe(200);
        expect(stored).toEqual(before);
        expect(mutationCount).toBe(0);
      });
  }
);

const startBody = { quizType: 'VOCABULARY', jlptLevel: 'N5', mode: 'matching' };
describe('starting a quiz preserves prior sessions', () => {
  it('leaves old answers, completion and XP untouched even after simultaneous starts with no new content', async () => {
    const before = structuredClone(stored);
    const responses = await Promise.all([startQuiz(request(startBody)), startQuiz(request(startBody))]);
    expect(responses.map((response) => response.status)).toEqual([200, 200]);
    expect(stored).toEqual(before);
    expect(mutationCount).toBe(0);
    expect(mocks.prisma.quizSession.findMany).not.toHaveBeenCalled();
  });
  it.each(['start-first', 'complete-first'])(
    'only explicit completion awards XP when another quiz starts (%s)', async (order) => {
      const start = () => startQuiz(request(startBody));
      const complete = () => completeQuiz(request({ sessionId }));
      const responses = await Promise.all(order === 'start-first' ? [start(), complete()] : [complete(), start()]);
      expect(responses.map((response) => response.status)).toEqual([200, 200]);
      expect(stored.user.experiencePoints).toBe(80);
      expect(stored.daily).toHaveLength(1);
      const committed = structuredClone(stored);
      expect((await completeQuiz(request({ sessionId }))).status).toBe(200);
      expect(stored).toEqual(committed);
    }
  );
});

describe('web completion waits for durable answers', () => {
  it('does not close, reward or count activity before the final answer is stored', async () => {
    stored.session.answers = [];
    const before = structuredClone(stored);
    expect((await completeQuiz(request({ sessionId }))).status).toBe(409);
    expect(stored).toEqual(before);
    expect(mutationCount).toBe(0);
    stored.session.answers = [{ questionId, isCorrect: true, timeSpentSeconds: 2, answeredAt: new Date() }];
    expect((await completeQuiz(request({ sessionId }))).status).toBe(200);
    expect(stored.user.experiencePoints).toBe(80);
  });
  it('does not count duplicate attempts or negative time as additional study time', async () => {
    stored.session.answers = [
      { questionId, isCorrect: false, timeSpentSeconds: 90, answeredAt: new Date() },
      { questionId, isCorrect: true, timeSpentSeconds: 500, answeredAt: new Date() },
    ];
    expect((await completeQuiz(request({ sessionId }))).status).toBe(200);
    expect(stored.daily[0]).toMatchObject({ studyTimeSeconds: 90 });
  });
});
