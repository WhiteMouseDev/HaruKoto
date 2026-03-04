import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import {
  calculateLevel,
  updateStreak,
  checkAndGrantAchievements,
  type GameEvent,
} from '@/lib/gamification';
import { REWARDS, KANA_REWARDS } from '@/lib/constants';

export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const body = await request.json();
    const { sessionId } = body;

    if (!sessionId) {
      return NextResponse.json(
        { error: 'sessionId is required' },
        { status: 400 }
      );
    }

    // Complete session
    const session = await prisma.quizSession.update({
      where: { id: sessionId, userId: user.id },
      data: { completedAt: new Date() },
      include: { answers: true },
    });

    const isKanaQuiz = session.quizType === 'KANA';
    const isPerfect =
      session.totalQuestions > 0 &&
      session.correctCount === session.totalQuestions;

    const studyTimeSeconds = session.answers.reduce(
      (sum, a) => sum + a.timeSpentSeconds,
      0
    );

    let xpEarned = session.correctCount * REWARDS.QUIZ_XP_PER_CORRECT;
    if (isKanaQuiz && isPerfect) {
      xpEarned += KANA_REWARDS.QUIZ_PERFECT_XP;
    }

    // Gamification transaction
    const { totalXp, newLevel, oldLevel, streak } =
      await prisma.$transaction(async (tx) => {
        const currentUser = await tx.user.findUniqueOrThrow({
          where: { id: user.id },
        });

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        await tx.dailyProgress.upsert({
          where: { userId_date: { userId: user.id, date: today } },
          update: {
            quizzesCompleted: { increment: 1 },
            correctAnswers: { increment: session.correctCount },
            totalAnswers: { increment: session.totalQuestions },
            xpEarned: { increment: xpEarned },
            studyTimeSeconds: { increment: studyTimeSeconds },
          },
          create: {
            userId: user.id,
            date: today,
            quizzesCompleted: 1,
            correctAnswers: session.correctCount,
            totalAnswers: session.totalQuestions,
            xpEarned,
            studyTimeSeconds,
          },
        });

        const txTotalXp = currentUser.experiencePoints + xpEarned;
        const { level: txNewLevel } = calculateLevel(txTotalXp);
        const txOldLevel = currentUser.level;

        const txStreak = updateStreak(
          currentUser.lastStudyDate,
          currentUser.streakCount,
          currentUser.longestStreak
        );

        await tx.user.update({
          where: { id: user.id },
          data: {
            experiencePoints: txTotalXp,
            level: txNewLevel,
            streakCount: txStreak.streakCount,
            longestStreak: txStreak.longestStreak,
            lastStudyDate: new Date(),
          },
        });

        return {
          totalXp: txTotalXp,
          newLevel: txNewLevel,
          oldLevel: txOldLevel,
          streak: txStreak,
        };
      });

    const isPerfectQuiz =
      session.totalQuestions > 0 &&
      session.correctCount === session.totalQuestions;

    const [quizCount] = await Promise.all([
      prisma.quizSession.count({
        where: { userId: user.id, completedAt: { not: null } },
      }),
    ]);

    const events: GameEvent[] = await checkAndGrantAchievements(user.id, {
      totalXp,
      newLevel,
      oldLevel,
      streakCount: streak.streakCount,
      quizCount,
      isPerfectQuiz,
    });

    // Save notifications
    for (const event of events) {
      await prisma.notification.create({
        data: {
          userId: user.id,
          type: event.type,
          title: event.title,
          body: event.body,
          emoji: event.emoji,
        },
      });
    }

    const levelInfo = calculateLevel(totalXp);

    return NextResponse.json({
      sessionId: session.id,
      totalQuestions: session.totalQuestions,
      correctCount: session.correctCount,
      accuracy: Math.round(
        (session.correctCount / session.totalQuestions) * 100
      ),
      xpEarned,
      currentXp: levelInfo.currentXp,
      xpForNext: levelInfo.xpForNext,
      level: levelInfo.level,
      events,
    });
  } catch (err) {
    console.error('Kana quiz complete error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
