import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiFetch } from '@/lib/api';
import { queryKeys } from '@/lib/query-keys';
import { PAGINATION } from '@/lib/constants';

export type WordbookEntry = {
  id: string;
  word: string;
  reading: string;
  meaningKo: string;
  source: 'QUIZ' | 'CONVERSATION' | 'MANUAL';
  note?: string;
  createdAt: string;
};

type WordbookResponse = {
  entries: WordbookEntry[];
  total: number;
  page: number;
  totalPages: number;
};

type WordbookParams = {
  page: number;
  sort: string;
  search: string;
  filter: string;
};

export function useWordbook(params: WordbookParams) {
  return useQuery<WordbookResponse>({
    queryKey: queryKeys.wordbook(params),
    queryFn: () => {
      const searchParams = new URLSearchParams({
        page: String(params.page),
        limit: String(PAGINATION.DEFAULT_PAGE_SIZE),
        sort: params.sort,
      });
      if (params.search) searchParams.set('search', params.search);
      if (params.filter !== 'ALL') searchParams.set('source', params.filter);

      return apiFetch<WordbookResponse>(
        `/api/v1/wordbook?${searchParams.toString()}`
      );
    },
    staleTime: 2 * 60 * 1000,
  });
}

export function useAddWord() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: {
      word: string;
      reading: string;
      meaningKo: string;
      source?: 'QUIZ' | 'CONVERSATION' | 'MANUAL';
      note?: string;
    }) =>
      apiFetch('/api/v1/wordbook', {
        method: 'POST',
        body: JSON.stringify(data),
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['wordbook'] });
    },
  });
}

export function useDeleteWord() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) =>
      apiFetch(`/api/v1/wordbook/${id}`, { method: 'DELETE' }),
    onMutate: async (id) => {
      await queryClient.cancelQueries({ queryKey: ['wordbook'] });

      const queries = queryClient.getQueriesData<WordbookResponse>({
        queryKey: ['wordbook'],
      });

      const snapshots: [readonly unknown[], WordbookResponse | undefined][] = [];
      for (const [key, data] of queries) {
        snapshots.push([key, data]);
        if (data) {
          queryClient.setQueryData<WordbookResponse>(key, {
            ...data,
            entries: data.entries.filter((e) => e.id !== id),
          });
        }
      }

      return { snapshots };
    },
    onError: (_err, _id, context) => {
      if (context?.snapshots) {
        for (const [key, data] of context.snapshots) {
          queryClient.setQueryData(key, data);
        }
      }
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['wordbook'] });
    },
  });
}
