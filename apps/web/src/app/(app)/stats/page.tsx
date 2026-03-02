'use client';

import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { RefreshCw } from 'lucide-react';
import { apiFetch } from '@/lib/api';
import { Button } from '@/components/ui/button';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import { PeriodTab } from '@/components/features/stats/period-tab';
import { StudyTab } from '@/components/features/stats/study-tab';
import { JlptTab } from '@/components/features/stats/jlpt-tab';

type DashboardData = {
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

type HistoryRecord = {
  date: string;
  wordsStudied: number;
  quizzesCompleted: number;
  correctAnswers: number;
  totalAnswers: number;
  conversationCount: number;
  studyTimeSeconds: number;
  xpEarned: number;
};

type HistoryData = {
  year: number;
  month: number;
  records: HistoryRecord[];
};

type ProfileData = {
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

async function fetchAllHistory(year: number): Promise<HistoryRecord[]> {
  const now = new Date();
  const currentYear = now.getFullYear();
  const currentMonth = now.getMonth() + 1;

  const maxMonth = year === currentYear ? currentMonth : 12;

  const promises = Array.from({ length: maxMonth }, (_, i) =>
    apiFetch<HistoryData>(
      `/api/v1/stats/history?year=${year}&month=${i + 1}`
    ).catch(() => ({ year, month: i + 1, records: [] as HistoryRecord[] }))
  );

  const results = await Promise.all(promises);
  return results.flatMap((r) => r.records);
}

export default function StatsPage() {
  const [dashboard, setDashboard] = useState<DashboardData | null>(null);
  const [profile, setProfile] = useState<ProfileData | null>(null);
  const [historyRecords, setHistoryRecords] = useState<HistoryRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [heatmapYear, setHeatmapYear] = useState(new Date().getFullYear());

  async function fetchData() {
    setLoading(true);
    setError(null);
    try {
      const [dashboardRes, profileRes, history] = await Promise.all([
        apiFetch<DashboardData>('/api/v1/stats/dashboard'),
        apiFetch<ProfileData>('/api/v1/user/profile'),
        fetchAllHistory(heatmapYear),
      ]);
      setDashboard(dashboardRes);
      setProfile(profileRes);
      setHistoryRecords(history);
    } catch (err) {
      setError(
        err instanceof Error ? err.message : '데이터를 불러올 수 없습니다.'
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    fetchData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Re-fetch history when heatmap year changes
  useEffect(() => {
    if (!loading) {
      fetchAllHistory(heatmapYear)
        .then(setHistoryRecords)
        .catch(() => setHistoryRecords([]));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [heatmapYear]);

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
        <Button variant="outline" onClick={fetchData} className="gap-2">
          <RefreshCw className="size-4" />
          다시 시도
        </Button>
      </div>
    );
  }

  if (!dashboard || !profile) return null;

  const jlptLevel = profile.profile.jlptLevel || 'N5';

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
              today={dashboard.today}
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
