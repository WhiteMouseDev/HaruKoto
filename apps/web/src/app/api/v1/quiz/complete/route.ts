import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma, type QuizSession } from '@harukoto/database';
import {
  calculateLevel,
  updateStreak,
  checkAndGrantAchievements,
  type GameEvent,
} from '@/lib/gamification';
import { REWARDS } from '@/lib/constants';
import { getTodayKST } from '@/lib/date';
import {
  lockStudyActivityUser,
  preserveNewerStudyDate,
} from '@/lib/study-activity-lock';
import { lockStudyQuizSession } from '@/lib/answered-study-day';
import { completionStudyDayCredit } from '@/lib/quiz-completion-study-day';
import {
  decodeWebQuizSnapshot,
  QuizSnapshotError,
} from '@/lib/quiz-session-snapshot';

function result(
  session: QuizSession,
  totalXp: number,
  events: GameEvent[] = []
) {
  const levelInfo = calculateLevel(totalXp);
  return NextResponse.json({
    sessionId: session.id,
    totalQuestions: session.totalQuestions,
    correctCount: session.correctCount,
    accuracy: Math.round((session.correctCount / session.totalQuestions) * 100),
    // Preserve the existing result display on a replay; no XP is awarded again.
    xpEarned: session.correctCount * REWARDS.QUIZ_XP_PER_CORRECT,
    currentXp: levelInfo.currentXp,
    xpForNext: levelInfo.xpForNext,
    level: levelInfo.level,
    events,
  });
}

function validateSnapshot(session: QuizSession) {
  // Old completed records without a snapshot remain readable. API snapshots
  // stay on their canonical app path before any completion/reward write.
  if (session.questionsData !== null || !session.completedAt) {
    decodeWebQuizSnapshot(
      session.questionsData,
      session.totalQuestions,
      session.quizType
    );
  }
}

export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user)
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    const { sessionId } = await request.json();
    if (!sessionId)
      return NextResponse.json(
        { error: 'sessionId is required' },
        { status: 400 }
      );

    const existing = await prisma.quizSession.findUnique({
      where: { id: sessionId, userId: user.id },
    });
    if (!existing)
      return NextResponse.json(
        { error: '세션을 찾을 수 없습니다' },
        { status: 404 }
      );
    validateSnapshot(existing);
    if (existing.completedAt) {
      const currentUser = await prisma.user.findUnique({
        where: { id: user.id },
        select: { experiencePoints: true },
      });
      return result(existing, currentUser!.experiencePoints);
    }

    return await prisma.$transaction(async (tx) => {
      const currentUser = await lockStudyActivityUser(tx, user.id);
      const locked = await lockStudyQuizSession(tx, sessionId);
      if (!locked || locked.userId !== user.id) {
        return NextResponse.json(
          { error: '세션을 찾을 수 없습니다' },
          { status: 404 }
        );
      }
      validateSnapshot(locked);
      // A competing completion may have committed while this request waited.
      if (locked.completedAt)
        return result(locked, currentUser.experiencePoints);

      // The final answer may still be in flight. Never close the session or
      // award completion rewards until every original question is durable.
      const snapshot = decodeWebQuizSnapshot(
        locked.questionsData,
        locked.totalQuestions,
        locked.quizType
      );
      const savedAnswers = await tx.quizAnswer.findMany({
        where: { sessionId },
        select: { questionId: true, timeSpentSeconds: true, answeredAt: true },
        orderBy: [{ answeredAt: 'asc' }, { id: 'asc' }],
      });
      const firstAnswers = new Map<string, (typeof savedAnswers)[number]>();
      for (const answer of savedAnswers) {
        if (!firstAnswers.has(answer.questionId))
          firstAnswers.set(answer.questionId, answer);
      }
      if (
        snapshot.questions.some(
          (question) => !firstAnswers.has(question.questionId)
        )
      ) {
        return NextResponse.json(
          {
            error:
              '아직 저장되지 않은 답안이 있어요. 답안을 저장한 뒤 다시 시도해 주세요.',
          },
          { status: 409 }
        );
      }

      const now = new Date();
      const today = getTodayKST(now);
      const previousDay = await tx.dailyProgress.findUnique({
        where: { userId_date: { userId: user.id, date: today } },
      });
      const dayCredit = completionStudyDayCredit(
        previousDay,
        snapshot.questions.map(
          (question) => firstAnswers.get(question.questionId)!.answeredAt
        ),
        now
      );
      const session = await tx.quizSession.update({
        where: { id: sessionId },
        data: { completedAt: now },
        include: { answers: true },
      });
      const xpEarned = session.correctCount * REWARDS.QUIZ_XP_PER_CORRECT;
      const studyTimeSeconds = snapshot.questions.reduce(
        (sum, question) =>
          sum +
          Math.max(
            0,
            firstAnswers.get(question.questionId)?.timeSpentSeconds ?? 0
          ),
        0
      );
      await tx.dailyProgress.upsert({
        where: { userId_date: { userId: user.id, date: today } },
        update: {
          studyDayCredited: dayCredit.credited,
          quizzesCompleted: { increment: 1 },
          correctAnswers: { increment: session.correctCount },
          totalAnswers: { increment: session.totalQuestions },
          wordsStudied: { increment: session.totalQuestions },
          xpEarned: { increment: xpEarned },
          studyTimeSeconds: { increment: studyTimeSeconds },
        },
        create: {
          studyDayCredited: dayCredit.credited,
          userId: user.id,
          date: today,
          quizzesCompleted: 1,
          correctAnswers: session.correctCount,
          totalAnswers: session.totalQuestions,
          wordsStudied: session.totalQuestions,
          xpEarned,
          studyTimeSeconds,
        },
      });
      const totalXp = currentUser.experiencePoints + xpEarned;
      const { level: newLevel } = calculateLevel(totalXp);
      const streak = dayCredit.refreshStreak
        ? updateStreak(
            currentUser.lastStudyDate,
            currentUser.streakCount,
            currentUser.longestStreak,
            today
          )
        : {
            streakCount: currentUser.streakCount,
            longestStreak: currentUser.longestStreak,
          };
      await tx.user.update({
        where: { id: user.id },
        data: {
          experiencePoints: totalXp,
          level: newLevel,
          ...(dayCredit.refreshStreak
            ? {
                streakCount: streak.streakCount,
                longestStreak: streak.longestStreak,
                lastStudyDate: preserveNewerStudyDate(
                  currentUser.lastStudyDate,
                  today
                ),
              }
            : {}),
        },
      });
      const [quizCount, wordsAggregate] = await Promise.all([
        tx.quizSession.count({
          where: { userId: user.id, completedAt: { not: null } },
        }),
        tx.dailyProgress.aggregate({
          where: { userId: user.id },
          _sum: { wordsStudied: true },
        }),
      ]);
      const events = await checkAndGrantAchievements(
        user.id,
        {
          totalXp,
          newLevel,
          oldLevel: currentUser.level,
          streakCount: streak.streakCount,
          quizCount,
          isPerfectQuiz:
            session.totalQuestions > 0 &&
            session.correctCount === session.totalQuestions,
          totalWordsStudied: wordsAggregate._sum.wordsStudied ?? 0,
        },
        tx
      );
      if (events.length) {
        await tx.notification.createMany({
          data: events.map((event) => ({
            userId: user.id,
            type: event.type,
            title: event.title,
            body: event.body,
            emoji: event.emoji,
          })),
        });
      }
      return result(session, totalXp, events);
    });
  } catch (err) {
    if (err instanceof QuizSnapshotError)
      return NextResponse.json({ error: err.message }, { status: 409 });
    console.error('Quiz complete error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
