'use client';

import { useState, useCallback } from 'react';
import { motion } from 'framer-motion';
import { Phone, Clock, Gauge, Subtitles, FileText } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Switch } from '@/components/ui/switch';
import { Separator } from '@/components/ui/separator';
import { Slider } from '@/components/ui/slider';

export type CallSettingsData = {
  silenceDurationMs: number;
  aiResponseSpeed: number;
  subtitleEnabled: boolean;
  autoAnalysis: boolean;
};

const DEFAULT_SILENCE_BY_LEVEL: Record<string, number> = {
  N5: 3000,
  N4: 2500,
  N3: 2000,
  N2: 1500,
  N1: 1200,
};

type CallSettingsProps = {
  settings: CallSettingsData;
  jlptLevel: string;
  onUpdate: (settings: Partial<CallSettingsData>) => Promise<void>;
};

export function getDefaultCallSettings(jlptLevel: string): CallSettingsData {
  return {
    silenceDurationMs: DEFAULT_SILENCE_BY_LEVEL[jlptLevel] ?? 2000,
    aiResponseSpeed: 1.0,
    subtitleEnabled: true,
    autoAnalysis: true,
  };
}

export function CallSettings({ settings, jlptLevel, onUpdate }: CallSettingsProps) {
  const [updating, setUpdating] = useState(false);

  const handleUpdate = useCallback(
    async (partial: Partial<CallSettingsData>) => {
      setUpdating(true);
      try {
        await onUpdate(partial);
      } finally {
        setUpdating(false);
      }
    },
    [onUpdate]
  );

  const silenceSeconds = (settings.silenceDurationMs / 1000).toFixed(1);

  const speedLabel =
    settings.aiResponseSpeed <= 0.85
      ? '느리게'
      : settings.aiResponseSpeed >= 1.15
        ? '빠르게'
        : '보통';

  return (
    <motion.div
      initial={{ y: 10, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ delay: 0.2 }}
    >
      <h3 className="mb-2 flex items-center gap-1.5 text-sm font-semibold text-muted-foreground">
        <Phone className="size-3.5" />
        통화 설정
      </h3>
      <Card>
        <CardContent className="flex flex-col p-0">
          {/* Silence Duration */}
          <div className="flex flex-col gap-3 px-4 py-3.5">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <Clock className="size-5 text-violet-500" />
                <div>
                  <span className="text-sm font-medium">침묵 대기 시간</span>
                  <p className="text-muted-foreground text-[11px]">
                    말을 멈춘 후 AI 응답까지 대기
                  </p>
                </div>
              </div>
              <span className="text-sm font-medium tabular-nums">
                {silenceSeconds}초
              </span>
            </div>
            <Slider
              value={[settings.silenceDurationMs]}
              onValueChange={([v]) => handleUpdate({ silenceDurationMs: v })}
              min={1000}
              max={5000}
              step={100}
              disabled={updating}
              className="w-full"
            />
            <div className="flex justify-between text-[10px] text-muted-foreground">
              <span>짧게 (1초)</span>
              <span>기본 ({(DEFAULT_SILENCE_BY_LEVEL[jlptLevel] / 1000).toFixed(1)}초)</span>
              <span>길게 (5초)</span>
            </div>
          </div>

          <Separator />

          {/* AI Response Speed */}
          <div className="flex flex-col gap-3 px-4 py-3.5">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <Gauge className="size-5 text-blue-500" />
                <div>
                  <span className="text-sm font-medium">AI 응답 속도</span>
                  <p className="text-muted-foreground text-[11px]">
                    AI가 말하는 속도
                  </p>
                </div>
              </div>
              <span className="text-sm font-medium">{speedLabel}</span>
            </div>
            <Slider
              value={[settings.aiResponseSpeed]}
              onValueChange={([v]) =>
                handleUpdate({ aiResponseSpeed: Math.round(v * 100) / 100 })
              }
              min={0.8}
              max={1.2}
              step={0.05}
              disabled={updating}
              className="w-full"
            />
            <div className="flex justify-between text-[10px] text-muted-foreground">
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
              <div>
                <span className="text-sm font-medium">자막 표시</span>
                <p className="text-muted-foreground text-[11px]">
                  통화 중 AI 음성을 텍스트로 표시
                </p>
              </div>
            </div>
            <Switch
              checked={settings.subtitleEnabled}
              onCheckedChange={(v) => handleUpdate({ subtitleEnabled: v })}
              disabled={updating}
            />
          </div>

          <Separator />

          {/* Auto Analysis Toggle */}
          <div className="flex items-center justify-between px-4 py-3.5">
            <div className="flex items-center gap-3">
              <FileText className="size-5 text-amber-500" />
              <div>
                <span className="text-sm font-medium">통화 후 자동 분석</span>
                <p className="text-muted-foreground text-[11px]">
                  종료 후 AI 피드백 자동 생성
                </p>
              </div>
            </div>
            <Switch
              checked={settings.autoAnalysis}
              onCheckedChange={(v) => handleUpdate({ autoAnalysis: v })}
              disabled={updating}
            />
          </div>
        </CardContent>
      </Card>
    </motion.div>
  );
}
