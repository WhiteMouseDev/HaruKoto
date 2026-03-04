'use client';

import { useState, useCallback } from 'react';
import { useTheme } from 'next-themes';
import { motion } from 'framer-motion';
import {
  ChevronRight,
  BookOpen,
  Target,
  Moon,
  Sun,
  Bell,
  Clock,
  Gauge,
  Subtitles,
  FileText,
} from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Switch } from '@/components/ui/switch';
import { Separator } from '@/components/ui/separator';
import { Slider } from '@/components/ui/slider';
import { usePushNotifications } from '@/hooks/use-push-notifications';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from '@/components/ui/sheet';
import type { CallSettingsData } from './call-settings';

type JlptLevel = 'N5' | 'N4' | 'N3' | 'N2' | 'N1';

type SettingsMenuProps = {
  jlptLevel: string;
  dailyGoal: number;
  onUpdate: (field: string, value: unknown) => Promise<void>;
  callSettings: CallSettingsData;
  onCallSettingsUpdate: (settings: Partial<CallSettingsData>) => Promise<void>;
};

const JLPT_LEVELS: JlptLevel[] = ['N5', 'N4', 'N3', 'N2', 'N1'];
const DAILY_GOALS = [5, 10, 15, 20];

const DEFAULT_SILENCE_BY_LEVEL: Record<string, number> = {
  N5: 3000,
  N4: 2500,
  N3: 2000,
  N2: 1500,
  N1: 1200,
};

export function SettingsMenu({
  jlptLevel,
  dailyGoal,
  onUpdate,
  callSettings,
  onCallSettingsUpdate,
}: SettingsMenuProps) {
  const { theme, setTheme } = useTheme();
  const { state: pushState, isLoading: pushLoading, subscribe, unsubscribe } = usePushNotifications();
  const [levelSheetOpen, setLevelSheetOpen] = useState(false);
  const [goalSheetOpen, setGoalSheetOpen] = useState(false);
  const [updating, setUpdating] = useState(false);
  const [callUpdating, setCallUpdating] = useState(false);

  const handleLevelChange = async (level: JlptLevel) => {
    setUpdating(true);
    try {
      await onUpdate('jlptLevel', level);
      setLevelSheetOpen(false);
    } finally {
      setUpdating(false);
    }
  };

  const handleGoalChange = async (goal: number) => {
    setUpdating(true);
    try {
      await onUpdate('dailyGoal', goal);
      setGoalSheetOpen(false);
    } finally {
      setUpdating(false);
    }
  };

  const handleCallUpdate = useCallback(
    async (partial: Partial<CallSettingsData>) => {
      setCallUpdating(true);
      try {
        await onCallSettingsUpdate(partial);
      } finally {
        setCallUpdating(false);
      }
    },
    [onCallSettingsUpdate]
  );

  const silenceSeconds = (callSettings.silenceDurationMs / 1000).toFixed(1);
  const speedLabel =
    callSettings.aiResponseSpeed <= 0.85
      ? '느리게'
      : callSettings.aiResponseSpeed >= 1.15
        ? '빠르게'
        : '보통';

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
              className="hover:bg-accent flex items-center justify-between px-4 py-3.5 text-left transition-colors"
              onClick={() => setLevelSheetOpen(true)}
              disabled={updating}
            >
              <div className="flex items-center gap-3">
                <BookOpen className="text-primary size-5" />
                <span className="text-sm font-medium">JLPT 레벨</span>
              </div>
              <div className="flex items-center gap-1">
                <span className="text-muted-foreground text-sm">
                  {jlptLevel}
                </span>
                <ChevronRight className="text-muted-foreground size-4" />
              </div>
            </button>

            <Separator />

            {/* Daily Goal */}
            <button
              className="hover:bg-accent flex items-center justify-between px-4 py-3.5 text-left transition-colors"
              onClick={() => setGoalSheetOpen(true)}
              disabled={updating}
            >
              <div className="flex items-center gap-3">
                <Target className="text-hk-blue size-5" />
                <span className="text-sm font-medium">일일 목표</span>
              </div>
              <div className="flex items-center gap-1">
                <span className="text-muted-foreground text-sm">
                  {dailyGoal}문제
                </span>
                <ChevronRight className="text-muted-foreground size-4" />
              </div>
            </button>

            <Separator />

            {/* Theme Toggle */}
            <button
              className="hover:bg-accent flex items-center justify-between px-4 py-3.5 text-left transition-colors"
              onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
            >
              <div className="flex items-center gap-3">
                {theme === 'dark' ? (
                  <Moon className="text-hk-yellow size-5" />
                ) : (
                  <Sun className="text-hk-yellow size-5" />
                )}
                <span className="text-sm font-medium">테마</span>
              </div>
              <div className="flex items-center gap-1">
                <span className="text-muted-foreground text-sm">
                  {theme === 'dark' ? '다크' : '라이트'}
                </span>
                <ChevronRight className="text-muted-foreground size-4" />
              </div>
            </button>

            <Separator />

            {/* Notifications */}
            <div className="flex items-center justify-between px-4 py-3.5">
              <div className="flex items-center gap-3">
                <Bell className="text-hk-red size-5" />
                <div className="flex flex-col">
                  <span className="text-sm font-medium">알림 설정</span>
                  {pushState === 'denied' && (
                    <span className="text-muted-foreground text-[11px]">
                      브라우저 설정에서 허용해주세요
                    </span>
                  )}
                  {pushState === 'unsupported' && (
                    <span className="text-muted-foreground text-[11px]">
                      이 브라우저에서 지원하지 않습니다
                    </span>
                  )}
                </div>
              </div>
              <Switch
                checked={pushState === 'granted'}
                onCheckedChange={async (checked) => {
                  if (checked) {
                    await subscribe();
                  } else {
                    await unsubscribe();
                  }
                }}
                disabled={pushState === 'unsupported' || pushState === 'denied' || pushLoading}
              />
            </div>

            {/* Call Settings Section Divider */}
            <div className="bg-secondary/50 px-4 py-2">
              <span className="text-muted-foreground text-xs font-medium">
                통화 설정
              </span>
            </div>

            {/* Silence Duration */}
            <div className="flex flex-col gap-3 px-4 py-3.5">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <Clock className="size-5 text-violet-500" />
                  <span className="text-sm font-medium">침묵 대기 시간</span>
                </div>
                <span className="text-sm font-medium tabular-nums">
                  {silenceSeconds}초
                </span>
              </div>
              <Slider
                value={[callSettings.silenceDurationMs]}
                onValueChange={([v]) => handleCallUpdate({ silenceDurationMs: v })}
                min={1000}
                max={5000}
                step={100}
                disabled={callUpdating}
                className="w-full"
              />
              <div className="text-muted-foreground flex justify-between text-[10px]">
                <span>짧게 (1초)</span>
                <span>
                  기본 ({(DEFAULT_SILENCE_BY_LEVEL[jlptLevel] / 1000).toFixed(1)}
                  초)
                </span>
                <span>길게 (5초)</span>
              </div>
            </div>

            <Separator />

            {/* AI Response Speed */}
            <div className="flex flex-col gap-3 px-4 py-3.5">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <Gauge className="size-5 text-blue-500" />
                  <span className="text-sm font-medium">AI 응답 속도</span>
                </div>
                <span className="text-sm font-medium">{speedLabel}</span>
              </div>
              <Slider
                value={[callSettings.aiResponseSpeed]}
                onValueChange={([v]) =>
                  handleCallUpdate({ aiResponseSpeed: Math.round(v * 100) / 100 })
                }
                min={0.8}
                max={1.2}
                step={0.05}
                disabled={callUpdating}
                className="w-full"
              />
              <div className="text-muted-foreground flex justify-between text-[10px]">
                <span>느리게</span>
                <span>보통</span>
                <span>빠르게</span>
              </div>
            </div>

            <Separator />

            {/* Subtitle Toggle */}
            <div className="flex items-center justify-between px-4 py-3.5">
              <div className="flex items-center gap-3">
                <Subtitles className="size-5 text-emerald-500" />
                <span className="text-sm font-medium">자막 표시</span>
              </div>
              <Switch
                checked={callSettings.subtitleEnabled}
                onCheckedChange={(v) => handleCallUpdate({ subtitleEnabled: v })}
                disabled={callUpdating}
              />
            </div>

            <Separator />

            {/* Auto Analysis Toggle */}
            <div className="flex items-center justify-between px-4 py-3.5">
              <div className="flex items-center gap-3">
                <FileText className="size-5 text-amber-500" />
                <span className="text-sm font-medium">통화 후 자동 분석</span>
              </div>
              <Switch
                checked={callSettings.autoAnalysis}
                onCheckedChange={(v) => handleCallUpdate({ autoAnalysis: v })}
                disabled={callUpdating}
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
                    ? 'border-primary bg-primary/10 text-primary'
                    : 'border-border hover:bg-accent'
                }`}
                disabled={updating}
                onClick={() => handleLevelChange(level)}
              >
                {level}
                {level === jlptLevel && ' (현재)'}
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
            <SheetDescription>하루에 풀 문제 수를 선택하세요.</SheetDescription>
          </SheetHeader>
          <div className="flex flex-col gap-2 px-4 pb-6">
            {DAILY_GOALS.map((goal) => (
              <button
                key={goal}
                className={`rounded-xl border px-4 py-3 text-left text-sm font-medium transition-colors ${
                  goal === dailyGoal
                    ? 'border-primary bg-primary/10 text-primary'
                    : 'border-border hover:bg-accent'
                }`}
                disabled={updating}
                onClick={() => handleGoalChange(goal)}
              >
                {goal}문제
                {goal === dailyGoal && ' (현재)'}
              </button>
            ))}
          </div>
        </SheetContent>
      </Sheet>
    </>
  );
}
