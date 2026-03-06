'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import { RefreshCw } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import { PeriodTab } from '@/components/features/stats/period-tab';
import { StudyTab } from '@/components/features/stats/study-tab';
import { JlptTab } from '@/components/features/stats/jlpt-tab';
import { useDashboard, useProfile } from '@/hooks/use-dashboard';
import { useStatsHistory } from '@/hooks/use-stats-history';

const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.08 },
  },
};

const item = {
  hidden: { opacity: 0, y: 16 },
  show: { opacity: 1, y: 0, transition: { duration: 0.35 } },
};

export default function StatsPage() {
  const [heatmapYear, setHeatmapYear] = useState(new Date().getFullYear());

  const {
    data: dashboard,
    isLoading: dashboardLoading,
    error: dashboardError,
    refetch: refetchDashboard,
  } = useDashboard();

  const { data: profileData, isLoading: profileLoading } = useProfile();

  const {
    data: historyRecords = [],
  } = useStatsHistory(heatmapYear);

  const loading = dashboardLoading || profileLoading;
  const error = dashboardError
    ? dashboardError instanceof Error
      ? dashboardError.message
      : '데이터를 불러올 수 없습니다.'
    : null;

  // Loading skeleton
  if (loading) {
    return (
      <div className="flex flex-col gap-4 p-4">
        <div className="pt-2">
          <div className="bg-secondary h-7 w-28 animate-pulse rounded" />
        </div>
        <div className="bg-secondary h-10 w-full animate-pulse rounded-lg" />
        {[1, 2, 3].map((n) => (
          <div
            key={n}
            className="bg-secondary h-40 animate-pulse rounded-xl"
          />
        ))}
      </div>
    );
  }

  // Error state
  if (error) {
    return (
      <div className="flex flex-col items-center justify-center gap-4 p-8">
        <p className="text-muted-foreground text-center">{error}</p>
        <Button variant="outline" onClick={() => refetchDashboard()} className="gap-2">
          <RefreshCw className="size-4" />
          다시 시도
        </Button>
      </div>
    );
  }

  if (!dashboard || !profileData) return null;

  const jlptLevel = profileData.profile.jlptLevel || 'N5';

  return (
    <motion.div
      className="flex flex-col gap-4 p-4"
      variants={container}
      initial="hidden"
      animate="show"
    >
      {/* Header */}
      <motion.div variants={item} className="pt-2">
        <h1 className="text-2xl font-bold">학습 통계</h1>
      </motion.div>

      {/* Tabs */}
      <motion.div variants={item}>
        <Tabs defaultValue="period">
          <TabsList className="w-full">
            <TabsTrigger value="period" className="flex-1">
              기간별
            </TabsTrigger>
            <TabsTrigger value="study" className="flex-1">
              학습별
            </TabsTrigger>
            <TabsTrigger value="jlpt" className="flex-1">
              JLPT 진도
            </TabsTrigger>
          </TabsList>

          <TabsContent value="period" className="mt-4">
            <PeriodTab
              today={dashboard.today}
              historyRecords={historyRecords}
              heatmapYear={heatmapYear}
              onHeatmapYearChange={setHeatmapYear}
            />
          </TabsContent>

          <TabsContent value="study" className="mt-4">
            <StudyTab
              levelProgress={dashboard.levelProgress}
              historyRecords={historyRecords}
            />
          </TabsContent>

          <TabsContent value="jlpt" className="mt-4">
            <JlptTab
              levelProgress={dashboard.levelProgress}
              currentLevel={jlptLevel}
            />
          </TabsContent>
        </Tabs>
      </motion.div>
    </motion.div>
  );
}
