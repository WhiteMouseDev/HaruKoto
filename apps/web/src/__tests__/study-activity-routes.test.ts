// @vitest-environment node

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { POST as completeQuiz } from '@/app/api/v1/quiz/complete/route';
import { POST as completeKanaQuiz } from '@/app/api/v1/kana/quiz/complete/route';
import { POST as completeKanaStage } from '@/app/api/v1/kana/stage-complete/route';
import { POST as endConversation } from '@/app/api/v1/chat/end/route';
import { POST as completeLiveConversation } from '@/app/api/v1/chat/live-feedback/route';
import { KANA_REWARDS, REWARDS } from '@/lib/constants';

const mocks = vi.hoisted(() => ({
  getUser: vi.fn(),
  achievements: vi.fn(),
  trackAiUsage: vi.fn(),
  generateText: vi.fn(),
  generateObject: vi.fn(),
  tx: {
    $queryRaw: vi.fn(),
    user: { findUniqueOrThrow: vi.fn(), update: vi.fn() },
    dailyProgress: { upsert: vi.fn() },
  },
  prisma: {
    $transaction: vi.fn(),
    quizSession: { findUnique: vi.fn(), update: vi.fn(), count: vi.fn() },
    kanaLearningStage: { findUnique: vi.fn(), count: vi.fn() },
    userKanaStage: { upsert: vi.fn(), count: vi.fn() },
    userKanaProgress: { count: vi.fn() },
    conversation: {
      findUnique: vi.fn(),
      update: vi.fn(),
      create: vi.fn(),
      count: vi.fn(),
    },
    conversationScenario: { findUnique: vi.fn(), findFirst: vi.fn() },
    user: { findUnique: vi.fn(), update: vi.fn() },
    dailyProgress: { aggregate: vi.fn() },
    notification: { create: vi.fn(), createMany: vi.fn() },
  },
}));

vi.mock('@/lib/supabase/server', () => ({
  createClient: async () => ({ auth: { getUser: mocks.getUser } }),
}));
vi.mock('@harukoto/database', () => ({ prisma: mocks.prisma }));
vi.mock('@/lib/gamification', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@/lib/gamification')>()),
  checkAndGrantAchievements: mocks.achievements,
}));
vi.mock('@/lib/rate-limit', () => ({
  rateLimit: () => ({ success: true }),
  RATE_LIMITS: { AI: {} },
}));
vi.mock('@/lib/subscription-service', () => ({
  trackAiUsage: mocks.trackAiUsage,
}));
vi.mock('ai', () => ({
  generateText: mocks.generateText,
  generateObject: mocks.generateObject,
}));
vi.mock('@harukoto/ai', () => ({ getAIProvider: vi.fn() }));

const userId = '10000000-0000-4000-8000-000000000001';
const sessionId = '10000000-0000-4000-8000-000000000002';
const stageId = '10000000-0000-4000-8000-000000000003';
const conversationId = '10000000-0000-4000-8000-000000000004';
const scenarioId = '10000000-0000-4000-8000-000000000005';
const questionId = '10000000-0000-4000-8000-000000000006';

const nativeSession = () => ({
  id: sessionId,
  userId,
  quizType: 'KANA',
  totalQuestions: 1,
  correctCount: 1,
  completedAt: null,
  questionsData: [
    {
      questionId,
      questionText: 'あ',
      questionSubText: null,
      hint: null,
      options: [{ id: 'right', text: '아' }],
      correctOptionId: 'right',
    },
  ],
  answers: [{ timeSpentSeconds: 2 }],
});

const request = (body: Record<string, unknown>) =>
  new Request('http://localhost/api/v1/study-complete', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

const cases = [
  {
    name: 'quiz',
    handler: completeQuiz,
    body: { sessionId },
    xp: REWARDS.QUIZ_XP_PER_CORRECT,
  },
  {
    name: 'kana quiz',
    handler: completeKanaQuiz,
    body: { sessionId },
    xp: REWARDS.QUIZ_XP_PER_CORRECT + KANA_REWARDS.QUIZ_PERFECT_XP,
  },
  {
    name: 'kana stage',
    handler: completeKanaStage,
    body: { stageId },
    xp: KANA_REWARDS.STAGE_COMPLETE_XP,
  },
  {
    name: 'chat',
    handler: endConversation,
    body: { conversationId },
    xp: REWARDS.CONVERSATION_COMPLETE_XP,
  },
  {
    name: 'live chat',
    handler: completeLiveConversation,
    body: {
      transcript: [{ role: 'user', text: 'こんにちは' }],
      durationSeconds: 30,
      scenarioId,
    },
    xp: REWARDS.CONVERSATION_COMPLETE_XP,
  },
] as const;

const currentUser = () => ({
  id: userId,
  experiencePoints: 70,
  level: 1,
  lastStudyDate: new Date('2026-11-01T15:00:00.100Z'),
  streakCount: 6,
  longestStreak: 8,
});

beforeEach(() => {
  vi.resetAllMocks();
  vi.useFakeTimers();
  vi.setSystemTime(new Date('2026-11-01T14:59:59.500Z'));
  vi.spyOn(console, 'error').mockImplementation(() => {});
  mocks.getUser.mockResolvedValue({ data: { user: { id: userId } } });
  mocks.prisma.$transaction.mockImplementation(
    (execute: (tx: typeof mocks.tx) => Promise<unknown>) => execute(mocks.tx)
  );
  mocks.tx.$queryRaw.mockResolvedValue([currentUser()]);
  mocks.prisma.quizSession.findUnique.mockResolvedValue(nativeSession());
  mocks.prisma.quizSession.update.mockResolvedValue(nativeSession());
  mocks.prisma.quizSession.count.mockResolvedValue(1);
  mocks.prisma.dailyProgress.aggregate.mockResolvedValue({
    _sum: { wordsStudied: 1 },
  });
  mocks.prisma.kanaLearningStage.findUnique
    .mockResolvedValueOnce({
      id: stageId,
      kanaType: 'HIRAGANA',
      stageNumber: 1,
    })
    .mockResolvedValue(null);
  mocks.prisma.kanaLearningStage.count.mockResolvedValue(10);
  mocks.prisma.userKanaStage.count.mockResolvedValue(0);
  mocks.prisma.userKanaProgress.count.mockResolvedValue(0);
  mocks.prisma.conversation.findUnique.mockResolvedValue({
    id: conversationId,
    userId,
    endedAt: null,
    createdAt: new Date('2026-11-01T14:59:00Z'),
    messages: [{ role: 'user', content: 'こんにちは' }],
  });
  mocks.prisma.conversation.create.mockResolvedValue({ id: conversationId });
  mocks.prisma.conversation.count.mockResolvedValue(1);
  mocks.prisma.conversationScenario.findUnique.mockResolvedValue({
    id: scenarioId,
  });
  mocks.achievements.mockResolvedValue([]);
});

afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
});

describe.each(cases)(
  '$name shared study activity serialization',
  ({ handler, body, xp }) => {
    it('waits for the user lock, then uses the latest counters and Korean day', async () => {
      let release!: (users: ReturnType<typeof currentUser>[]) => void;
      mocks.tx.$queryRaw.mockImplementation(
        () =>
          new Promise<ReturnType<typeof currentUser>[]>((resolve) => {
            release = resolve;
          })
      );
      const pending = handler(request(body));
      await vi.waitFor(() => expect(mocks.tx.$queryRaw).toHaveBeenCalledOnce());

      // A lesson can finish while this request waits across Korean midnight.
      // No daily or user mutation is allowed before the same user lock is held.
      expect(mocks.tx.dailyProgress.upsert).not.toHaveBeenCalled();
      expect(mocks.tx.user.update).not.toHaveBeenCalled();
      expect(mocks.tx.user.findUniqueOrThrow).not.toHaveBeenCalled();
      const [parts, parameter] = mocks.tx.$queryRaw.mock.calls[0];
      const sql = (parts as TemplateStringsArray)
        .join('$1')
        .replace(/\s+/g, ' ');
      expect(sql).toContain('FROM public.users');
      expect(sql).toContain('WHERE id = $1::uuid FOR NO KEY UPDATE');
      expect(sql).not.toContain(userId);
      expect(parameter).toBe(userId);

      vi.setSystemTime(new Date('2026-11-01T15:00:00.250Z'));
      release([currentUser()]);
      const response = await pending;
      expect(response.status).toBe(200);
      expect(mocks.tx.user.update).toHaveBeenCalledOnce();
      expect(mocks.tx.user.update).toHaveBeenCalledWith({
        where: { id: userId },
        data: expect.objectContaining({
          experiencePoints: 70 + xp,
          streakCount: 6,
          longestStreak: 8,
          lastStudyDate: new Date('2026-11-02T00:00:00Z'),
        }),
      });
      const dayWrite = mocks.tx.dailyProgress.upsert.mock.calls[0][0];
      expect(dayWrite.where.userId_date).toEqual({
        userId,
        date: new Date('2026-11-02T00:00:00Z'),
      });
      expect(dayWrite.update.xpEarned).toEqual({ increment: xp });
      expect(dayWrite.update).not.toHaveProperty('activity_recorded');
      expect(dayWrite.update).not.toHaveProperty('lessonCompleted');
      expect(mocks.generateText).not.toHaveBeenCalled();
      expect(mocks.generateObject).not.toHaveBeenCalled();
    });

    it('does not write rewards when acquiring the user lock fails', async () => {
      mocks.tx.$queryRaw.mockRejectedValue(new Error('lock unavailable'));
      const response = await handler(request(body));
      expect(response.status).toBe(500);
      expect(mocks.tx.dailyProgress.upsert).not.toHaveBeenCalled();
      expect(mocks.tx.user.update).not.toHaveBeenCalled();
      expect(mocks.achievements).not.toHaveBeenCalled();
    });

    it('keeps a newer stored study day and its counters for a delayed older clock', async () => {
      const newerDay = new Date('2026-11-03T00:00:00Z');
      mocks.tx.$queryRaw.mockResolvedValue([
        { ...currentUser(), lastStudyDate: newerDay },
      ]);
      vi.setSystemTime(new Date('2026-11-01T15:00:00.250Z'));
      const response = await handler(request(body));
      expect(response.status).toBe(200);
      expect(mocks.tx.user.update).toHaveBeenCalledWith({
        where: { id: userId },
        data: expect.objectContaining({
          experiencePoints: 70 + xp,
          streakCount: 6,
          longestStreak: 8,
          lastStudyDate: newerDay,
        }),
      });
    });

    it('does not access study records or locks for an unauthenticated request', async () => {
      mocks.getUser.mockResolvedValue({ data: { user: null } });
      const response = await handler(request(body));
      expect(response.status).toBe(401);
      expect(mocks.prisma.$transaction).not.toHaveBeenCalled();
      expect(mocks.tx.$queryRaw).not.toHaveBeenCalled();
      expect(mocks.prisma.quizSession.findUnique).not.toHaveBeenCalled();
      expect(mocks.prisma.quizSession.update).not.toHaveBeenCalled();
      expect(mocks.prisma.userKanaStage.upsert).not.toHaveBeenCalled();
      expect(mocks.prisma.conversation.findUnique).not.toHaveBeenCalled();
      expect(mocks.prisma.conversation.create).not.toHaveBeenCalled();
    });
  }
);
