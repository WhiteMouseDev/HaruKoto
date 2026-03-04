import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';

export async function GET() {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const stats = await prisma.conversation.groupBy({
      by: ['characterId'],
      where: {
        userId: user.id,
        endedAt: { not: null },
        characterId: { not: null },
      },
      _count: { id: true },
    });

    const characterStats: Record<string, number> = {};
    for (const s of stats) {
      if (s.characterId) {
        characterStats[s.characterId] = s._count.id;
      }
    }

    return NextResponse.json({ characterStats });
  } catch (err) {
    console.error('Character stats error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
