'use client';

import { motion } from 'framer-motion';
import { Check } from 'lucide-react';

type WeeklyChartProps = {
  weeklyStats: { date: string; wordsStudied: number; xpEarned: number }[];
  dailyGoal?: number;
};

const DAY_LABELS = ['월', '화', '수', '목', '금', '토', '일'];

const CHART_HEIGHT = 120; // px
const GOAL_LINE_RATIO = 0.7; // goal line at 70%

// Square-root scale: small efforts still look meaningful
function barHeight(value: number, goal: number): number {
  if (value <= 0) return 0;
  const ratio = value / goal;
  const scaled = Math.sqrt(ratio) * GOAL_LINE_RATIO * CHART_HEIGHT;
  // Minimum 16px for any non-zero value
  return Math.min(Math.max(scaled, 16), CHART_HEIGHT);
}

export function WeeklyChart({ weeklyStats, dailyGoal = 10 }: WeeklyChartProps) {
  const totalWords = weeklyStats.reduce((sum, d) => sum + d.wordsStudied, 0);
  const totalXp = weeklyStats.reduce((sum, d) => sum + d.xpEarned, 0);

  const goal = dailyGoal > 0 ? dailyGoal : 10;

  const bars = weeklyStats.map((day) => {
    const date = new Date(day.date + 'T00:00:00Z');
    const dayIndex = (date.getUTCDay() + 6) % 7;
    const metGoal = day.wordsStudied >= goal;
    return {
      label: DAY_LABELS[dayIndex],
      value: day.wordsStudied,
      px: barHeight(day.wordsStudied, goal),
      metGoal,
    };
  });

  const goalLinePx = GOAL_LINE_RATIO * CHART_HEIGHT;

  return (
    <div className="rounded-3xl border border-border bg-card p-6 shadow-sm">
      <div className="mb-4 flex items-center justify-between">
        <h2 className="text-base font-bold">주간 학습</h2>
      </div>

      {/* Bar chart */}
      <div
        className="relative flex items-end justify-between gap-2"
        style={{ height: CHART_HEIGHT }}
      >
        {/* Goal line */}
        <div
          className="border-muted-foreground/30 pointer-events-none absolute left-0 right-0 border-t border-dashed"
          style={{ bottom: goalLinePx }}
        >
          <span className="text-muted-foreground/50 absolute -top-3.5 right-0 text-[9px]">
            목표
          </span>
        </div>
        {bars.map((bar, i) => (
          <div key={i} className="flex flex-1 flex-col items-end justify-end">
            {/* Goal met indicator */}
            {bar.metGoal && (
              <motion.div
                className="mb-0.5 flex w-full justify-center"
                initial={{ opacity: 0, scale: 0 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ delay: 0.4 + i * 0.05, type: 'spring', stiffness: 300 }}
              >
                <Check className="text-primary size-3" strokeWidth={3} />
              </motion.div>
            )}
            <motion.div
              className={`w-full rounded-t-md ${
                bar.value > 0
                  ? bar.metGoal ? 'bg-primary' : 'bg-primary/50'
                  : 'bg-muted-foreground/15'
              }`}
              initial={{ height: 0 }}
              animate={{ height: bar.value > 0 ? bar.px : 3 }}
              transition={{ delay: i * 0.05, duration: 0.5, ease: 'easeOut' }}
            />
          </div>
        ))}
      </div>

      {/* Day labels */}
      <div className="mt-1 flex justify-between gap-2">
        {bars.map((bar, i) => (
          <span
            key={i}
            className="text-muted-foreground flex-1 text-center text-[10px]"
          >
            {bar.label}
          </span>
        ))}
      </div>

      {/* Summary */}
      <div className="text-muted-foreground mt-4 flex justify-center gap-6 text-sm">
        <span>
          단어{' '}
          <span className="text-foreground font-semibold">{totalWords}개</span>
        </span>
        <span>
          XP <span className="text-foreground font-semibold">{totalXp}</span>
        </span>
      </div>
    </div>
  );
}
