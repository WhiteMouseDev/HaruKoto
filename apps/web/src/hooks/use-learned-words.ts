import { useQuery } from '@tanstack/react-query';
import { apiFetch } from '@/lib/api';
import { queryKeys } from '@/lib/query-keys';
import { PAGINATION } from '@/lib/constants';

export type LearnedWord = {
  id: string;
  word: string;
  reading: string;
  meaningKo: string;
  jlptLevel: string;
  exampleSentence: string | null;
  exampleTranslation: string | null;
  correctCount: number;
  incorrectCount: number;
  streak: number;
  mastered: boolean;
  lastReviewedAt: string | null;
};

type LearnedWordsResponse = {
  entries: LearnedWord[];
  total: number;
  page: number;
  totalPages: number;
  summary: {
    totalLearned: number;
    mastered: number;
    learning: number;
  };
};

type LearnedWordsParams = {
  page: number;
  sort: string;
  search: string;
  filter: string;
};

export function useLearnedWords(params: LearnedWordsParams) {
  return useQuery<LearnedWordsResponse>({
    queryKey: queryKeys.learnedWords(params),
    queryFn: () => {
      const searchParams = new URLSearchParams({
        page: String(params.page),
        limit: String(PAGINATION.DEFAULT_PAGE_SIZE),
        sort: params.sort,
      });
      if (params.search) searchParams.set('search', params.search);
      if (params.filter !== 'ALL') searchParams.set('filter', params.filter);

      return apiFetch<LearnedWordsResponse>(
        `/api/v1/study/learned-words?${searchParams.toString()}`
      );
    },
    staleTime: 2 * 60 * 1000,
  });
}
