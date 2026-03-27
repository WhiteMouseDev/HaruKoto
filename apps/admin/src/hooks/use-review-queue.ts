'use client';

import { useRouter, useSearchParams } from 'next/navigation';
import { useCallback, useMemo } from 'react';

export function useReviewQueue(contentType: string) {
  const router = useRouter();
  const searchParams = useSearchParams();

  const queueParam = searchParams.get('queue');
  const qiParam = searchParams.get('qi');

  // Parse queue items - format: "id1,id2" or "cloze:id1,sentence_arrange:id2" for quiz
  const ids = useMemo(() => (queueParam ? queueParam.split(',') : []), [queueParam]);
  const currentIndex = qiParam !== null ? Number(qiParam) : -1;
  const isInQueue = ids.length > 0 && currentIndex >= 0;
  const total = ids.length;
  const position = currentIndex + 1; // 1-based for display
  const hasPrev = currentIndex > 0;
  const hasNext = currentIndex < ids.length - 1;

  const buildUrl = useCallback(
    (index: number) => {
      const entry = ids[index];
      if (!entry) return `/${contentType}`;

      // Quiz entries may have format "cloze:uuid" or "sentence_arrange:uuid"
      const colonIdx = entry.indexOf(':');
      let targetId: string;
      let quizType: string | null = null;

      if (colonIdx > 0 && contentType === 'quiz') {
        quizType = entry.substring(0, colonIdx);
        targetId = entry.substring(colonIdx + 1);
      } else {
        targetId = entry;
      }

      const params = new URLSearchParams();
      params.set('queue', queueParam!);
      params.set('qi', String(index));
      if (quizType) params.set('type', quizType);

      return `/${contentType}/${targetId}?${params.toString()}`;
    },
    [ids, contentType, queueParam],
  );

  const goNext = useCallback(() => {
    if (hasNext) {
      router.push(buildUrl(currentIndex + 1));
    } else {
      // Last item — return to list page
      router.push(`/${contentType}`);
    }
  }, [hasNext, currentIndex, contentType, router, buildUrl]);

  const goPrev = useCallback(() => {
    if (hasPrev) {
      router.push(buildUrl(currentIndex - 1));
    }
  }, [hasPrev, currentIndex, router, buildUrl]);

  const exitQueue = useCallback(() => {
    router.push(`/${contentType}`);
  }, [contentType, router]);

  return {
    isInQueue,
    position,
    total,
    goNext,
    goPrev,
    hasPrev,
    hasNext,
    exitQueue,
    /** Whether this is the last item in the queue */
    isLastItem: currentIndex === ids.length - 1,
  };
}
