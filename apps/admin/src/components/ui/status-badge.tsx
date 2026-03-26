'use client';

import { useTranslations } from 'next-intl';
import { cn } from '@/lib/utils';

type StatusBadgeProps = {
  status: 'needs_review' | 'approved' | 'rejected';
};

const statusStyles = {
  needs_review:
    'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400',
  approved:
    'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',
  rejected: 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400',
} as const;

export function StatusBadge({ status }: StatusBadgeProps) {
  const t = useTranslations('status');

  const labelKey =
    status === 'needs_review'
      ? 'needsReview'
      : status === 'approved'
        ? 'approved'
        : 'rejected';

  return (
    <span
      className={cn(
        'inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium',
        statusStyles[status]
      )}
    >
      {t(labelKey)}
    </span>
  );
}
