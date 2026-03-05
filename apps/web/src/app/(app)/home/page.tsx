'use client';

import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { RefreshCw } from 'lucide-react';
import { useDashboard, useProfile } from '@/hooks/use-dashboard';
import { useDailyMissions, useClaimMissionReward } from '@/hooks/use-daily-missions';
import { KanaCtaCard } from '@/components/features/dashboard/kana-cta-card';
import { NotificationCenter } from '@/components/features/notifications/notification-center';
import { PhoneCallCta } from '@/components/features/chat/phone-call-cta';
import { Button } from '@/components/ui/button';
import { StreakBadge } from '@/components/features/dashboard/streak-badge';
import { DailyProgressCard } from '@/components/features/dashboard/daily-progress-card';
import { DailyMissionsCard } from '@/components/features/dashboard/daily-missions-card';
import { WeeklyChart } from '@/components/features/dashboard/weekly-chart';
import { QuickStartCard } from '@/components/features/dashboard/quick-start-card';
import { LevelProgress } from '@/components/features/dashboard/level-progress';

const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.1 },
  },
};

const item = {
  hidden: { opacity: 0, y: 20 },
  show: { opacity: 1, y: 0, transition: { duration: 0.5 } },
};

export default function HomePage() {
  const router = useRouter();
  const { data: dashboard, isLoading, error, refetch } = useDashboard();
  const { data: profile } = useProfile();
  const { data: missionsData } = useDailyMissions();
  const claimReward = useClaimMissionReward();

  // Loading skeleton
  if (isLoading) {
    return (
      <div className="flex flex-col gap-5 px-6 pt-12 pb-6">
        <div className="flex items-end justify-between">
          <div className="flex flex-col gap-2">
            <div className="bg-secondary h-4 w-16 rounded">
              <div className="h-full animate-shimmer rounded" />
            </div>
            <div className="bg-secondary h-7 w-36 rounded">
              <div className="h-full animate-shimmer rounded" />
            </div>
          </div>
          <div className="bg-secondary h-10 w-10 rounded-full">
            <div className="h-full animate-shimmer rounded-full" />
          </div>
        </div>
        {[1, 2, 3, 4].map((n) => (
          <div key={n} className="bg-secondary h-36 rounded-3xl">
            <div className="h-full animate-shimmer rounded-3xl" />
          </div>
        ))}
      </div>
    );
  }

  // Error state
  if (error) {
    return (
      <div className="flex flex-col items-center justify-center gap-4 p-8">
        <p className="text-muted-foreground text-center">{error?.message}</p>
        <Button variant="outline" onClick={() => refetch()} className="gap-2">
          <RefreshCw className="size-4" />
          다시 시도
        </Button>
      </div>
    );
  }

  if (!dashboard || !profile) return null;

  const { nickname, jlptLevel, dailyGoal } = profile.profile;

  return (
    <motion.div
      className="flex flex-col gap-5 px-6 pt-12 pb-6"
      variants={container}
      initial="hidden"
      animate="show"
    >
      {/* Header */}
      <motion.header
        variants={item}
        className="flex items-end justify-between pb-2"
      >
        <div>
          <p className="text-muted-foreground mb-1 text-sm font-medium">
            おはよう!
          </p>
          <h1 className="text-2xl font-bold tracking-tight">
            안녕, {nickname || '학습자'}!
          </h1>
        </div>
        <NotificationCenter />
      </motion.header>

      {/* AI Call CTA */}
      <motion.div variants={item}>
        <PhoneCallCta onClick={() => router.push('/chat/call/contacts')} />
      </motion.div>

      {/* Kana CTA - users with showKana enabled who haven't completed kana */}
      {dashboard.showKana &&
        dashboard.kanaProgress &&
        (dashboard.kanaProgress.hiragana.pct < 100 || dashboard.kanaProgress.katakana.pct < 100) && (
          <motion.div variants={item}>
            <KanaCtaCard />
          </motion.div>
        )}

      {/* Combined: Streak + Daily Progress */}
      <motion.div variants={item}>
        <div className="space-y-6 rounded-3xl border border-border bg-card p-6 shadow-sm">
          <StreakBadge
            currentStreak={dashboard.streak.current}
            weeklyStats={dashboard.weeklyStats}
          />
          <div className="bg-muted/50 h-px w-full" />
          <DailyProgressCard
            dailyGoal={dailyGoal}
            wordsStudied={dashboard.today.wordsStudied}
            correctAnswers={dashboard.today.correctAnswers}
            totalAnswers={dashboard.today.totalAnswers}
            goalProgress={dashboard.today.goalProgress}
          />
        </div>
      </motion.div>

      {/* Daily Missions */}
      {missionsData && (
        <motion.div variants={item}>
          <DailyMissionsCard
            missions={missionsData.missions}
            completedCount={missionsData.completedCount}
            totalCount={missionsData.totalCount}
            onClaim={(id) => claimReward.mutate(id)}
            claiming={claimReward.isPending}
          />
        </motion.div>
      )}

      {/* Quick Start CTA */}
      <motion.div variants={item}>
        <QuickStartCard jlptLevel={jlptLevel || 'N5'} />
      </motion.div>

      {/* Weekly Chart */}
      <motion.div variants={item}>
        <WeeklyChart weeklyStats={dashboard.weeklyStats} dailyGoal={dailyGoal} />
      </motion.div>

      {/* Level Progress */}
      <motion.div variants={item}>
        <LevelProgress currentLevel={jlptLevel || 'N5'} />
      </motion.div>
    </motion.div>
  );
}
