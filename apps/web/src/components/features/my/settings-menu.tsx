"use client"

import { useState } from "react"
import { useTheme } from "next-themes"
import { motion } from "framer-motion"
import {
  ChevronRight,
  BookOpen,
  Target,
  Moon,
  Sun,
  Bell,
} from "lucide-react"
import { Card, CardContent } from "@/components/ui/card"
import { Switch } from "@/components/ui/switch"
import { Separator } from "@/components/ui/separator"
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet"

type JlptLevel = "N5" | "N4" | "N3" | "N2" | "N1"

type SettingsMenuProps = {
  jlptLevel: string
  dailyGoal: number
  onUpdate: (field: string, value: unknown) => Promise<void>
}

const JLPT_LEVELS: JlptLevel[] = ["N5", "N4", "N3", "N2", "N1"]
const DAILY_GOALS = [5, 10, 15, 20]

export function SettingsMenu({
  jlptLevel,
  dailyGoal,
  onUpdate,
}: SettingsMenuProps) {
  const { theme, setTheme } = useTheme()
  const [notifications, setNotifications] = useState(true)
  const [levelSheetOpen, setLevelSheetOpen] = useState(false)
  const [goalSheetOpen, setGoalSheetOpen] = useState(false)
  const [updating, setUpdating] = useState(false)

  const handleLevelChange = async (level: JlptLevel) => {
    setUpdating(true)
    try {
      await onUpdate("jlptLevel", level)
      setLevelSheetOpen(false)
    } finally {
      setUpdating(false)
    }
  }

  const handleGoalChange = async (goal: number) => {
    setUpdating(true)
    try {
      await onUpdate("dailyGoal", goal)
      setGoalSheetOpen(false)
    } finally {
      setUpdating(false)
    }
  }

  return (
    <>
      <motion.div
        initial={{ y: 10, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.15 }}
      >
        <Card>
          <CardContent className="flex flex-col p-0">
            {/* JLPT Level */}
            <button
              className="flex items-center justify-between px-4 py-3.5 text-left transition-colors hover:bg-accent"
              onClick={() => setLevelSheetOpen(true)}
              disabled={updating}
            >
              <div className="flex items-center gap-3">
                <BookOpen className="size-5 text-primary" />
                <span className="text-sm font-medium">JLPT 레벨</span>
              </div>
              <div className="flex items-center gap-1">
                <span className="text-sm text-muted-foreground">
                  {jlptLevel}
                </span>
                <ChevronRight className="size-4 text-muted-foreground" />
              </div>
            </button>

            <Separator />

            {/* Daily Goal */}
            <button
              className="flex items-center justify-between px-4 py-3.5 text-left transition-colors hover:bg-accent"
              onClick={() => setGoalSheetOpen(true)}
              disabled={updating}
            >
              <div className="flex items-center gap-3">
                <Target className="size-5 text-hk-blue" />
                <span className="text-sm font-medium">일일 목표</span>
              </div>
              <div className="flex items-center gap-1">
                <span className="text-sm text-muted-foreground">
                  {dailyGoal}문제
                </span>
                <ChevronRight className="size-4 text-muted-foreground" />
              </div>
            </button>

            <Separator />

            {/* Theme Toggle */}
            <button
              className="flex items-center justify-between px-4 py-3.5 text-left transition-colors hover:bg-accent"
              onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
            >
              <div className="flex items-center gap-3">
                {theme === "dark" ? (
                  <Moon className="size-5 text-hk-yellow" />
                ) : (
                  <Sun className="size-5 text-hk-yellow" />
                )}
                <span className="text-sm font-medium">테마</span>
              </div>
              <div className="flex items-center gap-1">
                <span className="text-sm text-muted-foreground">
                  {theme === "dark" ? "다크" : "라이트"}
                </span>
                <ChevronRight className="size-4 text-muted-foreground" />
              </div>
            </button>

            <Separator />

            {/* Notifications */}
            <div className="flex items-center justify-between px-4 py-3.5">
              <div className="flex items-center gap-3">
                <Bell className="size-5 text-hk-red" />
                <span className="text-sm font-medium">알림 설정</span>
              </div>
              <Switch
                checked={notifications}
                onCheckedChange={setNotifications}
              />
            </div>
          </CardContent>
        </Card>
      </motion.div>

      {/* JLPT Level Sheet */}
      <Sheet open={levelSheetOpen} onOpenChange={setLevelSheetOpen}>
        <SheetContent side="bottom" className="rounded-t-2xl">
          <SheetHeader>
            <SheetTitle>JLPT 레벨 변경</SheetTitle>
            <SheetDescription>학습할 JLPT 레벨을 선택하세요.</SheetDescription>
          </SheetHeader>
          <div className="flex flex-col gap-2 px-4 pb-6">
            {JLPT_LEVELS.map((level) => (
              <button
                key={level}
                className={`rounded-xl border px-4 py-3 text-left text-sm font-medium transition-colors ${
                  level === jlptLevel
                    ? "border-primary bg-primary/10 text-primary"
                    : "border-border hover:bg-accent"
                }`}
                disabled={updating}
                onClick={() => handleLevelChange(level)}
              >
                {level}
                {level === jlptLevel && " (현재)"}
              </button>
            ))}
          </div>
        </SheetContent>
      </Sheet>

      {/* Daily Goal Sheet */}
      <Sheet open={goalSheetOpen} onOpenChange={setGoalSheetOpen}>
        <SheetContent side="bottom" className="rounded-t-2xl">
          <SheetHeader>
            <SheetTitle>일일 목표 변경</SheetTitle>
            <SheetDescription>
              하루에 풀 문제 수를 선택하세요.
            </SheetDescription>
          </SheetHeader>
          <div className="flex flex-col gap-2 px-4 pb-6">
            {DAILY_GOALS.map((goal) => (
              <button
                key={goal}
                className={`rounded-xl border px-4 py-3 text-left text-sm font-medium transition-colors ${
                  goal === dailyGoal
                    ? "border-primary bg-primary/10 text-primary"
                    : "border-border hover:bg-accent"
                }`}
                disabled={updating}
                onClick={() => handleGoalChange(goal)}
              >
                {goal}문제
                {goal === dailyGoal && " (현재)"}
              </button>
            ))}
          </div>
        </SheetContent>
      </Sheet>
    </>
  )
}
