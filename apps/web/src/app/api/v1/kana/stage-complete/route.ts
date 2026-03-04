import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import {
  calculateLevel,
  updateStreak,
  checkAndGrantAchievements,
  type GameEvent,
} from '@/lib/gamification';
import { KANA_REWARDS } from '@/lib/constants';

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
    const { stageId, quizScore } = body;

    if (!stageId) {
      return NextResponse.json(
        { error: 'stageId is required' },
        { status: 400 }
      );
    }

    // Find the stage
    const stage = await prisma.kanaLearningStage.findUnique({
      where: { id: stageId },
    });
    if (!stage) {
      return NextResponse.json(
        { error: 'Stage not found' },
        { status: 404 }
      );
    }

    // Mark stage as completed
    await prisma.userKanaStage.upsert({
      where: {
        userId_stageId: { userId: user.id, stageId },
      },
      update: {
        isCompleted: true,
        quizScore: quizScore ?? null,
        completedAt: new Date(),
      },
      create: {
        userId: user.id,
        stageId,
        isUnlocked: true,
        isCompleted: true,
        quizScore: quizScore ?? null,
        completedAt: new Date(),
      },
    });

    // Unlock next stage
    const nextStage = await prisma.kanaLearningStage.findUnique({
      where: {
        kanaType_stageNumber: {
          kanaType: stage.kanaType,
          stageNumber: stage.stageNumber + 1,
        },
      },
    });

    if (nextStage) {
      await prisma.userKanaStage.upsert({
        where: {
          userId_stageId: { userId: user.id, stageId: nextStage.id },
        },
        update: { isUnlocked: true },
        create: {
          userId: user.id,
          stageId: nextStage.id,
          isUnlocked: true,
        },
      });
    }

    // Award XP
    const xpEarned = KANA_REWARDS.STAGE_COMPLETE_XP;

    const { totalXp, newLevel, oldLevel, streak } =
      await prisma.$transaction(async (tx) => {
        const currentUser = await tx.user.findUniqueOrThrow({
          where: { id: user.id },
        });

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        await tx.dailyProgress.upsert({
          where: { userId_date: { userId: user.id, date: today } },
          update: { xpEarned: { increment: xpEarned } },
          create: { userId: user.id, date: today, xpEarned },
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

    // Check kana-specific achievements
    const totalKanaLearned = await prisma.userKanaProgress.count({
      where: { userId: user.id },
    });

    const events: GameEvent[] = await checkAndGrantAchievements(user.id, {
      totalXp,
      newLevel,
      oldLevel,
      streakCount: streak.streakCount,
      kanaFirstChar: totalKanaLearned >= 1,
      kanaHiraganaComplete:
        stage.kanaType === 'HIRAGANA' &&
        (await prisma.userKanaStage.count({
          where: {
            userId: user.id,
            isCompleted: true,
            stage: { kanaType: 'HIRAGANA' },
          },
        })) >=
          (await prisma.kanaLearningStage.count({
            where: { kanaType: 'HIRAGANA' },
          })),
      kanaKatakanaComplete:
        stage.kanaType === 'KATAKANA' &&
        (await prisma.userKanaStage.count({
          where: {
            userId: user.id,
            isCompleted: true,
            stage: { kanaType: 'KATAKANA' },
          },
        })) >=
          (await prisma.kanaLearningStage.count({
            where: { kanaType: 'KATAKANA' },
          })),
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
      success: true,
      xpEarned,
      currentXp: levelInfo.currentXp,
      xpForNext: levelInfo.xpForNext,
      level: levelInfo.level,
      nextStageUnlocked: !!nextStage,
      events,
    });
  } catch (err) {
    console.error('Kana stage-complete error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
