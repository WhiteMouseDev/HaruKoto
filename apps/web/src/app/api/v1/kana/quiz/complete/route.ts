import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma, type QuizSession } from '@harukoto/database';
import { getTodayKST } from '@/lib/date';
import {
  lockStudyActivityUser,
  preserveNewerStudyDate,
} from '@/lib/study-activity-lock';
import { lockStudyQuizSession } from '@/lib/answered-study-day';
import {
  calculateLevel,
  updateStreak,
  checkAndGrantAchievements,
  type GameEvent,
} from '@/lib/gamification';
import { REWARDS, KANA_REWARDS } from '@/lib/constants';

function reward(session: QuizSession) {
  return (
    session.correctCount * REWARDS.QUIZ_XP_PER_CORRECT +
    (session.quizType === 'KANA' &&
    session.totalQuestions > 0 &&
    session.correctCount === session.totalQuestions
      ? KANA_REWARDS.QUIZ_PERFECT_XP
      : 0)
  );
}

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
    xpEarned: reward(session),
    currentXp: levelInfo.currentXp,
    xpForNext: levelInfo.xpForNext,
    level: levelInfo.level,
    events,
  });
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

    return await prisma.$transaction(async (tx) => {
      const currentUser = await lockStudyActivityUser(tx, user.id);
      const locked = await lockStudyQuizSession(tx, sessionId);
      if (!locked || locked.userId !== user.id)
        return NextResponse.json(
          { error: '세션을 찾을 수 없습니다' },
          { status: 404 }
        );
      if (locked.completedAt)
        return result(locked, currentUser.experiencePoints);

      const now = new Date();
      const today = getTodayKST(now);
      const session = await tx.quizSession.update({
        where: { id: sessionId },
        data: { completedAt: now },
        include: { answers: true },
      });
      const xpEarned = reward(session);
      const studyTimeSeconds = session.answers.reduce(
        (sum, answer) => sum + answer.timeSpentSeconds,
        0
      );
      await tx.dailyProgress.upsert({
        where: { userId_date: { userId: user.id, date: today } },
        update: {
          studyDayCredited: true,
          quizzesCompleted: { increment: 1 },
          correctAnswers: { increment: session.correctCount },
          totalAnswers: { increment: session.totalQuestions },
          xpEarned: { increment: xpEarned },
          studyTimeSeconds: { increment: studyTimeSeconds },
        },
        create: {
          studyDayCredited: true,
          userId: user.id,
          date: today,
          quizzesCompleted: 1,
          correctAnswers: session.correctCount,
          totalAnswers: session.totalQuestions,
          xpEarned,
          studyTimeSeconds,
        },
      });
      const totalXp = currentUser.experiencePoints + xpEarned;
      const { level: newLevel } = calculateLevel(totalXp);
      const streak = updateStreak(
        currentUser.lastStudyDate,
        currentUser.streakCount,
        currentUser.longestStreak,
        today
      );
      await tx.user.update({
        where: { id: user.id },
        data: {
          experiencePoints: totalXp,
          level: newLevel,
          streakCount: streak.streakCount,
          longestStreak: streak.longestStreak,
          lastStudyDate: preserveNewerStudyDate(
            currentUser.lastStudyDate,
            today
          ),
        },
      });
      const quizCount = await tx.quizSession.count({
        where: { userId: user.id, completedAt: { not: null } },
      });
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
        },
        tx
      );
      if (events.length)
        await tx.notification.createMany({
          data: events.map((event) => ({
            userId: user.id,
            type: event.type,
            title: event.title,
            body: event.body,
            emoji: event.emoji,
          })),
        });
      return result(session, totalXp, events);
    });
  } catch (err) {
    console.error('Kana quiz complete error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
