import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';

export async function POST() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  // DB trigger(handle_new_user)가 public.users에 자동 생성하므로
  // 여기서는 온보딩 완료 여부만 확인한다.
  const dbUser = await prisma.user.findUnique({
    where: { id: user.id },
    select: { onboardingCompleted: true },
  });

  if (!dbUser || !dbUser.onboardingCompleted) {
    return NextResponse.json({ needsOnboarding: true });
  }

  return NextResponse.json({ needsOnboarding: false });
}
