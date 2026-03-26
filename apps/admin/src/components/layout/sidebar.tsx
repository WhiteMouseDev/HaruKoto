import Image from 'next/image';
import {
  LayoutDashboard,
  BookOpen,
  BookMarked,
  HelpCircle,
  MessageSquare,
} from 'lucide-react';
import { getTranslations, getLocale } from 'next-intl/server';
import { SidebarNavItem } from './sidebar-nav-item';
import { LocaleSwitcher } from './locale-switcher';
import { LogoutButton } from './logout-button';

export async function Sidebar() {
  const t = await getTranslations('nav');
  const tAuth = await getTranslations('auth');
  const locale = await getLocale();

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
    },
    {
      href: '/grammar',
      icon: <BookMarked className="size-4 shrink-0" />,
      label: t('grammar'),
    },
    {
      href: '/quiz',
      icon: <HelpCircle className="size-4 shrink-0" />,
      label: t('quiz'),
    },
    {
      href: '/conversation',
      icon: <MessageSquare className="size-4 shrink-0" />,
      label: t('conversation'),
    },
  ];

  return (
    <aside className="flex h-full w-60 flex-col border-r border-border bg-background">
      {/* Logo + App name */}
      <div className="flex h-14 items-center gap-2 border-b border-border px-4">
        <Image
          src="/logo-symbol.svg"
          alt="HaruKoto logo"
          width={24}
          height={24}
          className="shrink-0"
        />
        <span className="text-sm font-semibold">HaruKoto Admin</span>
      </div>

      {/* Navigation */}
      <nav className="flex flex-1 flex-col gap-1 py-4">
        {navItems.map((item) => (
          <SidebarNavItem
            key={item.href}
            href={item.href}
            icon={item.icon}
            label={item.label}
          />
        ))}
      </nav>

      {/* Bottom: Locale + Logout */}
      <div className="flex flex-col gap-2 border-t border-border px-4 py-4">
        <LocaleSwitcher currentLocale={locale} />
        <LogoutButton label={tAuth('logout')} />
      </div>
    </aside>
  );
}
