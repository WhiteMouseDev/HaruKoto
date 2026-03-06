import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';

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
    const { nickname, jlptLevel, goal, showKana } = body;

    if (!nickname || !jlptLevel || !goal) {
      return NextResponse.json(
        { error: 'Missing required fields' },
        { status: 400 }
      );
    }

    // Prisma DB를 먼저 업데이트 (source of truth)
    await prisma.user.upsert({
      where: { id: user.id },
      create: {
        id: user.id,
        email: user.email!,
        nickname,
        jlptLevel,
        goal,
        showKana: !!showKana,
        onboardingCompleted: true,
      },
      update: {
        nickname,
        jlptLevel,
        goal,
        showKana: !!showKana,
        onboardingCompleted: true,
      },
    });

    // Supabase Auth metadata 동기화 (실패해도 앱 동작에 영향 없음)
    const { error } = await supabase.auth.updateUser({
      data: {
        nickname,
        jlpt_level: jlptLevel,
        goal,
        show_kana: !!showKana,
        onboarding_completed: true,
      },
    });

    if (error) {
      console.warn('Supabase Auth metadata update failed (non-critical):', error.message);
    }

    return NextResponse.json({ success: true });
  } catch {
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
