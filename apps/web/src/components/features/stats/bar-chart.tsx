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

const CHART_HEIGHT = 120; // px
const BASE_LINE_PX = 3; // baseline for 0-value days
const MIN_BAR_PX = 16; // minimum bar for non-zero values

function formatMinutes(seconds: number): string {
  const mins = Math.round(seconds / 60);
  if (mins < 60) return `${mins}분`;
  const hours = Math.floor(mins / 60);
  const remainder = mins % 60;
  return remainder > 0 ? `${hours}시간 ${remainder}분` : `${hours}시간`;
}

const MAX_BAR_PX = CHART_HEIGHT - 20; // leave room for value labels

// Square-root scale so small values still look meaningful
function calcBarPx(value: number, maxValue: number): number {
  if (value <= 0) return 0;
  if (maxValue <= 0) return MIN_BAR_PX;
  const ratio = value / maxValue;
  const scaled = Math.sqrt(ratio) * MAX_BAR_PX;
  return Math.min(Math.max(scaled, MIN_BAR_PX), MAX_BAR_PX);
}

function getWeekBars(records: BarChartRecord[]): BarData[] {
  const DAY_LABELS = ['월', '화', '수', '목', '금', '토', '일'];
  const today = new Date();
  const dayOfWeek = today.getDay();
  const monday = new Date(today);
  monday.setDate(today.getDate() - ((dayOfWeek + 6) % 7));
  const bars: BarData[] = [];

  for (let i = 0; i < 7; i++) {
    const d = new Date(monday);
    d.setDate(monday.getDate() + i);
    const dateStr = d.toISOString().split('T')[0];
    const record = records.find((r) => r.date === dateStr);
    bars.push({
      label: DAY_LABELS[i],
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
    '1월', '2월', '3월', '4월', '5월', '6월',
    '7월', '8월', '9월', '10월', '11월', '12월',
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
        <motion.div
          key={viewMode}
          className="mt-1 flex items-end justify-between gap-1.5"
          style={{ height: CHART_HEIGHT }}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.2 }}
        >
          {bars.map((bar, i) => {
            const barPx = calcBarPx(bar.value, maxValue);
            return (
              <div
                key={bar.label}
                className="flex flex-1 flex-col items-center justify-end gap-1"
              >
                {bar.value > 0 && (
                  <span className="text-muted-foreground text-[9px]">
                    {formatMinutes(bar.value)}
                  </span>
                )}
                <motion.div
                  className={`w-full rounded-t-md ${
                    bar.value > 0 ? 'bg-primary' : 'bg-muted-foreground/15'
                  }`}
                  initial={{ height: 0 }}
                  animate={{ height: bar.value > 0 ? barPx : BASE_LINE_PX }}
                  transition={{
                    delay: i * 0.04,
                    duration: 0.4,
                    ease: 'easeOut',
                  }}
                />
              </div>
            );
          })}
        </motion.div>

        {/* Labels */}
        <div key={`labels-${viewMode}`} className="flex justify-between gap-1.5">
          {bars.map((bar) => (
            <span
              key={bar.label}
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
