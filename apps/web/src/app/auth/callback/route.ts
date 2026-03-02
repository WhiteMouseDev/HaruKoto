import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get('code');
  const next = searchParams.get('next') ?? '/home';

  if (code) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      const {
        data: { user },
      } = await supabase.auth.getUser();

      if (user) {
        // Check if user exists in Prisma DB
        const dbUser = await prisma.user.findUnique({
          where: { id: user.id },
          select: { id: true, onboardingCompleted: true },
        });

        if (!dbUser) {
          // New OAuth user — create a basic record and redirect to onboarding
          await prisma.user.create({
            data: {
              id: user.id,
              email: user.email ?? '',
              nickname:
                user.user_metadata?.full_name ??
                user.user_metadata?.name ??
                '',
              avatarUrl: user.user_metadata?.avatar_url ?? null,
            },
          });
          return NextResponse.redirect(`${origin}/onboarding`);
        }

        if (!dbUser.onboardingCompleted) {
          return NextResponse.redirect(`${origin}/onboarding`);
        }
      }

      return NextResponse.redirect(`${origin}${next}`);
    }
  }

  // Auth error - redirect to login with error
  return NextResponse.redirect(`${origin}/login?error=auth_failed`);
}
