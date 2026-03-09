'use client';

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { apiFetch } from '@/lib/api';
import { queryKeys } from '@/lib/query-keys';

// Types

type IncompleteSession = {
  id: string;
  quizType: string;
  jlptLevel: string;
  totalQuestions: number;
  answeredCount: number;
  correctCount: number;
  startedAt: string;
};

type StudyStats = {
  totalCount: number;
  studiedCount: number;
  progress: number;
};

type QuizOption = {
  id: string;
  text: string;
};

type QuizQuestion = {
  questionId: string;
  questionText: string;
  questionSubText: string | null;
  hint: string | null;
  options: QuizOption[];
  correctOptionId: string;
  // Cloze fields
  sentence?: string;
  translation?: string;
  explanation?: string;
  grammarPoint?: string | null;
  // SentenceArrange fields
  koreanSentence?: string;
  japaneseSentence?: string;
  tokens?: { text: string; type: 'noun' | 'particle' | 'verb' | 'adjective' | 'copula' | 'adverb' | 'suffix'; meaning: string; order: number }[];
  // Typing fields
  prompt?: string;
  answer?: string;
  distractors?: string[];
};

type StartQuizParams = {
  quizType: string;
  jlptLevel: string;
  count: number;
  mode?: string;
};

type StartQuizResponse = {
  sessionId: string;
  questions: QuizQuestion[];
};

type ResumeQuizResponse = {
  sessionId: string;
  questions: QuizQuestion[];
  answeredQuestionIds: string[];
  correctCount: number;
  quizType?: string;
};

type AnswerQuestionParams = {
  sessionId: string;
  questionId: string;
  selectedOptionId: string;
  isCorrect: boolean;
  timeSpentSeconds: number;
  questionType: string;
};

type CompleteQuizParams = {
  sessionId: string;
};

type CompleteQuizResponse = {
  correctCount: number;
  totalQuestions: number;
  xpEarned: number;
  accuracy: number;
  currentXp?: number;
  xpForNext?: number;
  events?: { type: 'level_up' | 'streak' | 'achievement'; data: Record<string, unknown> }[];
};

type WrongAnswer = {
  questionId: string;
  word: string;
  reading: string | null;
  meaningKo: string;
  exampleSentence: string | null;
  exampleTranslation: string | null;
};

// Query hooks

export function useIncompleteQuiz() {
  return useQuery<{ session: IncompleteSession | null }>({
    queryKey: queryKeys.quizIncomplete,
    queryFn: () =>
      apiFetch<{ session: IncompleteSession | null }>(
        '/api/v1/quiz/incomplete'
      ),
    staleTime: 30 * 1000,
  });
}

export function useQuizStats(level: string, type: string) {
  return useQuery<StudyStats>({
    queryKey: [...queryKeys.quizStats, level, type],
    queryFn: () =>
      apiFetch<StudyStats>(
        `/api/v1/quiz/stats?level=${level}&type=${type}`
      ),
    staleTime: 2 * 60 * 1000,
  });
}

export function useWrongAnswers(sessionId: string | null) {
  return useQuery<{ wrongAnswers: WrongAnswer[] }>({
    queryKey: ['wrong-answers', sessionId],
    queryFn: () =>
      apiFetch<{ wrongAnswers: WrongAnswer[] }>(
        `/api/v1/quiz/wrong-answers?sessionId=${sessionId}`
      ),
    enabled: !!sessionId,
    staleTime: 5 * 60 * 1000,
  });
}

type RecommendationData = {
  reviewDueCount: number;
  newWordsCount: number;
  wrongCount: number;
  lastReviewedAt: string | null;
};

export function useRecommendations() {
  return useQuery<RecommendationData>({
    queryKey: ['recommendations'],
    queryFn: () =>
      apiFetch<RecommendationData>('/api/v1/quiz/recommendations'),
    staleTime: 2 * 60 * 1000,
  });
}

// Mutation hooks

export function useStartQuiz() {
  const queryClient = useQueryClient();

  return useMutation<StartQuizResponse, Error, StartQuizParams>({
    mutationFn: (params) =>
      apiFetch<StartQuizResponse>('/api/v1/quiz/start', {
        method: 'POST',
        body: JSON.stringify(params),
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.quizIncomplete });
    },
    onError: () => {
      toast.error('퀴즈를 시작할 수 없어요. 다시 시도해주세요.');
    },
  });
}

export function useResumeQuiz() {
  return useMutation<ResumeQuizResponse, Error, { sessionId: string }>({
    mutationFn: (params) =>
      apiFetch<ResumeQuizResponse>('/api/v1/quiz/resume', {
        method: 'POST',
        body: JSON.stringify(params),
      }),
    onError: () => {
      toast.error('퀴즈를 이어할 수 없어요. 다시 시도해주세요.');
    },
  });
}

export function useAnswerQuestion() {
  return useMutation<unknown, Error, AnswerQuestionParams>({
    mutationFn: (params) =>
      apiFetch('/api/v1/quiz/answer', {
        method: 'POST',
        body: JSON.stringify(params),
      }),
    onError: () => {
      toast.error('답안 저장에 실패했어요.');
    },
  });
}

export function useCompleteQuiz() {
  const queryClient = useQueryClient();

  return useMutation<CompleteQuizResponse, Error, CompleteQuizParams>({
    mutationFn: (params) =>
      apiFetch<CompleteQuizResponse>('/api/v1/quiz/complete', {
        method: 'POST',
        body: JSON.stringify(params),
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.dashboard });
      queryClient.invalidateQueries({ queryKey: queryKeys.profile });
      queryClient.invalidateQueries({ queryKey: queryKeys.notifications });
      queryClient.invalidateQueries({ queryKey: queryKeys.quizStats });
      queryClient.invalidateQueries({ queryKey: queryKeys.quizIncomplete });
    },
    onError: () => {
      toast.error('퀴즈 완료 처리에 실패했어요.');
    },
  });
}

// Re-export types
export type {
  IncompleteSession,
  StudyStats,
  QuizQuestion,
  QuizOption,
  CompleteQuizResponse,
  WrongAnswer,
  RecommendationData,
};
