'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import {
  fetchAdminContentDetail,
  fetchAuditLogs,
  patchAdminContent,
  reviewContent,
  type AuditLogEntry,
} from '@/lib/api/admin-content';

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
      void queryClient.invalidateQueries({
        queryKey: ['admin-content', contentType, 'list'],
      });
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
      void queryClient.invalidateQueries({
        queryKey: ['admin-content', contentType],
      });
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
