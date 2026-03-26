import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';

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

  // IMPORTANT: must use getUser() (server-validated) NOT getSession() (JWT-decoded only)
  // This ensures role revocation (AUTH-03) is effective on every request
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { pathname } = request.nextUrl;

  const isLoginPage = pathname === '/login';
  const isAuthCallback = pathname.startsWith('/auth/');
  const isApiRoute = pathname.startsWith('/api/');

  // Non-exempt routes: require authentication + reviewer role
  if (!isLoginPage && !isAuthCallback && !isApiRoute) {
    if (!user) {
      const url = request.nextUrl.clone();
      url.pathname = '/login';
      return NextResponse.redirect(url);
    }

    // AUTH-02: Only users with app_metadata.reviewer === true can access admin
    if (user.app_metadata?.reviewer !== true) {
      const url = request.nextUrl.clone();
      url.pathname = '/login';
      url.searchParams.set('error', 'access_denied');
      return NextResponse.redirect(url);
    }
  }

  // Redirect already-authenticated reviewer away from login page
  if (isLoginPage && user && user.app_metadata?.reviewer === true) {
    const url = request.nextUrl.clone();
    url.pathname = '/dashboard';
    return NextResponse.redirect(url);
  }

  return supabaseResponse;
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
};
