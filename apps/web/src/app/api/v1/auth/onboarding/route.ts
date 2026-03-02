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
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const body = await request.json();
    const { nickname, jlptLevel, goal } = body;

    if (!nickname || !jlptLevel || !goal) {
      return NextResponse.json(
        { error: 'Missing required fields' },
        { status: 400 }
      );
    }

    const { error } = await supabase.auth.updateUser({
      data: {
        nickname,
        jlpt_level: jlptLevel,
        goal,
        onboarding_completed: true,
      },
    });

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    await prisma.user.upsert({
      where: { id: user.id },
      create: {
        id: user.id,
        email: user.email!,
        nickname,
        jlptLevel,
        goal,
        onboardingCompleted: true,
      },
      update: {
        nickname,
        jlptLevel,
        goal,
        onboardingCompleted: true,
      },
    });

    return NextResponse.json({ success: true });
  } catch {
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
