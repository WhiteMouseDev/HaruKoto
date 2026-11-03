import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';
import { prisma } from '@harukoto/database';
import { STUDY_WRITES_PAUSED } from '@/lib/study-write-stop-policy';
import {
  STUDY_WRITE_STOP_MESSAGE,
  STUDY_WRITE_STOP_RETRY_SECONDS,
  canonicalStudyWritePath,
  studyWriteRouteDecision,
} from '@/lib/study-write-stop';

export async function proxy(request: NextRequest) {
  // Run before auth/session refresh, Prisma or an external provider. A stopped
  // request must never reach its handler, including GET mission auto-claims.
  if (
    STUDY_WRITES_PAUSED &&
    studyWriteRouteDecision(request.method, request.nextUrl.pathname) ===
      'pause'
  ) {
    return NextResponse.json(
      { error: STUDY_WRITE_STOP_MESSAGE },
      {
        status: 503,
        headers: {
          'Retry-After': String(STUDY_WRITE_STOP_RETRY_SECONDS),
          'Cache-Control': 'private, no-store',
        },
      }
    );
  }
  // Preserve the previous static-image fast path, but only after considering
  // canonical API paths: an encoded API/dynamic ID is not a static image.
  if (
    /\.(?:svg|png|jpg|jpeg|gif|webp)$/.test(request.nextUrl.pathname) &&
    !canonicalStudyWritePath(request.nextUrl.pathname).startsWith('/api/')
  ) {
    return NextResponse.next({ request });
  }
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
              user.user_metadata?.full_name || user.user_metadata?.name || '',
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
    // Do not exempt image extensions here: dynamic/encoded API IDs can contain
    // them. Static-image requests use the fast path after the STOP decision.
    '/((?!_next/static|_next/image|favicon.ico).*)',
  ],
};
