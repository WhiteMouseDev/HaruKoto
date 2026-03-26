'use client';

import { useQuery } from '@tanstack/react-query';

import {
  fetchContentStats,
  type ContentStatsResponse,
} from '@/lib/api/admin-content';

export function useDashboardStats() {
  return useQuery<ContentStatsResponse>({
    queryKey: ['admin-content-stats'],
    queryFn: fetchContentStats,
    staleTime: 60_000,
  });
}
