'use client';

import { motion } from 'framer-motion';

type WeeklyChartProps = {
  weeklyStats: { date: string; wordsStudied: number; xpEarned: number }[];
  dailyGoal?: number;
};

const DAY_LABELS = ['월', '화', '수', '목', '금', '토', '일'];

export function WeeklyChart({ weeklyStats, dailyGoal = 10 }: WeeklyChartProps) {
  const maxWords = Math.max(...weeklyStats.map((d) => d.wordsStudied), dailyGoal);
  const totalWords = weeklyStats.reduce((sum, d) => sum + d.wordsStudied, 0);
  const totalXp = weeklyStats.reduce((sum, d) => sum + d.xpEarned, 0);

  const bars = weeklyStats.map((day) => {
    const date = new Date(day.date + 'T00:00:00Z');
    const dayIndex = (date.getUTCDay() + 6) % 7;
    return {
      label: DAY_LABELS[dayIndex],
      value: day.wordsStudied,
      height: (day.wordsStudied / maxWords) * 100,
    };
  });

  return (
    <div className="rounded-3xl border border-border bg-card p-6 shadow-sm">
      <div className="mb-4 flex items-center justify-between">
        <h2 className="text-base font-bold">주간 학습</h2>
      </div>

      {/* Bar chart */}
      <div
        className="relative flex items-end justify-between gap-2"
        style={{ height: 100 }}
      >
        {/* Goal line */}
        <div
          className="border-muted-foreground/30 pointer-events-none absolute left-0 right-0 border-t border-dashed"
          style={{ bottom: `${(dailyGoal / maxWords) * 100}%` }}
        >
          <span className="text-muted-foreground/50 absolute -top-3.5 right-0 text-[9px]">
            목표
          </span>
        </div>
        {bars.map((bar, i) => (
          <div key={i} className="flex flex-1 flex-col items-center gap-1">
            <motion.div
              className="bg-primary w-full rounded-t-md"
              initial={{ height: 0 }}
              animate={{ height: `${Math.max(bar.height, 4)}%` }}
              transition={{ delay: i * 0.05, duration: 0.4, ease: 'easeOut' }}
              style={{ minHeight: bar.value > 0 ? 4 : 2 }}
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
