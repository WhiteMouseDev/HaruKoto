'use client';

import { useEffect, useState } from 'react';
import { useTranslations } from 'next-intl';
import { BookOpen, BookMarked, HelpCircle, MessageSquare } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { useDashboardStats } from '@/hooks/use-dashboard-stats';
import { StatsCard } from '@/components/features/dashboard/stats-card';
import type { User } from '@supabase/supabase-js';

const CONTENT_TYPE_CONFIG = [
  {
    key: 'vocabulary',
    icon: <BookOpen />,
  },
  {
    key: 'grammar',
    icon: <BookMarked />,
  },
  {
    key: 'quiz',
    icon: <HelpCircle />,
  },
  {
    key: 'conversation',
    icon: <MessageSquare />,
  },
] as const;

function SkeletonCard() {
  return (
    <div className="flex animate-pulse flex-col gap-4 rounded-xl border bg-card p-6">
      <div className="h-5 w-1/3 rounded bg-muted" />
      <div className="space-y-2">
        <div className="h-8 w-1/2 rounded bg-muted" />
        <div className="h-8 w-1/2 rounded bg-muted" />
        <div className="h-8 w-1/2 rounded bg-muted" />
      </div>
      <div className="h-2 w-full rounded bg-muted" />
    </div>
  );
}

export default function DashboardPage() {
  const t = useTranslations('dashboard');
  const { data, isLoading, isError, refetch } = useDashboardStats();
  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    const supabase = createClient();
    void supabase.auth.getUser().then(({ data: { user: u } }) => {
      setUser(u);
    });
  }, []);

  const displayName =
    (user?.user_metadata?.full_name as string | undefined) ??
    user?.email?.split('@')[0] ??
    'Reviewer';

  return (
    <div>
      <h1 className="mb-1 text-xl font-semibold">{t('pageTitle')}</h1>
      <p className="mb-6 text-sm text-muted-foreground">
        {t('welcome', { name: displayName })}
      </p>

      {isError ? (
        <div className="flex flex-col items-center gap-4 py-16 text-center">
          <p className="text-sm text-muted-foreground">{t('emptyBody')}</p>
          <button
            onClick={() => void refetch()}
            className="rounded-md border border-border px-4 py-2 text-sm hover:bg-muted/50"
          >
            再試行
          </button>
        </div>
      ) : (
        <div className="grid max-w-[960px] grid-cols-2 gap-6">
          {isLoading
            ? Array.from({ length: 4 }).map((_, i) => (
                <SkeletonCard key={i} />
              ))
            : CONTENT_TYPE_CONFIG.map(({ key, icon }) => {
                const statsItem = data?.stats.find(
                  (s) => s.contentType === key
                );
                return (
                  <StatsCard
                    key={key}
                    title={t(key as 'vocabulary' | 'grammar' | 'quiz' | 'conversation')}
                    icon={icon}
                    needsReview={statsItem?.needsReview ?? 0}
                    approved={statsItem?.approved ?? 0}
                    rejected={statsItem?.rejected ?? 0}
                    total={statsItem?.total ?? 0}
                  />
                );
              })}
        </div>
      )}
    </div>
  );
}
