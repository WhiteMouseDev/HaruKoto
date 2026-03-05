import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';

export async function POST(request: Request) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const body = await request.json();

  const dbUser = await prisma.user.findUnique({
    where: { id: user.id },
    select: { id: true, onboardingCompleted: true },
  });

  if (!dbUser) {
    await prisma.user.create({
      data: {
        id: user.id,
        email: body.email || user.email || '',
        nickname:
          body.nickname ||
          user.user_metadata?.full_name ||
          user.user_metadata?.name ||
          '',
        avatarUrl: body.avatarUrl || user.user_metadata?.avatar_url || null,
      },
    });
    return NextResponse.json({ needsOnboarding: true });
  }

  if (!dbUser.onboardingCompleted) {
    return NextResponse.json({ needsOnboarding: true });
  }

  return NextResponse.json({ needsOnboarding: false });
}
