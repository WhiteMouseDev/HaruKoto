import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import {
  calculateLevel,
  updateStreak,
  checkAndGrantAchievements,
  type GameEvent,
} from '@/lib/gamification';

export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
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
      include: {
        answers: true,
      },
    });

    const xpEarned = session.correctCount * 10;

    // 스트릭 계산을 위해 XP 업데이트 전 유저 정보 조회
    const currentUser = await prisma.user.findUniqueOrThrow({
      where: { id: user.id },
    });

    // Update daily progress
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    await prisma.dailyProgress.upsert({
      where: {
        userId_date: { userId: user.id, date: today },
      },
      update: {
        quizzesCompleted: { increment: 1 },
        correctAnswers: { increment: session.correctCount },
        totalAnswers: { increment: session.totalQuestions },
        wordsStudied: { increment: session.totalQuestions },
        xpEarned: { increment: xpEarned },
      },
      create: {
        userId: user.id,
        date: today,
        quizzesCompleted: 1,
        correctAnswers: session.correctCount,
        totalAnswers: session.totalQuestions,
        wordsStudied: session.totalQuestions,
        xpEarned,
      },
    });

    // 게임화 로직
    const totalXp = currentUser.experiencePoints + xpEarned;
    const { level: newLevel } = calculateLevel(totalXp);
    const oldLevel = currentUser.level;

    // 스트릭 업데이트 (XP 업데이트 전 lastStudyDate 기준)
    const streak = updateStreak(
      currentUser.lastStudyDate,
      currentUser.streakCount,
      currentUser.longestStreak
    );

    // 유저 정보 일괄 업데이트 (XP + 레벨 + 스트릭 + lastStudyDate)
    await prisma.user.update({
      where: { id: user.id },
      data: {
        experiencePoints: totalXp,
        level: newLevel,
        streakCount: streak.streakCount,
        longestStreak: streak.longestStreak,
        lastStudyDate: new Date(),
      },
    });

    // 퀴즈 수 + 총 학습 단어 수 조회
    const [quizCount, wordsAggregate] = await Promise.all([
      prisma.quizSession.count({
        where: { userId: user.id, completedAt: { not: null } },
      }),
      prisma.dailyProgress.aggregate({
        where: { userId: user.id },
        _sum: { wordsStudied: true },
      }),
    ]);

    const isPerfectQuiz =
      session.totalQuestions > 0 &&
      session.correctCount === session.totalQuestions;

    const events: GameEvent[] = await checkAndGrantAchievements(user.id, {
      totalXp,
      newLevel,
      oldLevel,
      streakCount: streak.streakCount,
      quizCount,
      isPerfectQuiz,
      totalWordsStudied: wordsAggregate._sum.wordsStudied ?? 0,
    });

    // 이벤트를 알림으로 저장
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

    return NextResponse.json({
      sessionId: session.id,
      totalQuestions: session.totalQuestions,
      correctCount: session.correctCount,
      accuracy: Math.round(
        (session.correctCount / session.totalQuestions) * 100
      ),
      xpEarned,
      events,
    });
  } catch (err) {
    console.error('Quiz complete error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
