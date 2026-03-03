import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { z } from 'zod';

const claimSchema = z.object({
  missionId: z.string().uuid(),
});

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
    const parsed = claimSchema.safeParse(body);
    if (!parsed.success) {
      return NextResponse.json(
        { error: 'Invalid request', details: parsed.error.flatten().fieldErrors },
        { status: 400 }
      );
    }

    const mission = await prisma.dailyMission.findFirst({
      where: {
        id: parsed.data.missionId,
        userId: user.id,
      },
    });

    if (!mission) {
      return NextResponse.json({ error: '미션을 찾을 수 없습니다' }, { status: 404 });
    }

    if (!mission.isCompleted) {
      return NextResponse.json({ error: '미션이 아직 완료되지 않았습니다' }, { status: 400 });
    }

    if (mission.rewardClaimed) {
      return NextResponse.json({ error: '이미 보상을 받았습니다' }, { status: 400 });
    }

    // XP 보상 매핑
    const XP_REWARDS: Record<string, number> = {
      words_5: 10,
      words_10: 20,
      quiz_1: 10,
      quiz_3: 25,
      correct_10: 15,
      correct_20: 30,
      chat_1: 15,
      chat_2: 30,
    };

    const xpReward = XP_REWARDS[mission.missionType] ?? 10;

    // 보상 수령 + XP 지급을 트랜잭션으로
    const updatedUser = await prisma.$transaction(async (tx) => {
      await tx.dailyMission.update({
        where: { id: mission.id },
        data: { rewardClaimed: true },
      });

      return tx.user.update({
        where: { id: user.id },
        data: { experiencePoints: { increment: xpReward } },
        select: { experiencePoints: true },
      });
    });

    return NextResponse.json({
      success: true,
      xpReward,
      totalXp: updatedUser.experiencePoints,
    });
  } catch (err) {
    console.error('Mission claim error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
