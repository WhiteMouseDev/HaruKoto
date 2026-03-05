import { useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { apiFetch } from '@/lib/api';
import { queryKeys } from '@/lib/query-keys';

export type HistoryItem = {
  id: string;
  type: 'VOICE' | 'TEXT';
  createdAt: string;
  endedAt: string | null;
  messageCount: number;
  overallScore: number | null;
  scenario: {
    title: string;
    titleJa: string;
    category: string;
    difficulty: string;
  } | null;
  character: {
    id: string;
    name: string;
    nameJa: string;
    avatarEmoji: string;
    avatarUrl: string | null;
  } | null;
};

type HistoryResponse = {
  history: HistoryItem[];
  nextCursor: string | null;
};

export function useChatHistory() {
  return useInfiniteQuery<HistoryResponse>({
    queryKey: queryKeys.chatHistory,
    queryFn: ({ pageParam }) => {
      const url = pageParam
        ? `/api/v1/chat/history?limit=5&cursor=${pageParam}`
        : '/api/v1/chat/history?limit=5';
      return apiFetch<HistoryResponse>(url);
    },
    initialPageParam: null as string | null,
    getNextPageParam: (lastPage) => lastPage.nextCursor,
    staleTime: 60 * 1000,
  });
}

export function useDeleteConversation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (conversationId: string) =>
      apiFetch(`/api/v1/chat/${conversationId}`, { method: 'DELETE' }),
    onMutate: async (conversationId) => {
      await queryClient.cancelQueries({ queryKey: queryKeys.chatHistory });

      const previous = queryClient.getQueryData(queryKeys.chatHistory);

      queryClient.setQueryData<{ pages: HistoryResponse[]; pageParams: (string | null)[] }>(
        queryKeys.chatHistory,
        (old) => {
          if (!old) return old;
          return {
            ...old,
            pages: old.pages.map((page) => ({
              ...page,
              history: page.history.filter((item) => item.id !== conversationId),
            })),
          };
        }
      );

      return { previous };
    },
    onError: (_err, _id, context) => {
      if (context?.previous) {
        queryClient.setQueryData(queryKeys.chatHistory, context.previous);
      }
      toast.error('삭제에 실패했어요. 다시 시도해주세요.');
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.chatHistory });
    },
  });
}
