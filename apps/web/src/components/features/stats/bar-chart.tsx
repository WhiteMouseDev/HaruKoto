'use client';

import { useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import { Card, CardContent } from '@/components/ui/card';

type BarChartRecord = {
  date: string;
  studyTimeSeconds: number;
  wordsStudied: number;
};

type BarChartProps = {
  records: BarChartRecord[];
};

type ViewMode = 'week' | 'month' | 'year';

const VIEW_LABELS: Record<ViewMode, string> = {
  week: '주',
  month: '월',
  year: '년',
};

type BarData = {
  label: string;
  value: number;
  dateRange?: string;
};

function formatMinutes(seconds: number): string {
  const mins = Math.round(seconds / 60);
  if (mins < 60) return `${mins}분`;
  const hours = Math.floor(mins / 60);
  const remainder = mins % 60;
  return remainder > 0 ? `${hours}시간 ${remainder}분` : `${hours}시간`;
}

function getWeekBars(records: BarChartRecord[]): BarData[] {
  const DAY_LABELS = ['월', '화', '수', '목', '금', '토', '일'];
  const today = new Date();
  const bars: BarData[] = [];

  for (let i = 6; i >= 0; i--) {
    const d = new Date(today);
    d.setDate(d.getDate() - i);
    const dateStr = d.toISOString().split('T')[0];
    const record = records.find((r) => r.date === dateStr);
    bars.push({
      label: DAY_LABELS[(d.getDay() + 6) % 7],
      value: record?.studyTimeSeconds ?? 0,
      dateRange: dateStr,
    });
  }

  return bars;
}

function getMonthBars(records: BarChartRecord[]): BarData[] {
  const today = new Date();
  const bars: BarData[] = [];
  const weeksInMonth = 5;

  for (let w = weeksInMonth - 1; w >= 0; w--) {
    const weekEnd = new Date(today);
    weekEnd.setDate(weekEnd.getDate() - w * 7);
    const weekStart = new Date(weekEnd);
    weekStart.setDate(weekStart.getDate() - 6);

    let totalSeconds = 0;
    records.forEach((r) => {
      const rDate = new Date(r.date + 'T00:00:00');
      if (rDate >= weekStart && rDate <= weekEnd) {
        totalSeconds += r.studyTimeSeconds;
      }
    });

    bars.push({
      label: `${weekStart.getMonth() + 1}/${weekStart.getDate()}`,
      value: totalSeconds,
      dateRange: `${weekStart.toISOString().split('T')[0]} ~ ${weekEnd.toISOString().split('T')[0]}`,
    });
  }

  return bars;
}

function getYearBars(records: BarChartRecord[]): BarData[] {
  const MONTH_LABELS = [
    '1월',
    '2월',
    '3월',
    '4월',
    '5월',
    '6월',
    '7월',
    '8월',
    '9월',
    '10월',
    '11월',
    '12월',
  ];
  const monthTotals = new Array<number>(12).fill(0);

  records.forEach((r) => {
    const month = new Date(r.date + 'T00:00:00').getMonth();
    monthTotals[month] += r.studyTimeSeconds;
  });

  return monthTotals.map((total, i) => ({
    label: MONTH_LABELS[i],
    value: total,
  }));
}

export function BarChart({ records }: BarChartProps) {
  const [viewMode, setViewMode] = useState<ViewMode>('week');

  const bars = useMemo(() => {
    switch (viewMode) {
      case 'week':
        return getWeekBars(records);
      case 'month':
        return getMonthBars(records);
      case 'year':
        return getYearBars(records);
    }
  }, [viewMode, records]);

  const maxValue = useMemo(
    () => Math.max(...bars.map((b) => b.value), 1),
    [bars]
  );

  const totalSeconds = useMemo(
    () => bars.reduce((sum, b) => sum + b.value, 0),
    [bars]
  );

  return (
    <Card>
      <CardContent className="flex flex-col gap-3 p-4">
        {/* Header */}
        <div className="flex items-center justify-between">
          <h3 className="font-semibold">학습 시간</h3>
          <div className="bg-secondary flex rounded-lg p-0.5">
            {(Object.keys(VIEW_LABELS) as ViewMode[]).map((mode) => (
              <button
                key={mode}
                onClick={() => setViewMode(mode)}
                className={`rounded-md px-3 py-1 text-xs font-medium transition-colors ${
                  viewMode === mode
                    ? 'bg-primary text-primary-foreground'
                    : 'text-muted-foreground hover:text-foreground'
                }`}
              >
                {VIEW_LABELS[mode]}
              </button>
            ))}
          </div>
        </div>

        {/* Chart */}
        <div
          className="flex items-end justify-between gap-1.5"
          style={{ height: 120 }}
        >
          {bars.map((bar, i) => {
            const heightPercent =
              bar.value > 0 ? (bar.value / maxValue) * 100 : 0;
            return (
              <div
                key={i}
                className="flex flex-1 flex-col items-center gap-1"
              >
                {bar.value > 0 && (
                  <span className="text-muted-foreground text-[9px]">
                    {formatMinutes(bar.value)}
                  </span>
                )}
                <motion.div
                  className="bg-primary w-full rounded-t-md"
                  initial={{ height: 0 }}
                  animate={{
                    height: `${Math.max(heightPercent, bar.value > 0 ? 4 : 0)}%`,
                  }}
                  transition={{
                    delay: i * 0.04,
                    duration: 0.4,
                    ease: 'easeOut',
                  }}
                  style={{ minHeight: bar.value > 0 ? 4 : 2 }}
                />
              </div>
            );
          })}
        </div>

        {/* Labels */}
        <div className="flex justify-between gap-1.5">
          {bars.map((bar, i) => (
            <span
              key={i}
              className="text-muted-foreground flex-1 text-center text-[10px]"
            >
              {bar.label}
            </span>
          ))}
        </div>

        {/* Total */}
        <div className="text-muted-foreground text-center text-sm">
          총 학습 시간{' '}
          <span className="text-foreground font-semibold">
            {formatMinutes(totalSeconds)}
          </span>
        </div>
      </CardContent>
    </Card>
  );
}
