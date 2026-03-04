'use client';

import { useState, useCallback, useRef, useEffect } from 'react';
import { useTheme } from 'next-themes';
import { motion } from 'framer-motion';
import {
  ChevronRight,
  BookOpen,
  Target,
  Sun,
  Moon,
  Monitor,
  Bell,
  Phone,
  Clock,
  Gauge,
  Subtitles,
  FileText,
  ScrollText,
  Shield,
  Mail,
  LogOut,
  UserX,
} from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Switch } from '@/components/ui/switch';
import { Separator } from '@/components/ui/separator';
import { Slider } from '@/components/ui/slider';
import { Button } from '@/components/ui/button';
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
  onCallSettingsUpdate: (settings: Partial<CallSettingsData>) => void;
  onLogout: () => void;
  loggingOut: boolean;
  onDeleteAccount: () => void;
  deleting: boolean;
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

const THEME_OPTIONS = [
  { value: 'light', label: '라이트', icon: Sun },
  { value: 'dark', label: '다크', icon: Moon },
  { value: 'system', label: '시스템', icon: Monitor },
] as const;

function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <span className="text-muted-foreground px-1 text-xs font-medium">
      {children}
    </span>
  );
}

export function SettingsMenu({
  jlptLevel,
  dailyGoal,
  onUpdate,
  callSettings,
  onCallSettingsUpdate,
  onLogout,
  loggingOut,
  onDeleteAccount,
  deleting,
}: SettingsMenuProps) {
  const { theme, setTheme } = useTheme();
  const {
    state: pushState,
    isLoading: pushLoading,
    subscribe,
    unsubscribe,
  } = usePushNotifications();
  const [levelSheetOpen, setLevelSheetOpen] = useState(false);
  const [goalSheetOpen, setGoalSheetOpen] = useState(false);
  const [themeSheetOpen, setThemeSheetOpen] = useState(false);
  const [callSheetOpen, setCallSheetOpen] = useState(false);
  const [updating, setUpdating] = useState(false);

  // Local slider state for instant UI feedback
  const [localSilence, setLocalSilence] = useState(
    callSettings.silenceDurationMs
  );
  const [localSpeed, setLocalSpeed] = useState(callSettings.aiResponseSpeed);
  const silenceTimerRef = useRef<ReturnType<typeof setTimeout>>(undefined);
  const speedTimerRef = useRef<ReturnType<typeof setTimeout>>(undefined);

  useEffect(() => {
    setLocalSilence(callSettings.silenceDurationMs);
  }, [callSettings.silenceDurationMs]);

  useEffect(() => {
    setLocalSpeed(callSettings.aiResponseSpeed);
  }, [callSettings.aiResponseSpeed]);

  useEffect(() => {
    return () => {
      clearTimeout(silenceTimerRef.current);
      clearTimeout(speedTimerRef.current);
    };
  }, []);

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

  const handleCallToggle = useCallback(
    (partial: Partial<CallSettingsData>) => {
      onCallSettingsUpdate(partial);
    },
    [onCallSettingsUpdate]
  );

  const handleSilenceChange = useCallback(
    (value: number) => {
      setLocalSilence(value);
      clearTimeout(silenceTimerRef.current);
      silenceTimerRef.current = setTimeout(() => {
        onCallSettingsUpdate({ silenceDurationMs: value });
      }, 400);
    },
    [onCallSettingsUpdate]
  );

  const handleSpeedChange = useCallback(
    (value: number) => {
      setLocalSpeed(Math.round(value * 100) / 100);
      clearTimeout(speedTimerRef.current);
      speedTimerRef.current = setTimeout(() => {
        onCallSettingsUpdate({
          aiResponseSpeed: Math.round(value * 100) / 100,
        });
      }, 400);
    },
    [onCallSettingsUpdate]
  );

  const silenceSeconds = (localSilence / 1000).toFixed(1);
  const speedLabel =
    localSpeed <= 0.85
      ? '느리게'
      : localSpeed >= 1.15
        ? '빠르게'
        : '보통';

  const themeLabel =
    theme === 'dark' ? '다크' : theme === 'system' ? '시스템' : '라이트';

  return (
    <>
      <div className="flex flex-col gap-3">
        {/* ── 학습 설정 ── */}
        <motion.div
          initial={{ y: 10, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.1 }}
          className="flex flex-col gap-1.5"
        >
          <SectionLabel>학습 설정</SectionLabel>
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
            </CardContent>
          </Card>
        </motion.div>

        {/* ── 앱 설정 ── */}
        <motion.div
          initial={{ y: 10, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.15 }}
          className="flex flex-col gap-1.5"
        >
          <SectionLabel>앱 설정</SectionLabel>
          <Card>
            <CardContent className="flex flex-col p-0">
              {/* Theme */}
              <button
                className="hover:bg-accent flex items-center justify-between px-4 py-3.5 text-left transition-colors"
                onClick={() => setThemeSheetOpen(true)}
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
                    {themeLabel}
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
                  disabled={
                    pushState === 'unsupported' ||
                    pushState === 'denied' ||
                    pushLoading
                  }
                />
              </div>

              <Separator />

              {/* Call Settings */}
              <button
                className="hover:bg-accent flex items-center justify-between px-4 py-3.5 text-left transition-colors"
                onClick={() => setCallSheetOpen(true)}
              >
                <div className="flex items-center gap-3">
                  <Phone className="size-5 text-violet-500" />
                  <span className="text-sm font-medium">통화 설정</span>
                </div>
                <ChevronRight className="text-muted-foreground size-4" />
              </button>
            </CardContent>
          </Card>
        </motion.div>

        {/* ── 정보 ── */}
        <motion.div
          initial={{ y: 10, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.2 }}
          className="flex flex-col gap-1.5"
        >
          <SectionLabel>정보</SectionLabel>
          <Card>
            <CardContent className="flex flex-col p-0">
              {/* Terms */}
              <a
                href="https://www.harukoto.co.kr/terms"
                target="_blank"
                rel="noopener noreferrer"
                className="hover:bg-accent flex items-center justify-between px-4 py-3.5 transition-colors"
              >
                <div className="flex items-center gap-3">
                  <ScrollText className="text-muted-foreground size-5" />
                  <span className="text-sm font-medium">이용약관</span>
                </div>
                <ChevronRight className="text-muted-foreground size-4" />
              </a>

              <Separator />

              {/* Privacy */}
              <a
                href="https://www.harukoto.co.kr/privacy"
                target="_blank"
                rel="noopener noreferrer"
                className="hover:bg-accent flex items-center justify-between px-4 py-3.5 transition-colors"
              >
                <div className="flex items-center gap-3">
                  <Shield className="text-muted-foreground size-5" />
                  <span className="text-sm font-medium">개인정보처리방침</span>
                </div>
                <ChevronRight className="text-muted-foreground size-4" />
              </a>

              <Separator />

              {/* Contact */}
              <a
                href="mailto:whitemousedev@whitemouse.dev"
                className="hover:bg-accent flex items-center justify-between px-4 py-3.5 transition-colors"
              >
                <div className="flex items-center gap-3">
                  <Mail className="text-muted-foreground size-5" />
                  <span className="text-sm font-medium">문의하기</span>
                </div>
                <ChevronRight className="text-muted-foreground size-4" />
              </a>
            </CardContent>
          </Card>
        </motion.div>

        {/* ── 계정 ── */}
        <motion.div
          initial={{ y: 10, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.25 }}
          className="flex flex-col gap-1.5"
        >
          <SectionLabel>계정</SectionLabel>
          <Card>
            <CardContent className="flex flex-col p-0">
              {/* Logout */}
              <button
                className="hover:bg-accent flex items-center gap-3 px-4 py-3.5 text-left transition-colors"
                onClick={onLogout}
                disabled={loggingOut}
              >
                <LogOut className="text-muted-foreground size-5" />
                <span className="text-sm font-medium">
                  {loggingOut ? '로그아웃 중...' : '로그아웃'}
                </span>
              </button>

              <Separator />

              {/* Delete Account */}
              <button
                className="hover:bg-accent flex items-center gap-3 px-4 py-3.5 text-left transition-colors"
                onClick={onDeleteAccount}
                disabled={deleting}
              >
                <UserX className="text-destructive size-5" />
                <span className="text-destructive text-sm font-medium">
                  {deleting ? '탈퇴 처리 중...' : '회원 탈퇴'}
                </span>
              </button>
            </CardContent>
          </Card>
        </motion.div>

        {/* Version */}
        <div className="flex justify-center pb-2">
          <span className="text-muted-foreground text-xs">v0.1.0</span>
        </div>
      </div>

      {/* ── Bottom Sheets ── */}

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

      {/* Theme Sheet */}
      <Sheet open={themeSheetOpen} onOpenChange={setThemeSheetOpen}>
        <SheetContent side="bottom" className="rounded-t-2xl">
          <SheetHeader>
            <SheetTitle>테마 변경</SheetTitle>
            <SheetDescription>앱 테마를 선택하세요.</SheetDescription>
          </SheetHeader>
          <div className="flex flex-col gap-2 px-4 pb-6">
            {THEME_OPTIONS.map(({ value, label, icon: Icon }) => (
              <button
                key={value}
                className={`flex items-center gap-3 rounded-xl border px-4 py-3 text-left text-sm font-medium transition-colors ${
                  theme === value
                    ? 'border-primary bg-primary/10 text-primary'
                    : 'border-border hover:bg-accent'
                }`}
                onClick={() => {
                  setTheme(value);
                  setThemeSheetOpen(false);
                }}
              >
                <Icon className="size-4" />
                {label}
                {theme === value && ' (현재)'}
              </button>
            ))}
          </div>
        </SheetContent>
      </Sheet>

      {/* Call Settings Sheet */}
      <Sheet open={callSheetOpen} onOpenChange={setCallSheetOpen}>
        <SheetContent side="bottom" className="rounded-t-2xl">
          <SheetHeader>
            <SheetTitle>통화 설정</SheetTitle>
            <SheetDescription>
              AI 통화 환경을 조정하세요.
            </SheetDescription>
          </SheetHeader>
          <div className="flex flex-col gap-1 px-4 pb-6">
            {/* Silence Duration */}
            <div className="flex flex-col gap-3 py-3">
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
                value={[localSilence]}
                onValueChange={([v]) => handleSilenceChange(v)}
                min={700}
                max={5000}
                step={100}
                className="w-full"
              />
              <div className="text-muted-foreground flex justify-between text-[10px]">
                <span>짧게 (0.7초)</span>
                <span>
                  기본 (
                  {(DEFAULT_SILENCE_BY_LEVEL[jlptLevel] / 1000).toFixed(1)}초)
                </span>
                <span>길게 (5초)</span>
              </div>
            </div>

            <Separator />

            {/* AI Response Speed */}
            <div className="flex flex-col gap-3 py-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <Gauge className="size-5 text-blue-500" />
                  <span className="text-sm font-medium">AI 응답 속도</span>
                </div>
                <span className="text-sm font-medium">{speedLabel}</span>
              </div>
              <Slider
                value={[localSpeed]}
                onValueChange={([v]) => handleSpeedChange(v)}
                min={0.8}
                max={1.2}
                step={0.05}
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
            <div className="flex items-center justify-between py-3">
              <div className="flex items-center gap-3">
                <Subtitles className="size-5 text-emerald-500" />
                <span className="text-sm font-medium">자막 표시</span>
              </div>
              <Switch
                checked={callSettings.subtitleEnabled}
                onCheckedChange={(v) =>
                  handleCallToggle({ subtitleEnabled: v })
                }
              />
            </div>

            <Separator />

            {/* Auto Analysis Toggle */}
            <div className="flex items-center justify-between py-3">
              <div className="flex items-center gap-3">
                <FileText className="size-5 text-amber-500" />
                <span className="text-sm font-medium">통화 후 자동 분석</span>
              </div>
              <Switch
                checked={callSettings.autoAnalysis}
                onCheckedChange={(v) => handleCallToggle({ autoAnalysis: v })}
              />
            </div>
          </div>
        </SheetContent>
      </Sheet>
    </>
  );
}
