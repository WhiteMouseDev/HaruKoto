"use client"

import { motion } from "framer-motion"
import { Card, CardContent } from "@/components/ui/card"

type WeeklyChartProps = {
  weeklyStats: { date: string; wordsStudied: number; xpEarned: number }[]
}

const DAY_LABELS = ["월", "화", "수", "목", "금", "토", "일"]

export function WeeklyChart({ weeklyStats }: WeeklyChartProps) {
  const maxWords = Math.max(...weeklyStats.map((d) => d.wordsStudied), 1)
  const totalWords = weeklyStats.reduce((sum, d) => sum + d.wordsStudied, 0)
  const totalXp = weeklyStats.reduce((sum, d) => sum + d.xpEarned, 0)

  const bars = weeklyStats.map((day) => {
    const date = new Date(day.date + "T00:00:00Z")
    const dayIndex = (date.getUTCDay() + 6) % 7
    return {
      label: DAY_LABELS[dayIndex],
      value: day.wordsStudied,
      height: (day.wordsStudied / maxWords) * 100,
    }
  })

  return (
    <Card>
      <CardContent className="flex flex-col gap-4 p-4">
        <div className="flex items-center justify-between">
          <h2 className="font-semibold">주간 학습</h2>
        </div>

        {/* Bar chart */}
        <div className="flex items-end justify-between gap-2" style={{ height: 80 }}>
          {bars.map((bar, i) => (
            <div key={i} className="flex flex-1 flex-col items-center gap-1">
              <motion.div
                className="w-full rounded-t-md bg-primary"
                initial={{ height: 0 }}
                animate={{ height: `${Math.max(bar.height, 4)}%` }}
                transition={{ delay: i * 0.05, duration: 0.4, ease: "easeOut" }}
                style={{ minHeight: bar.value > 0 ? 4 : 2 }}
              />
            </div>
          ))}
        </div>

        {/* Day labels */}
        <div className="flex justify-between gap-2">
          {bars.map((bar, i) => (
            <span
              key={i}
              className="flex-1 text-center text-[10px] text-muted-foreground"
            >
              {bar.label}
            </span>
          ))}
        </div>

        {/* Summary */}
        <div className="flex justify-center gap-6 text-sm text-muted-foreground">
          <span>
            단어 <span className="font-semibold text-foreground">{totalWords}개</span>
          </span>
          <span>
            XP <span className="font-semibold text-foreground">{totalXp}</span>
          </span>
        </div>
      </CardContent>
    </Card>
  )
}
