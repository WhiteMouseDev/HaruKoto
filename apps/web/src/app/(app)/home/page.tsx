"use client"

import { useState, useEffect } from "react"
import { motion } from "framer-motion"
import { Bell, RefreshCw } from "lucide-react"
import { apiFetch } from "@/lib/api"
import { Button } from "@/components/ui/button"
import { StreakBadge } from "@/components/features/dashboard/streak-badge"
import { DailyProgressCard } from "@/components/features/dashboard/daily-progress-card"
import { WeeklyChart } from "@/components/features/dashboard/weekly-chart"
import { QuickStartCard } from "@/components/features/dashboard/quick-start-card"
import { LevelProgress } from "@/components/features/dashboard/level-progress"

type DashboardData = {
  today: {
    wordsStudied: number
    quizzesCompleted: number
    correctAnswers: number
    totalAnswers: number
    xpEarned: number
    goalProgress: number
  }
  streak: { current: number; longest: number }
  weeklyStats: { date: string; wordsStudied: number; xpEarned: number }[]
  levelProgress: {
    vocabulary: { total: number; mastered: number; inProgress: number }
    grammar: { total: number; mastered: number; inProgress: number }
  }
}

type ProfileData = {
  profile: {
    nickname: string
    jlptLevel: string
    dailyGoal: number
    experiencePoints: number
    level: number
    streakCount: number
  }
  summary: {
    totalWordsStudied: number
    totalQuizzesCompleted: number
    totalXpEarned: number
  }
}

const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.08 },
  },
}

const item = {
  hidden: { opacity: 0, y: 16 },
  show: { opacity: 1, y: 0, transition: { duration: 0.35 } },
}

export default function HomePage() {
  const [dashboard, setDashboard] = useState<DashboardData | null>(null)
  const [profile, setProfile] = useState<ProfileData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  async function fetchData() {
    setLoading(true)
    setError(null)
    try {
      const [dashboardRes, profileRes] = await Promise.all([
        apiFetch<DashboardData>("/api/v1/stats/dashboard"),
        apiFetch<ProfileData>("/api/v1/user/profile"),
      ])
      setDashboard(dashboardRes)
      setProfile(profileRes)
    } catch (err) {
      setError(err instanceof Error ? err.message : "데이터를 불러올 수 없습니다.")
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchData()
  }, [])

  // Loading skeleton
  if (loading) {
    return (
      <div className="flex flex-col gap-6 p-4">
        <div className="flex items-center justify-between pt-2">
          <div className="flex flex-col gap-2">
            <div className="h-4 w-16 animate-pulse rounded bg-secondary" />
            <div className="h-7 w-36 animate-pulse rounded bg-secondary" />
          </div>
          <div className="h-8 w-16 animate-pulse rounded-full bg-secondary" />
        </div>
        {[1, 2, 3, 4].map((n) => (
          <div
            key={n}
            className="h-32 animate-pulse rounded-xl bg-secondary"
          />
        ))}
      </div>
    )
  }

  // Error state
  if (error) {
    return (
      <div className="flex flex-col items-center justify-center gap-4 p-8">
        <p className="text-center text-muted-foreground">{error}</p>
        <Button variant="outline" onClick={fetchData} className="gap-2">
          <RefreshCw className="size-4" />
          다시 시도
        </Button>
      </div>
    )
  }

  if (!dashboard || !profile) return null

  const { nickname, jlptLevel, dailyGoal } = profile.profile

  return (
    <motion.div
      className="flex flex-col gap-6 p-4"
      variants={container}
      initial="hidden"
      animate="show"
    >
      {/* Header */}
      <motion.div
        variants={item}
        className="flex items-center justify-between pt-2"
      >
        <div>
          <p className="text-sm text-muted-foreground">おはよう!</p>
          <h1 className="text-2xl font-bold">
            안녕, {nickname || "학습자"}!
          </h1>
        </div>
        <button className="flex items-center justify-center rounded-full bg-accent p-2">
          <Bell className="size-5 text-muted-foreground" />
        </button>
      </motion.div>

      {/* Streak Badge */}
      <motion.div variants={item}>
        <StreakBadge
          currentStreak={dashboard.streak.current}
          weeklyStats={dashboard.weeklyStats}
        />
      </motion.div>

      {/* Daily Progress */}
      <motion.div variants={item}>
        <DailyProgressCard
          dailyGoal={dailyGoal}
          wordsStudied={dashboard.today.wordsStudied}
          correctAnswers={dashboard.today.correctAnswers}
          totalAnswers={dashboard.today.totalAnswers}
          goalProgress={dashboard.today.goalProgress}
        />
      </motion.div>

      {/* Quick Start CTA */}
      <motion.div variants={item}>
        <QuickStartCard jlptLevel={jlptLevel || "N5"} />
      </motion.div>

      {/* Weekly Chart */}
      <motion.div variants={item}>
        <WeeklyChart weeklyStats={dashboard.weeklyStats} />
      </motion.div>

      {/* Level Progress */}
      <motion.div variants={item}>
        <LevelProgress currentLevel={jlptLevel || "N5"} />
      </motion.div>
    </motion.div>
  )
}
