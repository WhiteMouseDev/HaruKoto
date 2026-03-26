import { getTranslations } from 'next-intl/server';
import Image from 'next/image';
import { Card, CardContent } from '@/components/ui/card';
import { LoginForm } from '@/components/auth/login-form';

type SearchParams = Promise<{ error?: string }>;

type LoginPageProps = {
  searchParams: SearchParams;
};

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const t = await getTranslations('auth.login');
  const params = await searchParams;

  const errorParam =
    params.error === 'access_denied' || params.error === 'session_expired'
      ? params.error
      : null;

  return (
    <main className="flex min-h-screen items-center justify-center bg-background">
      <Card className="w-full max-w-[400px] rounded-lg border shadow-sm">
        <CardContent className="flex flex-col items-center px-8 py-12">
          <Image
            src="/images/logo-symbol.svg"
            alt="HaruKoto logo"
            width={48}
            height={48}
            className="mb-4"
            priority
          />
          <h1 className="mb-6 text-center text-[28px] font-semibold leading-[1.2] text-foreground">
            {t('heading')}
          </h1>
          <LoginForm defaultError={errorParam} />
        </CardContent>
      </Card>
    </main>
  );
}
