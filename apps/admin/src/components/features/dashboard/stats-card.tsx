'use client';

import { useTranslations } from 'next-intl';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

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
    <Card>
      <CardHeader className="flex-row items-center gap-3 space-y-0">
        <span className="text-muted-foreground [&_svg]:size-5">{icon}</span>
        <CardTitle className="text-base">{title}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        {/* Count rows */}
        <div className="space-y-1">
          <div className="flex items-baseline gap-2">
            <span className="text-[28px] font-semibold leading-none">
              {needsReview}
            </span>
            <span className="text-sm text-muted-foreground">
              {t('needsReview')}
            </span>
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-[28px] font-semibold leading-none">
              {approved}
            </span>
            <span className="text-sm text-muted-foreground">
              {t('approved')}
            </span>
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-[28px] font-semibold leading-none">
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
