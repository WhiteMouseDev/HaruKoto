import Image from 'next/image';
import type { User } from '@supabase/supabase-js';
import { getTranslations } from 'next-intl/server';
import { LocaleSwitcher } from './locale-switcher';
import { LogoutButton } from './logout-button';

type HeaderProps = {
  user: User;
  locale: string;
};

export async function Header({ user, locale }: HeaderProps) {
  const t = await getTranslations();
  const displayName =
    (user.user_metadata?.full_name as string | undefined) ??
    user.email?.split('@')[0] ??
    'Reviewer';

  return (
    <header className="flex h-14 w-full items-center justify-between border-b border-border bg-card px-6">
      {/* Left: Logo + App name */}
      <div className="flex items-center gap-2">
        <Image
          src="/logo-symbol.svg"
          alt="HaruKoto logo"
          width={24}
          height={24}
          className="shrink-0"
        />
        <span className="text-sm font-semibold">HaruKoto Admin</span>
      </div>

      {/* Right: Locale switcher + user info + logout */}
      <div className="flex items-center gap-4">
        <LocaleSwitcher currentLocale={locale} />
        <span className="text-sm text-muted-foreground">{displayName}</span>
        <LogoutButton label={t('auth.logout')} />
      </div>
    </header>
  );
}
