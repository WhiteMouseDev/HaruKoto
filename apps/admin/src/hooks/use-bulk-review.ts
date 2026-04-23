'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { batchReviewContent } from '@/lib/api/admin-content';

export type BulkBatch = {
  contentType: string;
  ids: string[];
  action: 'approve' | 'reject';
  reason?: string;
};

export function useBulkReview() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (batches: BulkBatch[]) => {
      // API's BatchReviewRequest only accepts canonical content types
      // (cloze / sentence_arrange / vocabulary / grammar / conversation). Quiz must be
      // split by quiz_type before calling — see ContentTable.buildBatches.
      //
      // Use allSettled so a partial failure still lets us invalidate caches for the
      // successful batches in onSettled. The first error is re-thrown so React Query
      // routes the mutation to onError.
      const results = await Promise.allSettled(
        batches.map((b) => batchReviewContent(b.contentType, b.ids, b.action, b.reason)),
      );
      const failure = results.find((r) => r.status === 'rejected');
      if (failure && failure.status === 'rejected') {
        throw failure.reason instanceof Error
          ? failure.reason
          : new Error(String(failure.reason));
      }
    },
    onSettled: (_data, _error, batches) => {
      // Invalidate optimistically on both success and partial failure so the UI
      // reflects whatever committed on the server.
      const types = new Set(batches.map((b) => b.contentType));
      if (types.has('cloze') || types.has('sentence_arrange')) types.add('quiz');
      for (const type of types) {
        void queryClient.invalidateQueries({ queryKey: ['admin-content', type] });
      }
      void queryClient.invalidateQueries({ queryKey: ['admin-content', 'stats'] });
    },
    onError: (err: Error) => {
      toast.error(err.message);
    },
  });
}
