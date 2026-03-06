'use client';

import { useState, useCallback, useRef, useEffect } from 'react';
import { useTheme } from 'next-themes';
import { motion } from 'framer-motion';
import {
  ChevronRight,
  Sun,
  Moon,
  Monitor,
  Bell,
  Phone,
  Clock,
  RotateCcw,
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
import { SectionLabel } from './section-label';

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

type AppSettingsSectionProps = {
  jlptLevel: string;
  callSettings: CallSettingsData;
  onCallSettingsUpdate: (settings: Partial<CallSettingsData>) => void;
};

export function AppSettingsSection({
  jlptLevel,
  callSettings,
  onCallSettingsUpdate,
}: AppSettingsSectionProps) {
  const { theme, setTheme } = useTheme();
  const {
    state: pushState,
    isLoading: pushLoading,
    subscribe,
    unsubscribe,
  } = usePushNotifications();
  const [themeSheetOpen, setThemeSheetOpen] = useState(false);
  const [callSheetOpen, setCallSheetOpen] = useState(false);
  const [localSilence, setLocalSilence] = useState(
    callSettings.silenceDurationMs
  );
  const [prevSilence, setPrevSilence] = useState(callSettings.silenceDurationMs);
  const silenceTimerRef = useRef<ReturnType<typeof setTimeout>>(undefined);

  if (prevSilence !== callSettings.silenceDurationMs) {
    setPrevSilence(callSettings.silenceDurationMs);
    setLocalSilence(callSettings.silenceDurationMs);
  }

  useEffect(() => {
    return () => {
      clearTimeout(silenceTimerRef.current);
    };
  }, []);

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

  const silenceSeconds = (localSilence / 1000).toFixed(1);

  const themeLabel =
    theme === 'dark' ? '다크' : theme === 'system' ? '시스템' : '라이트';

  return (
    <>
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
                  <Clock className={`size-5 ${localSilence < 700 ? 'text-amber-500' : 'text-violet-500'}`} />
                  <span className="text-sm font-medium">침묵 대기 시간</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className={`text-sm font-medium tabular-nums ${localSilence < 700 ? 'text-amber-500' : ''}`}>
                    {silenceSeconds}초
                  </span>
                  {localSilence !== (DEFAULT_SILENCE_BY_LEVEL[jlptLevel] ?? 2000) && (
                    <button
                      className="text-muted-foreground hover:text-foreground transition-colors"
                      onClick={() => handleSilenceChange(DEFAULT_SILENCE_BY_LEVEL[jlptLevel] ?? 2000)}
                      aria-label="기본값으로 초기화"
                    >
                      <RotateCcw className="size-3.5" />
                    </button>
                  )}
                </div>
              </div>
              <Slider
                value={[localSilence]}
                onValueChange={([v]) => handleSilenceChange(v)}
                min={0}
                max={5000}
                step={100}
                className="w-full"
              />
              <div className="text-muted-foreground flex justify-between text-[10px]">
                <span>즉시 (0초)</span>
                <span>
                  기본 (
                  {(DEFAULT_SILENCE_BY_LEVEL[jlptLevel] / 1000).toFixed(1)}초)
                </span>
                <span>길게 (5초)</span>
              </div>
              {localSilence < 700 && (
                <p className="text-amber-500 text-[11px]">
                  ⚠ 0.7초 미만은 말 중간에 끊길 수 있습니다
                </p>
              )}
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
