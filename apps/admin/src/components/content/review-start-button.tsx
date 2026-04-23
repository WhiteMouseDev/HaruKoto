'use client';

import { useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { useTranslations } from 'next-intl';
import { Play, Loader2 } from 'lucide-react';
import { toast } from 'sonner';

import { Button } from '@/components/ui/button';
import { fetchReviewQueue, type ReviewQueueItem } from '@/lib/api/admin-content';

type ReviewStartButtonProps = {
  contentType: string;
};

export function ReviewStartButton({ contentType }: ReviewStartButtonProps) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const t = useTranslations('review');
  const [isLoading, setIsLoading] = useState(false);

  async function handleStart() {
    setIsLoading(true);
    try {
      const jlptLevel = searchParams.get('jlpt') ?? undefined;
      const category = searchParams.get('category') ?? undefined;

      const data = await fetchReviewQueue(contentType, { jlptLevel, category });

      if (data.ids.length === 0) {
        toast.info(t('startQueueEmpty'));
        return;
      }

      if (data.capped) {
        toast.info(t('queueCapped'));
      }

      // Build queue param: for quiz, encode as "quizType:id"; for others, just "id"
      const queueEntries = data.ids.map((item: ReviewQueueItem) => {
        if (item.quizType) return `${item.quizType}:${item.id}`;
        return item.id;
      });
      const queueParam = queueEntries.join(',');

      // Navigate to first item
      const firstItem = data.ids[0]!;
      const params = new URLSearchParams();
      params.set('queue', queueParam);
      params.set('qi', '0');
      if (firstItem.quizType) params.set('type', firstItem.quizType);

      router.push(`/${contentType}/${firstItem.id}?${params.toString()}`);
    } catch {
      toast.error(t('queueLoadError'));
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <Button
      variant="default"
      size="sm"
      onClick={() => void handleStart()}
      disabled={isLoading}
    >
      {isLoading ? (
        <Loader2 className="mr-1.5 size-4 animate-spin" />
      ) : (
        <Play className="mr-1.5 size-4" />
      )}
      {t('startQueue')}
    </Button>
  );
}
