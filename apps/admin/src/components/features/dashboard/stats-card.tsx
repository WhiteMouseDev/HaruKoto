'use client';

import { useTranslations } from 'next-intl';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { cn } from '@/lib/utils';

type StatsCardProps = {
  title: string;
  icon: React.ReactNode;
  needsReview: number;
  approved: number;
  rejected: number;
  total: number;
};

export function StatsCard({
  title,
  icon,
  needsReview,
  approved,
  rejected,
  total,
}: StatsCardProps) {
  const t = useTranslations('dashboard');

  const progressPct = total > 0 ? Math.round((approved / total) * 100) : 0;

  return (
    <Card className={cn(needsReview > 0 && 'border-l-4 border-l-amber-400')}>
      <CardHeader className="flex-row items-center gap-3 space-y-0">
        <span className="text-muted-foreground [&_svg]:size-5">{icon}</span>
        <CardTitle className="text-base">{title}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        {/* Count rows */}
        <div className="space-y-1">
          <div className="flex items-baseline gap-2">
            <span className="text-[28px] font-semibold leading-none text-amber-500">
              {needsReview}
            </span>
            <span className="text-sm text-muted-foreground">
              {t('needsReview')}
            </span>
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-[28px] font-semibold leading-none text-emerald-600">
              {approved}
            </span>
            <span className="text-sm text-muted-foreground">
              {t('approved')}
              <span className="ml-1 text-xs">/ {total}</span>
            </span>
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-[28px] font-semibold leading-none text-muted-foreground">
              {rejected}
            </span>
            <span className="text-sm text-muted-foreground">
              {t('rejected')}
            </span>
          </div>
        </div>

        {/* Progress bar */}
        <div className="space-y-1">
          <div className="h-2 w-full overflow-hidden rounded-full bg-border">
            <div
              className="h-full bg-primary transition-all"
              style={{ width: `${progressPct}%` }}
            />
          </div>
          <p className="text-xs text-muted-foreground">
            {t('progressLabel', { n: progressPct })}
          </p>
        </div>
      </CardContent>
    </Card>
  );
}
