'use client';

import { useTranslations } from 'next-intl';
import { ChevronLeft, ChevronRight } from 'lucide-react';

import { Button } from '@/components/ui/button';

type QueueNavigationBarProps = {
  position: number;
  total: number;
  hasPrev: boolean;
  hasNext: boolean;
  onPrev: () => void;
  onNext: () => void;
  onExit: () => void;
};

export function QueueNavigationBar({
  position,
  total,
  hasPrev,
  hasNext,
  onPrev,
  onNext,
  onExit,
}: QueueNavigationBarProps) {
  const t = useTranslations('review');

  return (
    <div className="sticky top-0 z-10 flex h-12 items-center justify-between border-b border-border bg-card px-4">
      <Button
        variant="ghost"
        size="sm"
        onClick={onPrev}
        disabled={!hasPrev}
        aria-label={t('prevItem')}
      >
        <ChevronLeft className="mr-1 size-4" />
        {t('prevItem')}
      </Button>

      <span className="rounded-md bg-muted px-2 py-1 text-sm text-muted-foreground">
        {t('queuePosition', { current: position, total })}
      </span>

      <div className="flex items-center gap-3">
        <Button
          variant="ghost"
          size="sm"
          onClick={onNext}
          disabled={!hasNext}
          aria-label={t('nextItem')}
        >
          {t('nextItem')}
          <ChevronRight className="ml-1 size-4" />
        </Button>
        <button
          onClick={onExit}
          className="text-sm text-muted-foreground underline underline-offset-4 hover:text-foreground"
        >
          {t('exitQueue')}
        </button>
      </div>
    </div>
  );
}
