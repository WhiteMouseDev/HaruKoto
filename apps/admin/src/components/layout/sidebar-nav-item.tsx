'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { cn } from '@/lib/utils';

type SidebarNavItemProps = {
  href: string;
  icon: React.ReactNode;
  label: string;
};

export function SidebarNavItem({ href, icon, label }: SidebarNavItemProps) {
  const pathname = usePathname();
  const isActive =
    pathname === href ||
    (href !== '/dashboard' && pathname.startsWith(href + '/'));

  return (
    <Link
      href={href}
      className={cn(
        'flex h-10 items-center gap-2 px-4 text-sm transition-colors',
        isActive
          ? 'border-l-2 border-primary bg-accent text-foreground'
          : 'text-muted-foreground hover:bg-accent/50 hover:text-foreground'
      )}
    >
      {icon}
      <span>{label}</span>
    </Link>
  );
}
