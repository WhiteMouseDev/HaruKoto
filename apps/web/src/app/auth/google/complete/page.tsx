'use client';

import { Suspense, useEffect, useRef } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';

function LoadingSpinner() {
  return (
    <div className="flex min-h-dvh items-center justify-center">
      <div className="flex flex-col items-center gap-3">
        <div className="border-primary h-8 w-8 animate-spin rounded-full border-2 border-t-transparent" />
        <p className="text-muted-foreground text-sm">Google 로그인 처리 중...</p>
      </div>
    </div>
  );
}

function GoogleCompleteInner() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const processed = useRef(false);

  useEffect(() => {
    if (processed.current) return;
    processed.current = true;

    const idToken = searchParams.get('id_token');

    if (!idToken) {
      router.replace('/login?error=google_no_id_token');
      return;
    }

    async function handleSignIn(token: string) {
      const supabase = createClient();

      const { error } = await supabase.auth.signInWithIdToken({
        provider: 'google',
        token,
      });

      if (error) {
        console.error('Google signInWithIdToken failed:', error.message);
        router.replace('/login?error=google_signin_failed');
        return;
      }

      const {
        data: { user },
      } = await supabase.auth.getUser();

      if (user) {
        try {
          const res = await fetch('/api/auth/ensure-user', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              id: user.id,
              email: user.email ?? '',
              nickname:
                user.user_metadata?.full_name ??
                user.user_metadata?.name ??
                '',
              avatarUrl: user.user_metadata?.avatar_url ?? null,
            }),
          });

          if (res.ok) {
            const data = await res.json();
            if (data.needsOnboarding) {
              router.replace('/onboarding');
              return;
            }
          }
        } catch {
          // If ensure-user API doesn't exist yet, fall through to /home
        }
      }

      router.replace('/home');
    }

    handleSignIn(idToken);
  }, [searchParams, router]);

  return <LoadingSpinner />;
}

export default function GoogleCompletePage() {
  return (
    <Suspense fallback={<LoadingSpinner />}>
      <GoogleCompleteInner />
    </Suspense>
  );
}
