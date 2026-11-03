// @vitest-environment node
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { POST } from '@/app/api/v1/quiz/answer/route';

const mocks = vi.hoisted(() => ({
  user: vi.fn(),
  session: vi.fn(),
  transaction: vi.fn(),
}));
vi.mock('@/lib/supabase/server', () => ({
  createClient: async () => ({ auth: { getUser: mocks.user } }),
}));
vi.mock('@harukoto/database', () => ({
  prisma: {
    quizSession: { findUnique: mocks.session },
    $transaction: mocks.transaction,
  },
}));
const userId = '10000000-0000-4000-8000-000000000001';
const sessionId = '10000000-0000-4000-8000-000000000002';
const questionId = '10000000-0000-4000-8000-000000000003';
const attemptId = '10000000-0000-4000-8000-000000000004';
const nextId = '10000000-0000-4000-8000-000000000005';
const lastId = '10000000-0000-4000-8000-000000000006';
type Answer = {
  id: string;
  sessionId: string;
  questionId: string;
  questionType: string;
  selectedOptionId: string;
  isCorrect: boolean;
  timeSpentSeconds: number;
  answeredAt: Date;
};
function initial() {
  return {
    session: {
      id: sessionId,
      userId,
      quizType: 'VOCABULARY',
      totalQuestions: 1,
      correctCount: 0,
      completedAt: null as Date | null,
      questionsData: [
        {
          questionId,
          questionText: '映画',
          options: [
            { id: 'right', text: '영화' },
            { id: 'wrong', text: '음악' },
          ],
          correctOptionId: 'right',
        },
      ],
    },
    user: {
      id: userId,
      experiencePoints: 10,
      level: 1,
      lastStudyDate: null,
      streakCount: 0,
      longestStreak: 0,
    },
    answers: [] as Answer[],
    srsWrites: 0,
    dayWrites: 0,
  };
}
let state = initial();
let tail: Promise<unknown>;
let failSrs: boolean;
function tx(draft: ReturnType<typeof initial>) {
  return {
    $queryRaw: async () => [draft.user],
    quizSession: {
      findUnique: async () => draft.session,
      update: async () => {
        draft.session.correctCount++;
        return draft.session;
      },
    },
    quizAnswer: {
      findUnique: async ({ where }: { where: { id: string } }) =>
        draft.answers.find((answer) => answer.id === where.id) ?? null,
      findFirst: async () => draft.answers.at(-1) ?? null,
      create: async ({ data }: { data: Answer }) => {
        draft.answers.push(data);
        return data;
      },
    },
    vocabulary: { findMany: async () => [{ id: questionId }] },
    grammar: { findMany: async () => [] },
    userVocabProgress: {
      findUnique: async () => null,
      upsert: async () => {
        if (failSrs) throw new Error('save unavailable');
        draft.srsWrites++;
      },
    },
    dailyProgress: {
      upsert: async () => {
        draft.dayWrites++;
      },
    },
    user: { update: async () => {} },
  };
}
function body(overrides: Record<string, unknown> = {}) {
  return {
    sessionId,
    questionId,
    questionType: 'VOCABULARY',
    selectedOptionId: 'wrong',
    timeSpentSeconds: 2,
    attemptId,
    previousAttemptId: null,
    ...overrides,
  };
}
function request(payload: Record<string, unknown> = body()) {
  return new Request('http://localhost/api/v1/quiz/answer', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}
beforeEach(() => {
  vi.resetAllMocks();
  state = initial();
  tail = Promise.resolve();
  failSrs = false;
  mocks.user.mockResolvedValue({ data: { user: { id: userId } } });
  mocks.session.mockImplementation(async () => structuredClone(state.session));
  mocks.transaction.mockImplementation(
    (execute: (client: ReturnType<typeof tx>) => Promise<unknown>) => {
      const operation = tail.then(async () => {
        const draft = structuredClone(state);
        const result = await execute(tx(draft));
        state = draft;
        return result;
      });
      tail = operation.catch(() => {});
      return operation;
    }
  );
});
describe('native web logical attempt idempotency', () => {
  it('acknowledges response-loss replay without another answer, grade, SRS or attendance write', async () => {
    expect(
      (await POST(request(body({ selectedOptionId: 'right' })))).status
    ).toBe(200);
    const before = structuredClone(state);
    const response = await POST(request(body({ selectedOptionId: 'right' })));
    expect(await response.json()).toEqual({
      success: true,
      answerId: attemptId,
    });
    expect(state).toEqual(before);
  });
  it('serializes simultaneous duplicate attempts and stale different-attempt tabs', async () => {
    const results = await Promise.all([
      POST(request()),
      POST(request()),
      POST(request(body({ attemptId: nextId }))),
    ]);
    expect(results.map((response) => response.status)).toEqual([200, 200, 409]);
    expect(state.answers).toHaveLength(1);
    expect(state.srsWrites).toBe(1);
    expect(state.dayWrites).toBe(1);
  });
  it('rejects reusing an attempt ID with different content before any further effects', async () => {
    await POST(request());
    const before = structuredClone(state);
    expect(
      (await POST(request(body({ selectedOptionId: 'right' })))).status
    ).toBe(409);
    expect(state).toEqual(before);
  });
  it('keeps intentional wrong-to-correct attempts, then rejects a fresh answer after the solved pair', async () => {
    await POST(request());
    // Existing persisted timestamps are not edited; wait for real processing time.
    await new Promise((resolve) => setTimeout(resolve, 2));
    expect(
      (
        await POST(
          request(
            body({
              attemptId: nextId,
              previousAttemptId: attemptId,
              selectedOptionId: 'right',
            })
          )
        )
      ).status
    ).toBe(200);
    expect(state.answers).toHaveLength(2);
    expect(state.srsWrites).toBe(2);
    expect(state.dayWrites).toBe(1);
    expect(state.session.correctCount).toBe(1);
    const before = structuredClone(state);
    expect(
      (
        await POST(
          request(
            body({
              attemptId: lastId,
              previousAttemptId: nextId,
              selectedOptionId: 'right',
            })
          )
        )
      ).status
    ).toBe(409);
    expect(state).toEqual(before);
  });
  it('safely replays an already persisted answer after completion but rejects a fresh late answer', async () => {
    await POST(request());
    state.session.completedAt = new Date();
    const before = structuredClone(state);
    expect((await POST(request())).status).toBe(200);
    expect(
      (
        await POST(
          request(body({ attemptId: nextId, previousAttemptId: attemptId }))
        )
      ).status
    ).toBe(409);
    expect(state).toEqual(before);
  });
  it('refuses legacy requests with a refresh instruction and no transaction', async () => {
    const legacy = {
      sessionId,
      questionId,
      questionType: 'VOCABULARY',
      selectedOptionId: 'wrong',
      timeSpentSeconds: 2,
    };
    expect((await POST(request(legacy))).status).toBe(409);
    expect(mocks.transaction).not.toHaveBeenCalled();
    expect(state.answers).toHaveLength(0);
  });
  it('rolls back a failed write and retries the same attempt without partial grade or SRS effects', async () => {
    const log = vi.spyOn(console, 'error').mockImplementation(() => {});
    failSrs = true;
    const before = structuredClone(state);
    expect(
      (await POST(request(body({ selectedOptionId: 'right' })))).status
    ).toBe(500);
    expect(state).toEqual(before);
    failSrs = false;
    expect(
      (await POST(request(body({ selectedOptionId: 'right' })))).status
    ).toBe(200);
    expect(state.answers).toHaveLength(1);
    expect(state.srsWrites).toBe(1);
    expect(state.session.correctCount).toBe(1);
    log.mockRestore();
  });
});
