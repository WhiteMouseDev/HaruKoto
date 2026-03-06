'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { motion } from 'framer-motion';
import {
  Home,
  BarChart3,
  BookOpen,
  MessageCircle,
  User,
  FlaskConical,
} from 'lucide-react';
import { cn } from '@/lib/utils';

type Tab = {
  href: string;
  label: string;
  icon: typeof Home;
  beta?: boolean;
};

const tabs: Tab[] = [
  { href: '/home', label: '홈', icon: Home },
  { href: '/stats', label: '학습통계', icon: BarChart3 },
  { href: '/study', label: '학습', icon: BookOpen },
  { href: '/chat', label: '회화', icon: MessageCircle, beta: true },
  { href: '/my', label: 'MY', icon: User },
];

export function BottomNav() {
  const pathname = usePathname();

  // Hide on active chat/call pages where keyboard input exists
  const isConversationPage =
    /^\/chat\/[^/]+$/.test(pathname) || pathname.startsWith('/chat/call');
  if (isConversationPage) return null;

  return (
    <nav aria-label="메인 네비게이션" className="bg-background/95 safe-area-bottom fixed right-0 bottom-0 left-0 z-40 border-t backdrop-blur-sm">
      <div className="mx-auto flex h-16 max-w-lg items-center justify-around px-2">
        {tabs.map((tab) => {
          const isActive = pathname.startsWith(tab.href);
          const Icon = tab.icon;

          return (
            <Link
              key={tab.href}
              href={tab.href}
              prefetch={false}
              aria-current={isActive ? 'page' : undefined}
              className={cn(
                'relative flex flex-1 flex-col items-center gap-0.5 py-1.5 text-[10px] transition-colors',
                isActive
                  ? 'text-primary font-bold'
                  : 'text-muted-foreground font-medium hover:text-foreground'
              )}
            >
              <div className="relative">
                <motion.div
                  animate={{ scale: isActive ? 1.15 : 1 }}
                  transition={{ type: 'spring', stiffness: 400, damping: 20 }}
                >
                  <Icon
                    className={cn(
                      'size-5 transition-all',
                      isActive && 'fill-primary/20'
                    )}
                    strokeWidth={isActive ? 2.5 : 2}
                  />
                </motion.div>
                {tab.beta && (
                  <FlaskConical className="text-primary absolute -top-1.5 -right-2 size-2.5" />
                )}
              </div>
              <span>{tab.label}</span>
              {isActive && (
                <motion.span
                  layoutId="nav-indicator"
                  className="bg-primary absolute -top-px left-1/2 h-0.5 w-8 -translate-x-1/2 rounded-full"
                  transition={{ type: 'spring', stiffness: 400, damping: 30 }}
                />
              )}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
