'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import type { QueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import {
  fetchAdminContentDetail,
  fetchAuditLogs,
  patchAdminContent,
  reviewContent,
  type AuditLogEntry,
} from '@/lib/api/admin-content';

// Quiz detail pages address items via the compound type (quiz/cloze,
// quiz/sentence-arrange) because that's how the FastAPI detail/patch/review
// routes are keyed. The merged quiz LIST, however, is cached under
// ['admin-content', 'quiz', params]. Without this step, approving a single
// quiz item invalidates only the sub-cache and leaves the list stale.
function parentListContentType(contentType: string): string | null {
  if (contentType === 'quiz/cloze' || contentType === 'quiz/sentence-arrange') {
    return 'quiz';
  }
  return null;
}

function invalidateListCaches(queryClient: QueryClient, contentType: string): void {
  void queryClient.invalidateQueries({ queryKey: ['admin-content', contentType] });
  const parent = parentListContentType(contentType);
  if (parent) {
    void queryClient.invalidateQueries({ queryKey: ['admin-content', parent] });
  }
}

export function useContentDetail<T>(contentType: string, id: string) {
  const queryClient = useQueryClient();

  const detailQuery = useQuery<T>({
    queryKey: ['admin-content', contentType, id],
    queryFn: () => fetchAdminContentDetail<T>(contentType, id),
    staleTime: 30_000,
  });

  const patchMutation = useMutation({
    mutationFn: (data: Record<string, unknown>) =>
      patchAdminContent(contentType, id, data),
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ['admin-content', contentType, id],
      });
      invalidateListCaches(queryClient, contentType);
      void queryClient.invalidateQueries({
        queryKey: ['admin-content', contentType, id, 'audit-logs'],
      });
    },
    onError: (err: Error) => {
      console.error('Patch failed:', err);
    },
  });

  const reviewMutation = useMutation({
    mutationFn: ({
      action,
      reason,
    }: {
      action: 'approve' | 'reject';
      reason?: string;
    }) => reviewContent(contentType, id, action, reason),
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ['admin-content', contentType, id],
      });
      invalidateListCaches(queryClient, contentType);
      void queryClient.invalidateQueries({
        queryKey: ['admin-content', 'stats'],
      });
      void queryClient.invalidateQueries({
        queryKey: ['admin-content', contentType, id, 'audit-logs'],
      });
    },
    onError: (err: Error) => {
      toast.error(err.message);
    },
  });

  const auditQuery = useQuery<AuditLogEntry[]>({
    queryKey: ['admin-content', contentType, id, 'audit-logs'],
    queryFn: () => fetchAuditLogs(contentType, id),
    staleTime: 30_000,
  });

  return { detailQuery, patchMutation, reviewMutation, auditQuery };
}
