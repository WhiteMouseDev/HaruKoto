import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { getTodayKST } from '@/lib/date';
import {
  lockStudyActivityUser,
  preserveNewerStudyDate,
} from '@/lib/study-activity-lock';
import {
  calculateLevel,
  updateStreak,
  checkAndGrantAchievements,
  type GameEvent,
} from '@/lib/gamification';
import { KANA_REWARDS } from '@/lib/constants';

function result(
  totalXp: number,
  nextStageUnlocked: boolean,
  events: GameEvent[] = []
) {
  const levelInfo = calculateLevel(totalXp);
  return NextResponse.json({
    success: true,
    xpEarned: KANA_REWARDS.STAGE_COMPLETE_XP,
    currentXp: levelInfo.currentXp,
    xpForNext: levelInfo.xpForNext,
    level: levelInfo.level,
    nextStageUnlocked,
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
    const { stageId, quizScore } = await request.json();
    if (!stageId)
      return NextResponse.json(
        { error: 'stageId is required' },
        { status: 400 }
      );
    const stage = await prisma.kanaLearningStage.findUnique({
      where: { id: stageId },
    });
    if (!stage)
      return NextResponse.json({ error: 'Stage not found' }, { status: 404 });

    return await prisma.$transaction(async (tx) => {
      const currentUser = await lockStudyActivityUser(tx, user.id);
      // All stage writers serialize on the owner before observing completion.
      const prior = await tx.userKanaStage.findUnique({
        where: { userId_stageId: { userId: user.id, stageId } },
      });
      const nextStage = await tx.kanaLearningStage.findUnique({
        where: {
          kanaType_stageNumber: {
            kanaType: stage.kanaType,
            stageNumber: stage.stageNumber + 1,
          },
        },
      });
      if (prior?.isCompleted) {
        // Keep the original score/date and avoid even an unlock upsert on replay.
        const nextProgress = nextStage
          ? await tx.userKanaStage.findUnique({
              where: {
                userId_stageId: { userId: user.id, stageId: nextStage.id },
              },
            })
          : null;
        return result(
          currentUser.experiencePoints,
          nextProgress?.isUnlocked ?? false
        );
      }
      const now = new Date();
      const today = getTodayKST(now);
      await tx.userKanaStage.upsert({
        where: { userId_stageId: { userId: user.id, stageId } },
        update: {
          isCompleted: true,
          quizScore: quizScore ?? null,
          completedAt: now,
        },
        create: {
          userId: user.id,
          stageId,
          isUnlocked: true,
          isCompleted: true,
          quizScore: quizScore ?? null,
          completedAt: now,
        },
      });
      if (nextStage)
        await tx.userKanaStage.upsert({
          where: { userId_stageId: { userId: user.id, stageId: nextStage.id } },
          update: { isUnlocked: true },
          create: { userId: user.id, stageId: nextStage.id, isUnlocked: true },
        });
      const xpEarned = KANA_REWARDS.STAGE_COMPLETE_XP;
      await tx.dailyProgress.upsert({
        where: { userId_date: { userId: user.id, date: today } },
        update: { xpEarned: { increment: xpEarned }, studyDayCredited: true },
        create: {
          userId: user.id,
          date: today,
          xpEarned,
          studyDayCredited: true,
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
      const [
        totalKanaLearned,
        hiraganaCompletedCount,
        hiraganaTotalCount,
        katakanaCompletedCount,
        katakanaTotalCount,
      ] = await Promise.all([
        tx.userKanaProgress.count({ where: { userId: user.id } }),
        tx.userKanaStage.count({
          where: {
            userId: user.id,
            isCompleted: true,
            stage: { kanaType: 'HIRAGANA' },
          },
        }),
        tx.kanaLearningStage.count({ where: { kanaType: 'HIRAGANA' } }),
        tx.userKanaStage.count({
          where: {
            userId: user.id,
            isCompleted: true,
            stage: { kanaType: 'KATAKANA' },
          },
        }),
        tx.kanaLearningStage.count({ where: { kanaType: 'KATAKANA' } }),
      ]);
      const isHiraganaComplete = hiraganaCompletedCount >= hiraganaTotalCount;
      const isKatakanaComplete = katakanaCompletedCount >= katakanaTotalCount;
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
          ...(isHiraganaComplete && isKatakanaComplete
            ? { showKana: false }
            : {}),
        },
      });
      const events = await checkAndGrantAchievements(
        user.id,
        {
          totalXp,
          newLevel,
          oldLevel: currentUser.level,
          streakCount: streak.streakCount,
          kanaFirstChar: totalKanaLearned >= 1,
          kanaHiraganaComplete:
            stage.kanaType === 'HIRAGANA' && isHiraganaComplete,
          kanaKatakanaComplete:
            stage.kanaType === 'KATAKANA' && isKatakanaComplete,
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
      return result(totalXp, !!nextStage, events);
    });
  } catch (err) {
    console.error('Kana stage-complete error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
