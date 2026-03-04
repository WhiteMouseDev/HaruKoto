import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';

export async function GET(request: Request) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const { searchParams } = new URL(request.url);
    const type = searchParams.get('type');

    if (!type || (type !== 'HIRAGANA' && type !== 'KATAKANA')) {
      return NextResponse.json(
        { error: 'type must be HIRAGANA or KATAKANA' },
        { status: 400 }
      );
    }

    const stages = await prisma.kanaLearningStage.findMany({
      where: { kanaType: type },
      orderBy: { order: 'asc' },
    });

    // Get or create user stage records
    const existingUserStages = await prisma.userKanaStage.findMany({
      where: {
        userId: user.id,
        stageId: { in: stages.map((s) => s.id) },
      },
    });

    const userStageMap = new Map(
      existingUserStages.map((us) => [us.stageId, us])
    );

    // Auto-create UserKanaStage records if first access
    if (existingUserStages.length === 0 && stages.length > 0) {
      const data = stages.map((stage, index) => ({
        userId: user.id,
        stageId: stage.id,
        isUnlocked: index === 0, // Only first stage unlocked
        isCompleted: false,
      }));

      await prisma.userKanaStage.createMany({ data });

      // Re-fetch
      const created = await prisma.userKanaStage.findMany({
        where: {
          userId: user.id,
          stageId: { in: stages.map((s) => s.id) },
        },
      });
      for (const us of created) {
        userStageMap.set(us.stageId, us);
      }
    }

    const result = stages.map((stage) => {
      const userStage = userStageMap.get(stage.id);
      return {
        id: stage.id,
        kanaType: stage.kanaType,
        stageNumber: stage.stageNumber,
        title: stage.title,
        description: stage.description,
        characters: stage.characters,
        isUnlocked: userStage?.isUnlocked ?? false,
        isCompleted: userStage?.isCompleted ?? false,
        quizScore: userStage?.quizScore ?? null,
        completedAt: userStage?.completedAt ?? null,
      };
    });

    return NextResponse.json({ stages: result });
  } catch (err) {
    console.error('Kana stages GET error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
