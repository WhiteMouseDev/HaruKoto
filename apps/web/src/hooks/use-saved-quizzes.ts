'use client';

import { useEffect, useState } from 'react';
import { useInfiniteQuery } from '@tanstack/react-query';
import { createClient } from '@/lib/supabase/client';
import type { SavedQuizPage } from '@/lib/quiz-incomplete-sessions';
import { queryKeys } from '@/lib/query-keys';

export function useSavedQuizzes(
  filters: { quizType?: string; jlptLevel?: string } = {}
) {
  const [supabase] = useState(createClient);
  const [account, setAccount] = useState<{
    id: string | null;
    generation: number;
  }>({ id: null, generation: 0 });
  useEffect(() => {
    let active = true;
    let eventReceived = false;
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      eventReceived = true;
      if (active)
        setAccount((previous) => ({
          id: session?.user.id ?? null,
          generation:
            previous.generation +
            (previous.id === (session?.user.id ?? null) ? 0 : 1),
        }));
    });
    void supabase.auth.getSession().then(({ data: { session } }) => {
      if (active && !eventReceived)
        setAccount({ id: session?.user.id ?? null, generation: 0 });
    });
    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, [supabase]);

  return useInfiniteQuery<SavedQuizPage>({
    queryKey: [
      ...queryKeys.quizIncomplete,
      'saved',
      account.id,
      account.generation,
      filters,
    ],
    enabled: account.id !== null,
    initialPageParam: null,
    queryFn: async ({ pageParam, signal }) => {
      const search = new URLSearchParams({ limit: '20', ...filters });
      if (typeof pageParam === 'string') search.set('cursor', pageParam);
      const response = await fetch(
        `/api/v1/quiz/incomplete-sessions?${search}`,
        { signal }
      );
      // An older server may only expose the representative card. Do not turn
      // authentication/network failures into a misleading empty collection.
      if (response.status === 404 && !pageParam) {
        const fallback = await fetch('/api/v1/quiz/incomplete', { signal });
        if (!fallback.ok) throw new Error('저장된 퀴즈를 불러오지 못했어요.');
        const { session } = await fallback.json();
        const matchesFilter =
          session &&
          (!filters.quizType || session.quizType === filters.quizType) &&
          (!filters.jlptLevel || session.jlptLevel === filters.jlptLevel);
        return {
          sessions: matchesFilter
            ? [
                {
                  ...session,
                  mode: null,
                  remainingCount: null,
                  resumeStatus: session.resumeStatus ?? 'available',
                  resumeReason: null,
                },
              ]
            : [],
          nextCursor: null,
        };
      }
      if (!response.ok)
        throw new Error('저장된 퀴즈를 불러오지 못했어요. 다시 시도해 주세요.');
      return response.json();
    },
    getNextPageParam: (page) => page.nextCursor ?? undefined,
    staleTime: 30_000,
  });
}
