import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiFetch } from '@/lib/api';
import { queryKeys } from '@/lib/query-keys';

export type KanaCharacterData = {
  id: string;
  kanaType: 'HIRAGANA' | 'KATAKANA';
  character: string;
  romaji: string;
  pronunciation: string;
  row: string;
  column: string;
  strokeCount: number;
  exampleWord: string | null;
  exampleReading: string | null;
  exampleMeaning: string | null;
  category: string;
  order: number;
  progress: {
    correctCount: number;
    incorrectCount: number;
    streak: number;
    mastered: boolean;
    lastReviewedAt: string | null;
  } | null;
};

export type KanaStageData = {
  id: string;
  kanaType: 'HIRAGANA' | 'KATAKANA';
  stageNumber: number;
  title: string;
  description: string;
  characters: string[];
  isUnlocked: boolean;
  isCompleted: boolean;
  quizScore: number | null;
  completedAt: string | null;
};

export type KanaProgressData = {
  hiragana: { learned: number; mastered: number; total: number; pct: number };
  katakana: { learned: number; mastered: number; total: number; pct: number };
};

export function useKanaCharacters(type: 'HIRAGANA' | 'KATAKANA', category?: string) {
  const categoryParam = category ? `&category=${category}` : '';
  return useQuery<{ characters: KanaCharacterData[] }>({
    queryKey: queryKeys.kanaCharacters(type, category),
    queryFn: () =>
      apiFetch<{ characters: KanaCharacterData[] }>(
        `/api/v1/kana/characters?type=${type}${categoryParam}`
      ),
    staleTime: 5 * 60 * 1000,
  });
}

export function useKanaStages(type: 'HIRAGANA' | 'KATAKANA') {
  return useQuery<{ stages: KanaStageData[] }>({
    queryKey: queryKeys.kanaStages(type),
    queryFn: () =>
      apiFetch<{ stages: KanaStageData[] }>(
        `/api/v1/kana/stages?type=${type}`
      ),
    staleTime: 2 * 60 * 1000,
  });
}

export function useKanaProgress() {
  return useQuery<KanaProgressData>({
    queryKey: queryKeys.kanaProgress,
    queryFn: () => apiFetch<KanaProgressData>('/api/v1/kana/progress'),
    staleTime: 2 * 60 * 1000,
  });
}

export function useUpdateKanaProgress() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: { kanaId: string; learned: boolean }) =>
      apiFetch('/api/v1/kana/progress', {
        method: 'POST',
        body: JSON.stringify(data),
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.kanaProgress });
      queryClient.invalidateQueries({
        queryKey: ['kana-characters'],
      });
    },
  });
}

export function useCompleteKanaStage() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: { stageId: string; quizScore?: number }) =>
      apiFetch('/api/v1/kana/stage-complete', {
        method: 'POST',
        body: JSON.stringify(data),
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.kanaProgress });
      queryClient.invalidateQueries({
        queryKey: queryKeys.kanaStages('HIRAGANA'),
      });
      queryClient.invalidateQueries({
        queryKey: queryKeys.kanaStages('KATAKANA'),
      });
      queryClient.invalidateQueries({ queryKey: queryKeys.dashboard });
    },
  });
}
