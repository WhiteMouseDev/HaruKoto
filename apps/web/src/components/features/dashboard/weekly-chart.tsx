'use client';

import { motion } from 'framer-motion';
import { Check } from 'lucide-react';
import type { DashboardData } from '@/hooks/use-dashboard';

type WeeklyChartProps = {
  weeklyStats: DashboardData['weeklyStats'];
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
  const totalXp = weeklyStats.reduce((sum, d) => sum + d.xpEarned, 0);

  const goal = dailyGoal > 0 ? dailyGoal : 10;

  const bars = weeklyStats.map((day) => {
    const date = new Date(day.date + 'T00:00:00Z');
    const dayIndex = (date.getUTCDay() + 6) % 7;
    const savedCount = day.vocabularyAnsweredCount;
    const hasSavedCount =
      typeof savedCount === 'number' &&
      Number.isInteger(savedCount) &&
      savedCount >= 0;
    const value = hasSavedCount ? savedCount : day.wordsStudied;
    const metGoal = value >= goal;
    // Historical saved answers can still appear as activity without backfilling
    // attendance. Completion-only XP must not recreate an explicit FALSE day.
    const hasActivity =
      day.hasStudied === true ||
      (hasSavedCount && value > 0) ||
      (day.hasStudied == null && (value > 0 || day.xpEarned > 0));
    return {
      date: day.date,
      label: DAY_LABELS[dayIndex],
      value,
      hasSavedCount,
      hasActivity,
      px: barHeight(value, goal),
      metGoal,
    };
  });

  const totalWords = bars.reduce((sum, day) => sum + day.value, 0);
  const hasLegacyCounts = bars.some((day) => !day.hasSavedCount);
  const activeDays = bars.filter((day) => day.hasActivity).length;
  const goalLinePx = GOAL_LINE_RATIO * CHART_HEIGHT;

  return (
    <div className="border-border bg-card rounded-3xl border p-6 shadow-sm">
      <div className="mb-4 flex items-center justify-between">
        <h2 className="text-base font-bold">주간 학습</h2>
      </div>

      <p className="text-muted-foreground mb-4 text-xs">
        {hasLegacyCounts
          ? '일부 날짜는 완료한 퀴즈 기준으로 표시해요.'
          : '저장한 단어 수예요. 같은 날 중복은 한 번만 세요.'}
      </p>
      {activeDays === 0 && (
        <p className="text-muted-foreground mb-3 text-xs">
          아직 이번 주 학습 활동이 없어요.
        </p>
      )}

      {/* Bar chart */}
      <div
        className="relative flex items-end justify-between gap-2"
        style={{ height: CHART_HEIGHT }}
      >
        {/* Goal line */}
        <div
          className="border-muted-foreground/30 pointer-events-none absolute right-0 left-0 border-t border-dashed"
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
                transition={{
                  delay: 0.4 + i * 0.05,
                  type: 'spring',
                  stiffness: 300,
                }}
              >
                <Check className="text-primary size-3" strokeWidth={3} />
              </motion.div>
            )}
            <motion.div
              role="img"
              aria-label={`${bar.date} · ${bar.hasSavedCount ? '저장한 단어' : '완료 집계'} ${bar.value}개${bar.metGoal ? ' · 목표 달성' : ''}`}
              className={`w-full rounded-t-md ${
                bar.value > 0
                  ? bar.metGoal
                    ? 'bg-primary'
                    : 'bg-primary/50'
                  : 'bg-muted-foreground/15'
              }`}
              initial={{ height: 0 }}
              animate={{ height: bar.px }}
              transition={{ delay: i * 0.05, duration: 0.5, ease: 'easeOut' }}
            />
          </div>
        ))}
      </div>

      {/* Day labels */}
      <div className="mt-1 flex justify-between gap-2">
        {bars.map((bar, i) => (
          <div
            key={i}
            className="text-muted-foreground flex flex-1 flex-col items-center gap-1 text-[10px]"
          >
            <span
              role="img"
              aria-label={`${bar.date} · 학습 활동 ${bar.hasActivity ? '있음' : '없음'}`}
              className={`size-1.5 rounded-full ${bar.hasActivity ? 'bg-primary' : 'bg-transparent'}`}
            />
            <span>{bar.label}</span>
          </div>
        ))}
      </div>

      {/* Summary */}
      <div className="text-muted-foreground mt-4 flex justify-center gap-6 text-sm">
        <span>
          {hasLegacyCounts ? '단어(일부 완료 기준)' : '단어 학습'}{' '}
          <span className="text-foreground font-semibold">{totalWords}개</span>
        </span>
        <span>
          XP <span className="text-foreground font-semibold">{totalXp}</span>
        </span>
      </div>
      <p className="text-muted-foreground mt-2 text-center text-[10px]">
        학습 활동 {activeDays}일 · 점은 학습 여부, 막대는 단어 수예요.
      </p>
      <p className="text-muted-foreground mt-1 text-center text-[10px]">
        단어 합계는 하루별 개수의 합이며, XP는 완료한 학습 기준이에요.
      </p>
    </div>
  );
}
