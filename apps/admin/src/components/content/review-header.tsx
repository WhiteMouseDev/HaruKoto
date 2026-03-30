'use client';

import { useTranslations } from 'next-intl';
import { CheckCircle, XCircle } from 'lucide-react';

import { Button } from '@/components/ui/button';
import { StatusBadge } from '@/components/ui/status-badge';

type ReviewHeaderProps = {
  reviewStatus: 'needs_review' | 'approved' | 'rejected';
  onApprove: () => void;
  onReject: () => void;
  isLoading: boolean;
};

export function ReviewHeader({
  reviewStatus,
  onApprove,
  onReject,
  isLoading,
}: ReviewHeaderProps) {
  const t = useTranslations('review');

  return (
    <div className="sticky top-0 z-10 flex items-center justify-between rounded-lg border border-border bg-card p-4">
      <StatusBadge status={reviewStatus} />
      <div className="flex items-center gap-2">
        <Button
          variant="default"
          size="sm"
          onClick={onApprove}
          disabled={isLoading}
          className="bg-green-600 text-white hover:bg-green-700"
        >
          <CheckCircle className="mr-1.5 size-4" />
          {t('approve')}
        </Button>
        <Button
          variant="destructive"
          size="sm"
          onClick={onReject}
          disabled={isLoading}
        >
          <XCircle className="mr-1.5 size-4" />
          {t('reject')}
        </Button>
      </div>
    </div>
  );
}
