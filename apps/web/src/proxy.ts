import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';
import { prisma } from '@harukoto/database';

export async function proxy(request: NextRequest) {
  let supabaseResponse = NextResponse.next({
    request,
  });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value)
          );
          supabaseResponse = NextResponse.next({
            request,
          });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  // Protected routes - redirect to login if not authenticated
  const protectedPaths = ['/home', '/stats', '/study', '/chat', '/my'];
  const isProtectedPath = protectedPaths.some((path) =>
    request.nextUrl.pathname.startsWith(path)
  );

  if (!user && isProtectedPath) {
    const url = request.nextUrl.clone();
    url.pathname = '/login';
    return NextResponse.redirect(url);
  }

  // Logged-in user on protected route: check onboarding completion
  if (user && isProtectedPath) {
    const onboardingCookie = request.cookies.get('onboarding_completed');

    if (onboardingCookie?.value === user.id) {
      // Cookie matches current user, skip DB query
    } else {
      let dbUser = await prisma.user.findUnique({
        where: { id: user.id },
        select: { onboardingCompleted: true },
      });

      // Supabase Auth에 유저가 있지만 Prisma DB에 없는 경우 자동 생성
      if (!dbUser) {
        dbUser = await prisma.user.create({
          data: {
            id: user.id,
            email: user.email || '',
            nickname:
              user.user_metadata?.full_name ||
              user.user_metadata?.name ||
              '',
            avatarUrl: user.user_metadata?.avatar_url || null,
          },
          select: { onboardingCompleted: true },
        });
      }

      if (!dbUser.onboardingCompleted) {
        const url = request.nextUrl.clone();
        url.pathname = '/onboarding';
        return NextResponse.redirect(url);
      }

      supabaseResponse.cookies.set('onboarding_completed', user.id, {
        httpOnly: true,
        sameSite: 'lax',
        path: '/',
        maxAge: 30 * 24 * 60 * 60, // 30 days
      });
    }
  }

  // Redirect onboarded users away from /onboarding
  if (user && request.nextUrl.pathname === '/onboarding') {
    const onboardingCookie = request.cookies.get('onboarding_completed');
    if (onboardingCookie?.value === user.id) {
      const url = request.nextUrl.clone();
      url.pathname = '/home';
      return NextResponse.redirect(url);
    }
    const dbUser = await prisma.user.findUnique({
      where: { id: user.id },
      select: { onboardingCompleted: true },
    });
    if (dbUser?.onboardingCompleted) {
      const url = request.nextUrl.clone();
      url.pathname = '/home';
      const redirectResponse = NextResponse.redirect(url);
      // Set cookie so future checks skip DB query
      redirectResponse.cookies.set('onboarding_completed', user.id, {
        httpOnly: true,
        sameSite: 'lax',
        path: '/',
        maxAge: 30 * 24 * 60 * 60,
      });
      return redirectResponse;
    }
  }

  // Root path — always redirect (landing is a separate app)
  if (request.nextUrl.pathname === '/') {
    const url = request.nextUrl.clone();
    url.pathname = user ? '/home' : '/login';
    return NextResponse.redirect(url);
  }

  // Redirect logged-in users away from login page
  if (user && request.nextUrl.pathname === '/login') {
    const url = request.nextUrl.clone();
    url.pathname = '/home';
    return NextResponse.redirect(url);
  }

  return supabaseResponse;
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
};
