"use client"

import { motion } from "framer-motion"
import { Calendar, BookOpen, Zap, Flame } from "lucide-react"
import { Card, CardContent } from "@/components/ui/card"

type StatsOverviewProps = {
  totalStudyDays: number
  totalWordsStudied: number
  experiencePoints: number
  level: number
  longestStreak: number
}

const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.05 },
  },
}

const item = {
  hidden: { y: 10, opacity: 0 },
  show: { y: 0, opacity: 1 },
}

export function StatsOverview({
  totalStudyDays,
  totalWordsStudied,
  experiencePoints,
  level,
  longestStreak,
}: StatsOverviewProps) {
  const stats = [
    {
      icon: Calendar,
      label: "총 학습일",
      value: `${totalStudyDays}일`,
      color: "text-hk-blue",
    },
    {
      icon: BookOpen,
      label: "학습 단어",
      value: `${totalWordsStudied}개`,
      color: "text-primary",
    },
    {
      icon: Zap,
      label: "총 XP",
      value: `${experiencePoints}`,
      sub: `Lv.${level}`,
      color: "text-hk-yellow",
    },
    {
      icon: Flame,
      label: "최장 연속",
      value: `${longestStreak}일`,
      color: "text-hk-red",
    },
  ]

  return (
    <Card>
      <CardContent className="p-4">
        <motion.div
          className="grid grid-cols-2 gap-3"
          variants={container}
          initial="hidden"
          animate="show"
        >
          {stats.map((stat) => (
            <motion.div
              key={stat.label}
              variants={item}
              className="flex flex-col items-center gap-1 rounded-xl bg-secondary p-3"
            >
              <stat.icon className={`size-5 ${stat.color}`} />
              <span className="text-xs text-muted-foreground">
                {stat.label}
              </span>
              <span className="text-lg font-bold">{stat.value}</span>
              {stat.sub && (
                <span className="text-[10px] text-muted-foreground">
                  {stat.sub}
                </span>
              )}
            </motion.div>
          ))}
        </motion.div>
      </CardContent>
    </Card>
  )
}
