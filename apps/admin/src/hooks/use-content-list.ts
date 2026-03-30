'use client';

import { useQuery, keepPreviousData } from '@tanstack/react-query';
import { useSearchParams } from 'next/navigation';

import { fetchAdminContent, type PaginatedResponse } from '@/lib/api/admin-content';

export type ContentType = 'vocabulary' | 'grammar' | 'quiz' | 'conversation';

export function useContentList<T>(type: ContentType) {
  const searchParams = useSearchParams();

  const page = searchParams.get('page') ?? '1';
  const search = searchParams.get('q') ?? undefined;
  const jlpt_level = searchParams.get('jlpt') ?? undefined;
  const review_status = searchParams.get('status') ?? undefined;
  const category = searchParams.get('category') ?? undefined;
  const quiz_type = searchParams.get('quiz_type') ?? undefined;
  const sort_by = searchParams.get('sort_by') ?? undefined;
  const sort_order = searchParams.get('sort_order') ?? undefined;

  const params: Record<string, string | undefined> = {
    page,
    page_size: '20',
    search,
    jlpt_level,
    review_status,
    category,
    quiz_type,
    sort_by,
    sort_order,
  };

  return useQuery<PaginatedResponse<T>>({
    queryKey: ['admin-content', type, params],
    queryFn: () => fetchAdminContent<T>(type, params),
    staleTime: 30_000,
    placeholderData: keepPreviousData,
  });
}
