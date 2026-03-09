'use client';

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { queryKeys } from '@/lib/query-keys';
import { apiFetch } from '@/lib/api';
import type { SubscriptionStatusResponse } from '@/types/subscription';

export function useSubscription() {
  return useQuery<SubscriptionStatusResponse>({
    queryKey: queryKeys.subscription,
    queryFn: () =>
      apiFetch<SubscriptionStatusResponse>('/api/v1/subscription/status'),
    staleTime: 30 * 60 * 1000, // 30분 — mutation 시에만 invalidate
    gcTime: 60 * 60 * 1000,
  });
}

export function useIsPremium() {
  const { data } = useSubscription();
  return data?.subscription.isPremium ?? false;
}

export function useAiUsage() {
  const { data } = useSubscription();
  return data?.aiUsage ?? null;
}

export function useCancelSubscription() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (reason?: string) =>
      apiFetch('/api/v1/subscription/cancel', {
        method: 'POST',
        body: JSON.stringify({ reason }),
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.subscription });
    },
    onError: () => {
      toast.error('구독 해지에 실패했어요. 다시 시도해주세요.');
    },
  });
}

export function useResumeSubscription() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: () =>
      apiFetch('/api/v1/subscription/resume', {
        method: 'POST',
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.subscription });
    },
    onError: () => {
      toast.error('구독 재개에 실패했어요. 다시 시도해주세요.');
    },
  });
}
