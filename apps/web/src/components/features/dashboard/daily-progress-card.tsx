"use client"

import { Target, BookOpen, Trophy } from "lucide-react"
import { Card, CardContent } from "@/components/ui/card"
import { Progress } from "@/components/ui/progress"

type DailyProgressCardProps = {
  dailyGoal: number
  wordsStudied: number
  correctAnswers: number
  totalAnswers: number
  goalProgress: number
}

export function DailyProgressCard({
  dailyGoal,
  wordsStudied,
  correctAnswers,
  totalAnswers,
  goalProgress,
}: DailyProgressCardProps) {
  const accuracyPercent =
    totalAnswers > 0 ? Math.round((correctAnswers / totalAnswers) * 100) : 0
  const progressPercent = Math.round(goalProgress * 100)

  return (
    <Card>
      <CardContent className="flex flex-col gap-4 p-4">
        <h2 className="font-semibold">오늘의 학습</h2>

        {/* Goal progress bar */}
        <div className="flex flex-col gap-2">
          <div className="flex items-center justify-between text-sm">
            <span className="text-muted-foreground">하루 목표</span>
            <span className="font-medium">
              {wordsStudied}/{dailyGoal}
            </span>
          </div>
          <Progress value={progressPercent} />
          <span className="text-xs text-muted-foreground text-right">
            {progressPercent}%
          </span>
        </div>

        {/* Stats grid */}
        <div className="grid grid-cols-3 gap-3">
          <div className="flex flex-col items-center gap-1 rounded-xl bg-secondary p-3">
            <Target className="size-5 text-primary" />
            <span className="text-xs text-muted-foreground">목표</span>
            <span className="text-lg font-bold">
              {wordsStudied}/{dailyGoal}
            </span>
          </div>
          <div className="flex flex-col items-center gap-1 rounded-xl bg-secondary p-3">
            <BookOpen className="size-5 text-hk-blue" />
            <span className="text-xs text-muted-foreground">단어</span>
            <span className="text-lg font-bold">{wordsStudied}개</span>
          </div>
          <div className="flex flex-col items-center gap-1 rounded-xl bg-secondary p-3">
            <Trophy className="size-5 text-hk-yellow" />
            <span className="text-xs text-muted-foreground">정답률</span>
            <span className="text-lg font-bold">
              {totalAnswers > 0 ? `${accuracyPercent}%` : "--%"}
            </span>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}
