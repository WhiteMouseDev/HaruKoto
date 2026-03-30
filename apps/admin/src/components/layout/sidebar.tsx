import Image from 'next/image';
import {
  LayoutDashboard,
  BookOpen,
  BookMarked,
  HelpCircle,
  MessageSquare,
} from 'lucide-react';
import { getTranslations } from 'next-intl/server';
import type { User } from '@supabase/supabase-js';
import { SidebarNavWithBadges } from './sidebar-nav-with-badges';
import { LocaleSwitcher } from './locale-switcher';
import { LogoutButton } from './logout-button';

export async function Sidebar({ user, locale }: { user: User; locale: string }) {
  const t = await getTranslations('nav');
  const tAuth = await getTranslations('auth');

  const displayName =
    (user.user_metadata?.full_name as string | undefined) ??
    user.email?.split('@')[0] ??
    'Reviewer';

  const navItems = [
    {
      href: '/dashboard',
      icon: <LayoutDashboard className="size-4 shrink-0" />,
      label: t('dashboard'),
    },
    {
      href: '/vocabulary',
      icon: <BookOpen className="size-4 shrink-0" />,
      label: t('vocabulary'),
      contentTypeKey: 'vocabulary',
    },
    {
      href: '/grammar',
      icon: <BookMarked className="size-4 shrink-0" />,
      label: t('grammar'),
      contentTypeKey: 'grammar',
    },
    {
      href: '/quiz',
      icon: <HelpCircle className="size-4 shrink-0" />,
      label: t('quiz'),
      contentTypeKey: 'quiz',
    },
    {
      href: '/conversation',
      icon: <MessageSquare className="size-4 shrink-0" />,
      label: t('conversation'),
      contentTypeKey: 'conversation',
    },
  ];

  return (
    <aside className="flex h-screen w-60 shrink-0 flex-col overflow-y-auto border-r border-border bg-background">
      {/* Logo */}
      <div className="flex h-14 items-center border-b border-border px-4">
        <Image
          src="/images/logo-horizontal.svg"
          alt="HaruKoto"
          width={140}
          height={32}
          className="shrink-0"
        />
      </div>

      {/* Navigation with badges */}
      <SidebarNavWithBadges navItems={navItems} />

      {/* Bottom: Display name + Locale + Logout */}
      <div className="flex flex-col gap-2 border-t border-border px-4 py-4">
        <span className="text-xs text-muted-foreground">{displayName}</span>
        <LocaleSwitcher currentLocale={locale} />
        <LogoutButton label={tAuth('logout')} />
      </div>
    </aside>
  );
}
