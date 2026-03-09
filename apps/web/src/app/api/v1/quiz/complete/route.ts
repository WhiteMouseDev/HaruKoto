import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import {
  calculateLevel,
  updateStreak,
  checkAndGrantAchievements,
  type GameEvent,
} from '@/lib/gamification';
import { REWARDS } from '@/lib/constants';
import { getTodayKST } from '@/lib/date';

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

    // 멱등성: 이미 완료된 세션이면 기존 결과 반환
    const existingSession = await prisma.quizSession.findUnique({
      where: { id: sessionId, userId: user.id },
    });
    if (!existingSession) {
      return NextResponse.json(
        { error: '세션을 찾을 수 없습니다' },
        { status: 404 }
      );
    }
    if (existingSession.completedAt) {
      const levelInfo = calculateLevel(
        (await prisma.user.findUnique({ where: { id: user.id }, select: { experiencePoints: true } }))!.experiencePoints
      );
      return NextResponse.json({
        sessionId: existingSession.id,
        totalQuestions: existingSession.totalQuestions,
        correctCount: existingSession.correctCount,
        accuracy: Math.round(
          (existingSession.correctCount / existingSession.totalQuestions) * 100
        ),
        xpEarned: existingSession.correctCount * REWARDS.QUIZ_XP_PER_CORRECT,
        currentXp: levelInfo.currentXp,
        xpForNext: levelInfo.xpForNext,
        level: levelInfo.level,
        events: [],
      });
    }

    // Complete session
    const session = await prisma.quizSession.update({
      where: { id: sessionId, userId: user.id },
      data: { completedAt: new Date() },
      include: {
        answers: true,
      },
    });

    const xpEarned = session.correctCount * REWARDS.QUIZ_XP_PER_CORRECT;
    const studyTimeSeconds = session.answers.reduce(
      (sum, a) => sum + a.timeSpentSeconds,
      0
    );

    // 게임화 로직을 트랜잭션으로 감싸서 레이스 컨디션 방지
    const { totalXp, newLevel, oldLevel, streak } = await prisma.$transaction(async (tx) => {
      const currentUser = await tx.user.findUniqueOrThrow({
        where: { id: user.id },
      });

      const today = getTodayKST();

      await tx.dailyProgress.upsert({
        where: {
          userId_date: { userId: user.id, date: today },
        },
        update: {
          quizzesCompleted: { increment: 1 },
          correctAnswers: { increment: session.correctCount },
          totalAnswers: { increment: session.totalQuestions },
          wordsStudied: { increment: session.totalQuestions },
          xpEarned: { increment: xpEarned },
          studyTimeSeconds: { increment: studyTimeSeconds },
        },
        create: {
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

      const txTotalXp = currentUser.experiencePoints + xpEarned;
      const { level: txNewLevel } = calculateLevel(txTotalXp);
      const txOldLevel = currentUser.level;

      const txStreak = updateStreak(
        currentUser.lastStudyDate,
        currentUser.streakCount,
        currentUser.longestStreak,
        today
      );

      await tx.user.update({
        where: { id: user.id },
        data: {
          experiencePoints: txTotalXp,
          level: txNewLevel,
          streakCount: txStreak.streakCount,
          longestStreak: txStreak.longestStreak,
          lastStudyDate: today,
        },
      });

      return { totalXp: txTotalXp, newLevel: txNewLevel, oldLevel: txOldLevel, streak: txStreak };
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
    if (events.length > 0) {
      await prisma.notification.createMany({
        data: events.map((event) => ({
          userId: user.id,
          type: event.type,
          title: event.title,
          body: event.body,
          emoji: event.emoji,
        })),
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
    console.error('Quiz complete error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
