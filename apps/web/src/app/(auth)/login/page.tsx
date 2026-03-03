'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { createClient } from '@/lib/supabase/client';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent } from '@/components/ui/card';
import { Logo } from '@/components/brand/logo';

export default function LoginPage() {
  const router = useRouter();
  const [isSignUp, setIsSignUp] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [info, setInfo] = useState('');
  const [loading, setLoading] = useState(false);
  const [showResetPassword, setShowResetPassword] = useState(false);
  const [resetEmail, setResetEmail] = useState('');
  const [resetLoading, setResetLoading] = useState(false);
  const [resetMessage, setResetMessage] = useState('');

  const supabase = createClient();

  async function handleEmailAuth(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    setInfo('');
    setLoading(true);

    try {
      if (isSignUp) {
        const { data, error } = await supabase.auth.signUp({
          email,
          password,
          options: {
            emailRedirectTo: `${window.location.origin}/auth/callback`,
          },
        });
        if (error) throw error;
        // Supabase returns a user with identities=[] if the email already exists (OAuth or email)
        if (data.user && data.user.identities?.length === 0) {
          setError(
            '이미 가입된 이메일입니다. 소셜 로그인으로 가입하셨다면 해당 방법으로 로그인해주세요.'
          );
        } else {
          setInfo('확인 이메일을 발송했습니다. 이메일을 확인해주세요.');
        }
      } else {
        const { error } = await supabase.auth.signInWithPassword({
          email,
          password,
        });
        if (error) {
          if (
            error.message.includes('Invalid login credentials') ||
            error.message.includes('invalid_credentials')
          ) {
            throw new Error(
              '이메일 또는 비밀번호가 올바르지 않습니다. 소셜 로그인(Google/Kakao)으로 가입하셨다면 해당 방법으로 로그인해주세요.'
            );
          }
          if (error.message.includes('Email not confirmed')) {
            throw new Error(
              '이메일 인증이 완료되지 않았습니다. 가입 시 발송된 이메일을 확인해주세요.'
            );
          }
          throw error;
        }
        router.push('/home');
        router.refresh();
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : '오류가 발생했습니다');
    } finally {
      setLoading(false);
    }
  }

  async function handleSocialLogin(provider: 'google' | 'kakao') {
    const { error } = await supabase.auth.signInWithOAuth({
      provider,
      options: {
        redirectTo: `${window.location.origin}/auth/callback`,
      },
    });
    if (error) {
      setError(error.message);
    }
  }

  async function handleResetPassword(e: React.FormEvent) {
    e.preventDefault();
    setResetLoading(true);
    setResetMessage('');

    try {
      const { error } = await supabase.auth.resetPasswordForEmail(resetEmail, {
        redirectTo: `${window.location.origin}/auth/callback`,
      });
      if (error) throw error;
      setResetMessage('비밀번호 재설정 이메일을 발송했습니다. 이메일을 확인해주세요.');
    } catch (err) {
      setResetMessage(
        err instanceof Error ? err.message : '오류가 발생했습니다'
      );
    } finally {
      setResetLoading(false);
    }
  }

  if (showResetPassword) {
    return (
      <div className="from-background to-secondary flex min-h-dvh flex-col items-center justify-center bg-gradient-to-b px-6">
        <div className="mb-8 flex flex-col items-center gap-2">
          <Logo variant="full" size="lg" />
        </div>

        <Card className="w-full max-w-sm">
          <CardContent className="flex flex-col gap-4 p-6">
            <div className="text-center">
              <h2 className="text-lg font-bold">비밀번호 재설정</h2>
              <p className="text-muted-foreground mt-1 text-sm">
                가입한 이메일을 입력하면 재설정 링크를 보내드립니다.
              </p>
            </div>

            <form onSubmit={handleResetPassword} className="flex flex-col gap-3">
              <div className="flex flex-col gap-1.5">
                <Label htmlFor="reset-email">이메일</Label>
                <Input
                  id="reset-email"
                  type="email"
                  placeholder="hello@example.com"
                  value={resetEmail}
                  onChange={(e) => setResetEmail(e.target.value)}
                  className="h-12 rounded-xl"
                  required
                  autoFocus
                />
              </div>

              {resetMessage && (
                <p className="text-center text-sm text-muted-foreground">
                  {resetMessage}
                </p>
              )}

              <Button
                type="submit"
                className="h-12 rounded-xl text-base"
                disabled={resetLoading}
              >
                {resetLoading ? '발송 중...' : '재설정 링크 보내기'}
              </Button>
            </form>

            <button
              type="button"
              className="text-primary text-sm font-medium underline-offset-4 hover:underline"
              onClick={() => {
                setShowResetPassword(false);
                setResetMessage('');
              }}
            >
              ← 로그인으로 돌아가기
            </button>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="from-background to-secondary flex min-h-dvh flex-col items-center justify-center bg-gradient-to-b px-6">
      {/* Logo */}
      <div className="mb-8 flex flex-col items-center gap-2">
        <Logo variant="full" size="lg" />
      </div>

      <Card className="w-full max-w-sm">
        <CardContent className="flex flex-col gap-4 p-6">
          {/* Social Login Buttons */}
          <div className="flex flex-col gap-2.5">
            <Button
              variant="outline"
              className="h-12 w-full rounded-xl text-sm"
              onClick={() => handleSocialLogin('google')}
            >
              <svg className="mr-2 size-5" viewBox="0 0 24 24">
                <path
                  d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 01-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z"
                  fill="#4285F4"
                />
                <path
                  d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                  fill="#34A853"
                />
                <path
                  d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                  fill="#FBBC05"
                />
                <path
                  d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                  fill="#EA4335"
                />
              </svg>
              Google로 계속하기
            </Button>
            <Button
              variant="outline"
              className="h-12 w-full rounded-xl bg-[#FEE500] text-sm text-[#191919] hover:bg-[#FDD835] hover:text-[#191919]"
              onClick={() => handleSocialLogin('kakao')}
            >
              <svg className="mr-2 size-5" viewBox="0 0 24 24" fill="#191919">
                <path d="M12 3C6.48 3 2 6.48 2 10.5c0 2.63 1.74 4.94 4.35 6.24-.13.48-.84 3.07-.87 3.27 0 0-.02.08.04.11.06.03.13.01.13.01.17-.02 3.15-2.08 3.64-2.43.88.13 1.79.2 2.71.2 5.52 0 10-3.48 10-7.5S17.52 3 12 3z" />
              </svg>
              Kakao로 계속하기
            </Button>
            {/* TODO: Apple Developer Program 가입 후 활성화 ($99/yr)
            <Button
              variant="outline"
              className="h-12 w-full rounded-xl bg-black text-sm text-white hover:bg-gray-800 hover:text-white"
              onClick={() => handleSocialLogin('apple')}
            >
              <svg
                className="mr-2 size-5"
                viewBox="0 0 24 24"
                fill="currentColor"
              >
                <path d="M17.05 20.28c-.98.95-2.05.88-3.08.4-1.09-.5-2.08-.48-3.24 0-1.44.62-2.2.44-3.06-.4C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z" />
              </svg>
              Apple로 계속하기
            </Button>
            */}
          </div>

          {/* Divider */}
          <div className="relative my-2">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t" />
            </div>
            <div className="relative flex justify-center text-xs">
              <span className="bg-card text-muted-foreground px-2">또는</span>
            </div>
          </div>

          {/* Email Auth */}
          <form onSubmit={handleEmailAuth} className="flex flex-col gap-3">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="email">이메일</Label>
              <Input
                id="email"
                type="email"
                placeholder="hello@example.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="h-12 rounded-xl"
                required
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="password">비밀번호</Label>
              <Input
                id="password"
                type="password"
                placeholder="6자 이상 입력"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="h-12 rounded-xl"
                minLength={6}
                required
              />
            </div>

            {error && (
              <p className="text-destructive text-center text-sm">{error}</p>
            )}

            {info && (
              <p className="text-primary text-center text-sm font-medium">{info}</p>
            )}

            <Button
              type="submit"
              className="h-12 rounded-xl text-base"
              disabled={loading}
            >
              {loading ? '처리 중...' : isSignUp ? '회원가입' : '로그인'}
            </Button>
          </form>

          {/* Forgot Password */}
          {!isSignUp && (
            <button
              type="button"
              className="text-muted-foreground text-center text-sm underline-offset-4 hover:underline"
              onClick={() => {
                setShowResetPassword(true);
                setResetEmail(email);
              }}
            >
              비밀번호를 잊으셨나요?
            </button>
          )}

          {/* Toggle */}
          <p className="text-muted-foreground text-center text-sm">
            {isSignUp ? '이미 계정이 있나요?' : '계정이 없나요?'}{' '}
            <button
              type="button"
              className="text-primary font-medium underline-offset-4 hover:underline"
              onClick={() => {
                setIsSignUp(!isSignUp);
                setError('');
                setInfo('');
              }}
            >
              {isSignUp ? '로그인' : '회원가입'}
            </button>
          </p>
        </CardContent>
      </Card>

      <Link
        href="/"
        className="text-muted-foreground hover:text-foreground mt-6 text-sm"
      >
        ← 처음으로
      </Link>
    </div>
  );
}
