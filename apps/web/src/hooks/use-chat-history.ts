import { useInfiniteQuery } from '@tanstack/react-query';
import { apiFetch } from '@/lib/api';
import { queryKeys } from '@/lib/query-keys';

export type HistoryItem = {
  id: string;
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
