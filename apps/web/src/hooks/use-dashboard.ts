import { useQuery } from '@tanstack/react-query';
import { apiFetch } from '@/lib/api';

export type DashboardData = {
  today: {
    wordsStudied: number;
    quizzesCompleted: number;
    correctAnswers: number;
    totalAnswers: number;
    xpEarned: number;
    goalProgress: number;
  };
  streak: { current: number; longest: number };
  weeklyStats: { date: string; wordsStudied: number; xpEarned: number }[];
  levelProgress: {
    vocabulary: { total: number; mastered: number; inProgress: number };
    grammar: { total: number; mastered: number; inProgress: number };
  };
};

export type ProfileData = {
  profile: {
    nickname: string;
    jlptLevel: string;
    dailyGoal: number;
    experiencePoints: number;
    level: number;
    streakCount: number;
  };
  summary: {
    totalWordsStudied: number;
    totalQuizzesCompleted: number;
    totalXpEarned: number;
  };
};

export function useDashboard() {
  return useQuery<DashboardData>({
    queryKey: ['dashboard'],
    queryFn: () => apiFetch<DashboardData>('/api/v1/stats/dashboard'),
  });
}

export function useProfile() {
  return useQuery<ProfileData>({
    queryKey: ['profile'],
    queryFn: () => apiFetch<ProfileData>('/api/v1/user/profile'),
  });
}
