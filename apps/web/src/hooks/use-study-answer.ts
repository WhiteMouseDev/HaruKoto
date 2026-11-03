'use client';

import { useEffect, useRef, useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { apiFetch } from '@/lib/api';
import { createClient } from '@/lib/supabase/client';
import { queryKeys } from '@/lib/query-keys';
import { studyWriteErrorMessage } from '@/lib/study-write-stop';

type AccountBoundary = { userId: string | null; generation: number };

/** Refresh attendance/progress only after a saved answer from the same login generation. */
export function useStudyAnswer<Parameters, Response = unknown>(
  url: string,
  options: { refreshSavedQuizzes?: boolean } = {}
) {
  const queryClient = useQueryClient();
  const [supabase] = useState(createClient);
  const account = useRef<{
    userId: string | null | undefined;
    generation: number;
  }>({
    userId: undefined,
    generation: 0,
  });

  useEffect(() => {
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      const userId = session?.user.id ?? null;
      if (
        account.current.userId !== undefined &&
        account.current.userId !== userId
      ) {
        account.current.generation += 1;
      }
      account.current.userId = userId;
    });
    return () => subscription.unsubscribe();
  }, [supabase]);

  return useMutation<Response, Error, Parameters, AccountBoundary>({
    onMutate: async () => {
      // Local session identity is only a cache guard. The server still verifies
      // cookie authentication and session ownership on every answer request.
      const {
        data: { session },
      } = await supabase.auth.getSession();
      const userId = session?.user.id ?? null;
      if (account.current.userId === undefined) account.current.userId = userId;
      return { userId, generation: account.current.generation };
    },
    mutationFn: (parameters) =>
      apiFetch<Response>(url, {
        method: 'POST',
        body: JSON.stringify(parameters),
      }),
    onSuccess: async (_data, _parameters, boundary) => {
      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (
        !boundary?.userId ||
        session?.user.id !== boundary.userId ||
        account.current.userId !== boundary.userId ||
        account.current.generation !== boundary.generation
      )
        return;
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: queryKeys.dashboard }),
        queryClient.invalidateQueries({ queryKey: queryKeys.profile }),
        queryClient.invalidateQueries({ queryKey: ['stats-history'] }),
        ...(options.refreshSavedQuizzes
          ? [
              queryClient.invalidateQueries({
                queryKey: queryKeys.quizIncomplete,
              }),
            ]
          : []),
      ]);
    },
    onError: (error, _parameters, boundary) => {
      if (
        boundary &&
        (account.current.userId !== boundary.userId ||
          account.current.generation !== boundary.generation)
      )
        return;
      toast.error(studyWriteErrorMessage(error, '답안 저장에 실패했어요.'));
    },
  });
}
