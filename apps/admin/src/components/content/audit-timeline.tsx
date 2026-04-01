import { useTranslations } from 'next-intl';
import { cn } from '@/lib/utils';
import type { AuditLogEntry } from '@/lib/api/admin-content';

type AuditTimelineProps = {
  entries: AuditLogEntry[] | undefined;
  isLoading: boolean;
};

function getActionBadgeClass(action: string): string {
  if (action === 'approved') return 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400';
  if (action === 'rejected') return 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400';
  return 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400';
}

function getDotClass(action: string): string {
  if (action === 'approved') return 'bg-green-500';
  if (action === 'rejected') return 'bg-red-500';
  return 'bg-blue-500';
}

type TimeTranslator = (key: string, values?: Record<string, unknown>) => string;

function formatRelativeTime(dateStr: string, tTime: TimeTranslator): string {
  const diffMs = Date.now() - new Date(dateStr).getTime();
  const diffMin = Math.floor(diffMs / 60_000);
  if (diffMin < 1) return tTime('justNow');
  if (diffMin < 60) return tTime('minutesAgo', { n: diffMin });
  const diffH = Math.floor(diffMin / 60);
  if (diffH < 24) return tTime('hoursAgo', { n: diffH });
  return tTime('daysAgo', { n: Math.floor(diffH / 24) });
}

export function AuditTimeline({ entries, isLoading }: AuditTimelineProps) {
  const t = useTranslations('audit');
  const tTime = useTranslations('time');

  if (isLoading) {
    return (
      <div className="mt-8">
        <h3 className="mb-4 text-base font-semibold">{t('title')}</h3>
        <div className="space-y-4">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="flex gap-3">
              <div className="flex flex-col items-center">
                <div className="size-3 animate-pulse rounded-full bg-muted" />
                <div className="w-px flex-1 bg-border" />
              </div>
              <div className="flex-1 pb-4">
                <div className="mb-1 h-4 w-32 animate-pulse rounded bg-muted" />
                <div className="h-3 w-48 animate-pulse rounded bg-muted" />
              </div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  if (!entries || entries.length === 0) {
    return (
      <div className="mt-8">
        <h3 className="mb-4 text-base font-semibold">{t('title')}</h3>
        <p className="text-sm text-muted-foreground">{t('empty')}</p>
      </div>
    );
  }

  return (
    <div className="mt-8">
      <h3 className="mb-4 text-base font-semibold">{t('title')}</h3>
      <div className="relative border-l-2 border-border pl-4">
        {entries.map((entry, idx) => {
          const isLast = idx === entries.length - 1;
          return (
            <div
              key={entry.id}
              className={cn('relative pb-6', isLast && 'pb-0')}
            >
              {/* Dot on the vertical line */}
              <div
                className={cn(
                  'absolute -left-[1.3125rem] top-1 size-3 rounded-full border-2 border-background',
                  getDotClass(entry.action),
                )}
              />

              <div className="flex flex-wrap items-center gap-2">
                <span
                  className={cn(
                    'inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium',
                    getActionBadgeClass(entry.action),
                  )}
                >
                  {t(entry.action as 'modified' | 'approved' | 'rejected')}
                </span>
                <span className="text-xs text-muted-foreground">
                  {entry.reviewerEmail}
                </span>
                <span className="text-xs text-muted-foreground">
                  {formatRelativeTime(entry.createdAt, tTime)}
                </span>
              </div>

              {entry.reason && (
                <p className="mt-1 text-sm text-muted-foreground">
                  {entry.reason}
                </p>
              )}

              {entry.changes && Object.keys(entry.changes).length > 0 && (
                <div className="mt-1 space-y-0.5">
                  {Object.entries(entry.changes).map(([field, value]) => (
                    <p key={field} className="text-xs text-muted-foreground">
                      <span className="font-medium">{field}:</span>{' '}
                      {String(value)}
                    </p>
                  ))}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
