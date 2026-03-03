'use client';

import { useState, useCallback } from 'react';
import { motion } from 'framer-motion';
import { LogOut } from 'lucide-react';
import { ProfileHeader } from '@/components/features/my/profile-header';
import { StatsOverview } from '@/components/features/my/stats-overview';
import { SettingsMenu } from '@/components/features/my/settings-menu';
import { Button } from '@/components/ui/button';
import { createClient } from '@/lib/supabase/client';
import { useProfile } from '@/hooks/use-dashboard';
import { useUpdateProfile } from '@/hooks/use-update-profile';

type JlptLevel = 'N5' | 'N4' | 'N3' | 'N2' | 'N1';

type MyProfileData = {
  profile: {
    id: string;
    nickname: string;
    avatarUrl: string | null;
    jlptLevel: JlptLevel;
    dailyGoal: number;
    experiencePoints: number;
    level: number;
    streakCount: number;
    longestStreak: number;
    createdAt: string;
  };
  summary: {
    totalWordsStudied: number;
    totalQuizzesCompleted: number;
    totalStudyDays: number;
    totalXpEarned: number;
  };
};

export default function MyPage() {
  const { data, isLoading: loading } = useProfile() as {
    data: MyProfileData | undefined;
    isLoading: boolean;
  };
  const updateProfile = useUpdateProfile();
  const [loggingOut, setLoggingOut] = useState(false);

  const handleUpdate = useCallback(
    async (field: string, value: unknown) => {
      await updateProfile.mutateAsync({ [field]: value });
    },
    [updateProfile]
  );

  const handleLogout = async () => {
    setLoggingOut(true);
    try {
      const supabase = createClient();
      await supabase.auth.signOut();
      window.location.href = '/login';
    } catch {
      setLoggingOut(false);
    }
  };

  if (loading) {
    return (
      <div className="flex flex-col gap-4 p-4">
        <h1 className="pt-2 text-2xl font-bold">MY</h1>
        <div className="flex items-center gap-4">
          <div className="bg-muted size-16 animate-pulse rounded-full" />
          <div className="flex flex-col gap-2">
            <div className="bg-muted h-5 w-24 animate-pulse rounded" />
            <div className="bg-muted h-4 w-32 animate-pulse rounded" />
          </div>
        </div>
        <div className="grid grid-cols-2 gap-3">
          {Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="bg-muted h-24 animate-pulse rounded-xl" />
          ))}
        </div>
      </div>
    );
  }

  if (!data) {
    return (
      <div className="flex flex-col gap-4 p-4">
        <h1 className="pt-2 text-2xl font-bold">MY</h1>
        <p className="text-muted-foreground">
          프로필을 불러올 수 없습니다. 다시 시도해주세요.
        </p>
      </div>
    );
  }

  const { profile, summary } = data;

  return (
    <div className="flex flex-col gap-6 p-4">
      <h1 className="pt-2 text-2xl font-bold">MY</h1>

      <ProfileHeader
        nickname={profile.nickname}
        avatarUrl={profile.avatarUrl}
        jlptLevel={profile.jlptLevel}
        createdAt={profile.createdAt}
      />

      <StatsOverview
        totalStudyDays={summary.totalStudyDays}
        totalWordsStudied={summary.totalWordsStudied}
        experiencePoints={profile.experiencePoints}
        level={profile.level}
        longestStreak={profile.longestStreak}
      />

      <SettingsMenu
        jlptLevel={profile.jlptLevel}
        dailyGoal={profile.dailyGoal}
        onUpdate={handleUpdate}
      />

      <motion.div
        className="flex flex-col items-center gap-3 pt-2"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.3 }}
      >
        <Button
          variant="ghost"
          className="text-destructive hover:text-destructive w-full"
          onClick={handleLogout}
          disabled={loggingOut}
        >
          <LogOut className="size-4" />
          {loggingOut ? '로그아웃 중...' : '로그아웃'}
        </Button>
        <span className="text-muted-foreground text-xs">v0.1.0</span>
      </motion.div>
    </div>
  );
}
