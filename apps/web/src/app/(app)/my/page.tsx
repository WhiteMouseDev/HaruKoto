'use client';

import { useState, useCallback } from 'react';
import { motion } from 'framer-motion';
import { LogOut } from 'lucide-react';
import { ProfileHero } from '@/components/features/my/profile-hero';
import { AchievementsSection } from '@/components/features/my/achievements-section';
import { SettingsMenu } from '@/components/features/my/settings-menu';
import { getDefaultCallSettings, type CallSettingsData } from '@/components/features/my/call-settings';
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
    levelProgress: { currentXp: number; xpForNext: number };
    streakCount: number;
    longestStreak: number;
    callSettings: Partial<CallSettingsData> | null;
    createdAt: string;
  };
  summary: {
    totalWordsStudied: number;
    totalQuizzesCompleted: number;
    totalStudyDays: number;
    totalXpEarned: number;
  };
  achievements: {
    achievementType: string;
    achievedAt: string;
  }[];
};

export default function MyPage() {
  const { data, isLoading: loading } = useProfile() as {
    data: MyProfileData | undefined;
    isLoading: boolean;
  };
  const updateProfile = useUpdateProfile();
  const [loggingOut, setLoggingOut] = useState(false);

  const handleNicknameUpdate = useCallback(
    async (nickname: string) => {
      await updateProfile.mutateAsync({ nickname });
    },
    [updateProfile]
  );

  const handleUpdate = useCallback(
    async (field: string, value: unknown) => {
      await updateProfile.mutateAsync({ [field]: value });
    },
    [updateProfile]
  );

  const handleCallSettingsUpdate = useCallback(
    (partial: Partial<CallSettingsData>) => {
      updateProfile.mutate({ callSettings: partial });
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
        {/* ProfileHero skeleton */}
        <div className="rounded-xl border p-4">
          <div className="flex items-center gap-3">
            <div className="bg-muted size-12 animate-pulse rounded-full" />
            <div className="flex flex-col gap-2">
              <div className="bg-muted h-5 w-24 animate-pulse rounded" />
              <div className="bg-muted h-1.5 w-32 animate-pulse rounded-full" />
            </div>
          </div>
          <div className="mt-4 grid grid-cols-4 gap-2">
            {Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="bg-muted h-12 animate-pulse rounded-lg" />
            ))}
          </div>
        </div>
        {/* Achievements skeleton */}
        <div className="bg-muted h-20 animate-pulse rounded-xl" />
        {/* Settings skeleton */}
        <div className="bg-muted h-48 animate-pulse rounded-xl" />
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

  const { profile, summary, achievements } = data;

  return (
    <div className="flex flex-col gap-4 p-4">
      <h1 className="pt-2 text-2xl font-bold">MY</h1>

      <ProfileHero
        nickname={profile.nickname}
        avatarUrl={profile.avatarUrl}
        jlptLevel={profile.jlptLevel}
        experiencePoints={profile.experiencePoints}
        level={profile.level}
        levelProgress={profile.levelProgress}
        totalStudyDays={summary.totalStudyDays}
        totalWordsStudied={summary.totalWordsStudied}
        longestStreak={profile.longestStreak}
        onNicknameUpdate={handleNicknameUpdate}
      />

      <AchievementsSection achievements={achievements} />

      <SettingsMenu
        jlptLevel={profile.jlptLevel}
        dailyGoal={profile.dailyGoal}
        onUpdate={handleUpdate}
        callSettings={{
          ...getDefaultCallSettings(profile.jlptLevel),
          ...(profile.callSettings ?? {}),
        }}
        onCallSettingsUpdate={handleCallSettingsUpdate}
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
