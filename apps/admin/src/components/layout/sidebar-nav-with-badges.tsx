'use client';

import { type ReactNode } from 'react';
import { useDashboardStats } from '@/hooks/use-dashboard-stats';
import { SidebarNavItem } from './sidebar-nav-item';

type NavItemDef = {
  href: string;
  icon: ReactNode;
  label: string;
  contentTypeKey?: string;
};

// Maps UI content type keys to stats API keys
function getBadgeCount(
  stats: Array<{ contentType: string; needsReview: number }> | undefined,
  contentTypeKey: string | undefined,
): number {
  if (!stats || !contentTypeKey) return 0;
  if (contentTypeKey === 'quiz') {
    const cloze = stats.find((s) => s.contentType === 'cloze')?.needsReview ?? 0;
    const sa = stats.find((s) => s.contentType === 'sentence_arrange')?.needsReview ?? 0;
    return cloze + sa;
  }
  return stats.find((s) => s.contentType === contentTypeKey)?.needsReview ?? 0;
}

export function SidebarNavWithBadges({ navItems }: { navItems: NavItemDef[] }) {
  const { data } = useDashboardStats();

  return (
    <nav className="flex flex-1 flex-col gap-1 py-4">
      {navItems.map((item) => (
        <SidebarNavItem
          key={item.href}
          href={item.href}
          icon={item.icon}
          label={item.label}
          badge={getBadgeCount(data?.stats, item.contentTypeKey)}
        />
      ))}
    </nav>
  );
}
