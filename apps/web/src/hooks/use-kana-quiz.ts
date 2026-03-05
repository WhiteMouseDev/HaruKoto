'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { apiFetch } from '@/lib/api';
import { queryKeys } from '@/lib/query-keys';

type QuizQuestion = {
  questionId: string;
  questionText: string;
  questionSubText: string | null;
  options: { id: string; text: string }[];
  correctOptionId: string;
};

type StartKanaQuizParams = {
  kanaType: string;
  stageNumber?: number;
  quizMode: string;
  count: number;
};

type StartKanaQuizResponse = {
  sessionId: string | null;
  questions: QuizQuestion[];
  message?: string;
};

type AnswerKanaQuestionParams = {
  sessionId: string;
  questionId: string;
  selectedOptionId: string;
};

type CompleteKanaQuizResponse = {
  accuracy: number;
  xpEarned: number;
  currentXp: number;
  xpForNext: number;
};

export function useStartKanaQuiz() {
  return useMutation<StartKanaQuizResponse, Error, StartKanaQuizParams>({
    mutationFn: (params) =>
      apiFetch<StartKanaQuizResponse>('/api/v1/kana/quiz/start', {
        method: 'POST',
        body: JSON.stringify(params),
      }),
  });
}

export function useAnswerKanaQuestion() {
  return useMutation<unknown, Error, AnswerKanaQuestionParams>({
    mutationFn: (params) =>
      apiFetch('/api/v1/kana/quiz/answer', {
        method: 'POST',
        body: JSON.stringify(params),
      }),
  });
}

export function useCompleteKanaQuiz() {
  const queryClient = useQueryClient();

  return useMutation<CompleteKanaQuizResponse, Error, { sessionId: string }>({
    mutationFn: (params) =>
      apiFetch<CompleteKanaQuizResponse>('/api/v1/kana/quiz/complete', {
        method: 'POST',
        body: JSON.stringify(params),
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.dashboard });
      queryClient.invalidateQueries({ queryKey: queryKeys.kanaProgress });
      queryClient.invalidateQueries({
        queryKey: queryKeys.kanaStages('HIRAGANA'),
      });
      queryClient.invalidateQueries({
        queryKey: queryKeys.kanaStages('KATAKANA'),
      });
    },
  });
}
