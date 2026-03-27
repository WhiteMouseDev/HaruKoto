'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';

import { batchReviewContent } from '@/lib/api/admin-content';

export function useBulkReview(contentType: string) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({
      ids,
      action,
      reason,
    }: {
      ids: string[];
      action: 'approve' | 'reject';
      reason?: string;
    }) => batchReviewContent(contentType, ids, action, reason),
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ['admin-content', contentType],
      });
      void queryClient.invalidateQueries({
        queryKey: ['admin-content', 'stats'],
      });
    },
  });
}
