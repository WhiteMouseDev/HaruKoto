import { NextResponse } from 'next/server';

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get('code');
  const error = searchParams.get('error');

  if (error || !code) {
    return NextResponse.redirect(`${origin}/login?error=kakao_auth_failed`);
  }

  try {
    // Exchange authorization code for tokens via Kakao token endpoint
    const tokenResponse = await fetch('https://kauth.kakao.com/oauth/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        client_id: process.env.KAKAO_REST_API_KEY!,
        client_secret: process.env.KAKAO_CLIENT_SECRET!,
        redirect_uri: `${origin}/auth/kakao/callback`,
        code,
      }),
    });

    if (!tokenResponse.ok) {
      return NextResponse.redirect(`${origin}/login?error=kakao_token_failed`);
    }

    const tokenData = await tokenResponse.json();
    const idToken = tokenData.id_token;

    if (!idToken) {
      return NextResponse.redirect(
        `${origin}/login?error=kakao_no_id_token`
      );
    }

    // Redirect to client page with id_token for Supabase signInWithIdToken
    const completeUrl = new URL('/auth/kakao/complete', origin);
    completeUrl.searchParams.set('id_token', idToken);

    return NextResponse.redirect(completeUrl.toString());
  } catch {
    return NextResponse.redirect(`${origin}/login?error=kakao_exchange_failed`);
  }
}
