// @vitest-environment node
// Opt in only against the disposable local database provisioned for this suite.
import { randomUUID } from 'node:crypto';
import {
  afterAll,
  afterEach,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
  vi,
} from 'vitest';
import { prisma } from '@harukoto/database';
import { POST as answer } from '@/app/api/v1/quiz/answer/route';
import { POST as complete } from '@/app/api/v1/quiz/complete/route';
import { POST as start } from '@/app/api/v1/quiz/start/route';
import { POST as resume } from '@/app/api/v1/quiz/resume/route';
import { listSavedQuizzes } from '@/lib/quiz-incomplete-sessions';
import { getTodayKST } from '@/lib/date';
import { POST as kanaProgress } from '@/app/api/v1/kana/progress/route';

const auth = vi.hoisted(() => ({ getUser: vi.fn() }));
vi.mock('@/lib/supabase/server', () => ({
  createClient: async () => ({ auth: { getUser: auth.getUser } }),
}));
const enabled = process.env.HARUKOTO_WEB_PG_TESTS === '1';
let userId: string;
let sessionId: string;
let questionId: string;
const request = (body: object) =>
  new Request('http://localhost/api/v1/quiz', {
    method: 'POST',
    body: JSON.stringify(body),
  });
const submit = (
  attemptId: string,
  previousAttemptId: string | null = null,
  selectedOptionId = 'right'
) =>
  answer(
    request({
      sessionId,
      questionId,
      attemptId,
      previousAttemptId,
      selectedOptionId,
      questionType: 'VOCABULARY',
      timeSpentSeconds: 90,
    })
  );
const evidence = async () => ({
  answers: await prisma.quizAnswer.findMany({
    where: { sessionId },
    orderBy: [{ answeredAt: 'asc' }, { id: 'asc' }],
  }),
  session: await prisma.quizSession.findUniqueOrThrow({
    where: { id: sessionId },
  }),
  progress: await prisma.userVocabProgress.findMany({ where: { userId } }),
  day: await prisma.dailyProgress.findMany({ where: { userId } }),
  user: await prisma.user.findUniqueOrThrow({ where: { id: userId } }),
});
const seedPreviousDayAnswer = async () => {
  const previous = new Date(Date.now() - 2 * 86_400_000);
  await prisma.quizAnswer.create({
    data: {
      id: randomUUID(),
      sessionId,
      questionId,
      questionType: 'VOCABULARY',
      selectedOptionId: 'right',
      isCorrect: true,
      timeSpentSeconds: 90,
      answeredAt: previous,
    },
  });
  await prisma.quizSession.update({
    where: { id: sessionId },
    data: { correctCount: 1 },
  });
  await prisma.user.update({
    where: { id: userId },
    data: { lastStudyDate: previous, streakCount: 4, longestStreak: 7 },
  });
  return previous;
};
const startAnotherFixture = async () => {
  const original = await prisma.quizSession.findUniqueOrThrow({
    where: { id: sessionId },
  });
  const extra = await prisma.quizSession.create({
    data: {
      userId,
      quizType: 'VOCABULARY',
      jlptLevel: 'N5',
      totalQuestions: 1,
      questionsData: original.questionsData!,
    },
  });
  return extra.id;
};

describe.runIf(enabled)(
  'real PostgreSQL quiz retention and request races',
  () => {
    beforeAll(async () => {
      const url = new URL(process.env.DATABASE_URL ?? '');
      const local =
        url.port === '65470' && url.pathname === '/quiz_retention_web_tests';
      const ci =
        process.env.GITHUB_ACTIONS === 'true' &&
        process.env.CI === 'true' &&
        url.port === '5432' &&
        url.pathname === '/harukoto_ci';
      if (!['127.0.0.1', 'localhost'].includes(url.hostname) || (!local && !ci))
        throw new Error(
          'Refusing a database outside the dedicated local/CI quiz retention fixture'
        );
      const database = await prisma.$queryRaw<
        { name: string }[]
      >`SELECT current_database() AS name`;
      expect(database[0].name).toBe(
        local ? 'quiz_retention_web_tests' : 'harukoto_ci'
      );
    });
    beforeEach(async () => {
      userId = randomUUID();
      questionId = randomUUID();
      sessionId = randomUUID();
      auth.getUser.mockResolvedValue({ data: { user: { id: userId } } });
      await prisma.user.create({
        data: {
          id: userId,
          email: `${userId}@quiz-retention.invalid`,
          goals: [],
        },
      });
      await prisma.vocabulary.create({
        data: {
          id: questionId,
          jlptLevel: 'N5',
          word: `試験${questionId}`,
          reading: 'しけん',
          meaningKo: '시험',
          partOfSpeech: 'NOUN',
        },
      });
      await prisma.quizSession.create({
        data: {
          id: sessionId,
          userId,
          quizType: 'VOCABULARY',
          jlptLevel: 'N5',
          totalQuestions: 1,
          startedAt: new Date(Date.now() - 30 * 86_400_000),
          questionsData: [
            {
              questionId,
              questionText: '試験',
              options: [
                { id: 'right', text: '시험' },
                { id: 'wrong', text: '음악' },
              ],
              correctOptionId: 'right',
            },
          ],
        },
      });
    });
    afterEach(async () => {
      // Delete only this suite's own fixture IDs; never truncate shared tables.
      if (userId) await prisma.user.deleteMany({ where: { id: userId } });
      if (questionId)
        await prisma.vocabulary.deleteMany({ where: { id: questionId } });
    });
    afterAll(async () => {
      await prisma.$disconnect();
    });

    it('serializes duplicate and stale-tab answers without a second SRS effect', async () => {
      const id = randomUUID();
      const responses = await Promise.all([
        submit(id),
        submit(id),
        submit(randomUUID()),
      ]);
      // Whichever distinct first attempt wins, exactly one logical answer persists.
      expect(
        responses
          .map((response) => response.status)
          .every((status) => status === 200 || status === 409)
      ).toBe(true);
      const before = await evidence();
      expect(before.answers).toHaveLength(1);
      expect(before.session.correctCount).toBe(1);
      expect(before.progress).toHaveLength(1);
      expect(before.progress[0].correctCount).toBe(1);
      expect(before.day).toHaveLength(1);
      expect(before.user.experiencePoints).toBe(0);
      const stored = before.answers[0];
      const replay = await submit(stored.id);
      expect(replay.status).toBe(200);
      expect(await evidence()).toEqual(before);
    });

    it('keeps wrong-to-correct learning attempts while rejecting stale predecessors', async () => {
      const first = randomUUID();
      const second = randomUUID();
      expect((await submit(first, null, 'wrong')).status).toBe(200);
      const before = await evidence();
      expect((await submit(randomUUID(), null)).status).toBe(409);
      expect(await evidence()).toEqual(before);
      expect((await submit(second, first)).status).toBe(200);
      const after = await evidence();
      expect(after.answers).toHaveLength(2);
      expect(after.session.correctCount).toBe(1);
      expect(after.progress[0]).toMatchObject({
        correctCount: 1,
        incorrectCount: 1,
      });
      expect((await submit(randomUUID(), second)).status).toBe(409);
      expect(await evidence()).toEqual(after);
    });

    it('rejects premature completion and resolves concurrent final-answer/completion exactly once', async () => {
      const before = await evidence();
      expect((await complete(request({ sessionId }))).status).toBe(409);
      expect(await evidence()).toEqual(before);
      const id = randomUUID();
      const [completion, saved] = await Promise.all([
        complete(request({ sessionId })),
        submit(id),
      ]);
      expect([200, 409]).toContain(completion.status);
      expect(saved.status).toBe(200);
      expect((await complete(request({ sessionId }))).status).toBe(200);
      const committed = await evidence();
      expect(committed.answers).toHaveLength(1);
      expect(committed.session.completedAt).not.toBeNull();
      expect(committed.user.experiencePoints).toBe(10);
      expect(committed.day[0].quizzesCompleted).toBe(1);
      expect(committed.day[0].studyTimeSeconds).toBe(90);
      expect((await submit(id)).status).toBe(200);
      expect((await complete(request({ sessionId }))).status).toBe(200);
      expect(await evidence()).toEqual(committed);
    });

    it('finds a thirty-day-old quiz behind empty sessions, resumes it and starts another without settling it', async () => {
      expect((await submit(randomUUID(), null, 'wrong')).status).toBe(200);
      await prisma.quizSession.createMany({
        data: Array.from({ length: 25 }, () => ({
          userId,
          quizType: 'VOCABULARY' as const,
          jlptLevel: 'N5' as const,
          totalQuestions: 1,
          questionsData: [],
        })),
      });
      const before = await evidence();
      const list = await listSavedQuizzes(
        userId,
        new URLSearchParams('limit=1')
      );
      expect(list.sessions.map((row) => row.id)).toEqual([sessionId]);
      expect(list.nextCursor).toBeNull();
      expect((await resume(request({ sessionId }))).status).toBe(200);
      expect(await evidence()).toEqual(before);
      const started = await start(
        request({ quizType: 'VOCABULARY', jlptLevel: 'N5', count: 1 })
      );
      expect(started.status).toBe(200);
      expect((await started.json()).sessionId).not.toBe(sessionId);
      expect(await evidence()).toEqual(before);
    });

    it('settles old answers once without creating attendance and promotes only a new saved answer', async () => {
      const previous = await seedPreviousDayAnswer();
      const due = new Date(Date.now() + 7 * 86_400_000);
      await prisma.userVocabProgress.create({
        data: {
          userId,
          vocabularyId: questionId,
          correctCount: 1,
          nextReviewAt: due,
        },
      });
      const beforeRecovery = await evidence();
      expect((await complete(request({ sessionId }))).status).toBe(200);
      const recovered = await evidence();
      expect(recovered.answers).toEqual(beforeRecovery.answers);
      expect(recovered.progress).toEqual(beforeRecovery.progress);
      expect(recovered.day[0]).toMatchObject({
        studyDayCredited: false,
        xpEarned: 10,
        quizzesCompleted: 1,
        wordsStudied: 1,
      });
      expect(recovered.user).toMatchObject({
        lastStudyDate: previous,
        streakCount: 4,
        longestStreak: 7,
      });
      expect((await complete(request({ sessionId }))).status).toBe(200);
      expect(await evidence()).toEqual(recovered);
      const freshSession = await startAnotherFixture();
      expect(
        (
          await answer(
            request({
              sessionId: freshSession,
              questionId,
              attemptId: randomUUID(),
              previousAttemptId: null,
              selectedOptionId: 'wrong',
              questionType: 'VOCABULARY',
            })
          )
        ).status
      ).toBe(200);
      const after = await evidence();
      expect(after.day[0]).toMatchObject({
        studyDayCredited: true,
        activity_recorded: true,
        xpEarned: 10,
        quizzesCompleted: 1,
        wordsStudied: 1,
      });
      expect(after.user.streakCount).toBe(1);
      expect(after.user.longestStreak).toBe(7);
    });

    it.each([null, true, false] as const)(
      'preserves pre-existing day credit %s before completion adds XP',
      async (credit) => {
        const previous = await seedPreviousDayAnswer();
        await prisma.dailyProgress.create({
          data: {
            userId,
            date: getTodayKST(),
            studyDayCredited: credit,
            wordsStudied: 3,
            xpEarned: 20,
          },
        });
        expect((await complete(request({ sessionId }))).status).toBe(200);
        const after = await evidence();
        expect(after.day[0]).toMatchObject({
          studyDayCredited: credit !== false,
          wordsStudied: 4,
          xpEarned: 30,
        });
        expect(after.user).toMatchObject({
          lastStudyDate: previous,
          streakCount: 4,
          longestStreak: 7,
        });
      }
    );

    it('never demotes a concurrent real answer when recovering an old completion', async () => {
      await seedPreviousDayAnswer();
      const freshSession = await startAnotherFixture();
      const responses = await Promise.all([
        complete(request({ sessionId })),
        answer(
          request({
            sessionId: freshSession,
            questionId,
            attemptId: randomUUID(),
            previousAttemptId: null,
            selectedOptionId: 'right',
            questionType: 'VOCABULARY',
          })
        ),
      ]);
      expect(responses.map((response) => response.status)).toEqual([200, 200]);
      const after = await evidence();
      expect(after.day[0]).toMatchObject({
        studyDayCredited: true,
        activity_recorded: true,
        xpEarned: 10,
        quizzesCompleted: 1,
      });
      expect(after.user.experiencePoints).toBe(10);
      expect(after.user.streakCount).toBe(1);
    });

    it('serializes actual kana progress with delayed completion without losing day credit', async () => {
      await seedPreviousDayAnswer();
      const kanaId = randomUUID();
      await prisma.kanaCharacter.create({
        data: {
          id: kanaId,
          kanaType: 'HIRAGANA',
          character: `あ${kanaId}`,
          romaji: 'a',
          pronunciation: '아',
          row: 'a',
          column: 'a',
          strokeCount: 3,
        },
      });
      try {
        const responses = await Promise.all([
          complete(request({ sessionId })),
          kanaProgress(request({ kanaId, learned: true })),
        ]);
        expect(responses.map((response) => response.status)).toEqual([
          200, 200,
        ]);
        const after = await evidence();
        expect(after.day[0]).toMatchObject({
          studyDayCredited: true,
          kanaLearned: 1,
          quizzesCompleted: 1,
          xpEarned: 10,
        });
        expect(
          await prisma.userKanaProgress.findUnique({
            where: { userId_kanaId: { userId, kanaId } },
          })
        ).toMatchObject({ correctCount: 1 });
      } finally {
        await prisma.kanaCharacter.deleteMany({ where: { id: kanaId } });
      }
    });
  }
);
