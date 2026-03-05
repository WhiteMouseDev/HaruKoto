'use client';

import { useQuery } from '@tanstack/react-query';
import { queryKeys } from '@/lib/query-keys';
import { apiFetch } from '@/lib/api';
import type { PaymentRecord } from '@/types/subscription';

type PaymentsResponse = {
  payments: PaymentRecord[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
};

export function usePayments(page: number = 1) {
  return useQuery<PaymentsResponse>({
    queryKey: queryKeys.payments(page),
    queryFn: () => apiFetch<PaymentsResponse>(`/api/v1/payments?page=${page}`),
    staleTime: 5 * 60 * 1000,
  });
}
