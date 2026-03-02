import type { JlptLevel } from './content';

export type User = {
  id: string;
  email: string;
  nickname: string;
  avatarUrl: string | null;
  jlptLevel: JlptLevel;
  goal: string;
  experiencePoints: number;
  level: number;
  streakCount: number;
  lastStudyDate: string | null;
  isPremium: boolean;
  subscriptionExpiresAt: string | null;
  dailyGoal: number;
  createdAt: string;
  updatedAt: string;
};

export type UserProfile = Omit<User, 'createdAt' | 'updatedAt'>;
