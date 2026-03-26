'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { createClient } from '@/lib/supabase/client';

type LoginFormProps = {
  defaultError?: 'access_denied' | 'session_expired' | null;
};

export function LoginForm({ defaultError = null }: LoginFormProps) {
  const t = useTranslations('auth.login');
  const router = useRouter();

  const getInitialError = () => {
    if (defaultError === 'access_denied') return t('errorAccessDenied');
    if (defaultError === 'session_expired') return t('errorSessionExpired');
    return '';
  };

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string>(getInitialError);
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setIsLoading(true);
    setError('');

    const supabase = createClient();
    const { error: signInError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (signInError) {
      setError(t('errorWrongCredentials'));
      setIsLoading(false);
      return;
    }

    router.push('/dashboard');
    router.refresh();
  };

  return (
    <form onSubmit={handleSubmit} className="flex w-full flex-col gap-4">
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="email" className="text-xs text-muted-foreground">
          {t('emailLabel')}
        </Label>
        <Input
          id="email"
          type="email"
          autoComplete="email"
          placeholder=""
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          disabled={isLoading}
        />
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="password" className="text-xs text-muted-foreground">
          {t('passwordLabel')}
        </Label>
        <Input
          id="password"
          type="password"
          autoComplete="current-password"
          placeholder=""
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
          disabled={isLoading}
        />
      </div>
      {error && (
        <p className="text-sm text-destructive" role="alert">
          {error}
        </p>
      )}
      <Button
        type="submit"
        disabled={isLoading}
        className="h-10 w-full bg-primary text-xs text-primary-foreground"
      >
        {t('submit')}
      </Button>
    </form>
  );
}
