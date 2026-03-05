'use client';

import { motion } from 'framer-motion';
import { Check, Flame } from 'lucide-react';

type StreakBadgeProps = {
  currentStreak: number;
  weeklyStats: { date: string; wordsStudied: number }[];
};

const DAY_LABELS = ['월', '화', '수', '목', '금', '토', '일'];

export function StreakBadge({ currentStreak, weeklyStats }: StreakBadgeProps) {
  const today = new Date();
  const todayIndex = (today.getDay() + 6) % 7; // Mon=0

  const weekDays = weeklyStats.map((day) => {
    const date = new Date(day.date + 'T00:00:00Z');
    const dayIndex = (date.getUTCDay() + 6) % 7;
    return {
      label: DAY_LABELS[dayIndex],
      studied: day.wordsStudied > 0,
      isToday:
        dayIndex === todayIndex &&
        date.toISOString().slice(0, 10) === today.toISOString().slice(0, 10),
    };
  });

  return (
    <div>
      <div className="mb-5 flex items-center gap-2">
        <motion.div
          animate={{ scale: [1, 1.2, 1] }}
          transition={{ duration: 1.5, repeat: Infinity, repeatDelay: 2 }}
        >
          <Flame size={20} className="fill-primary text-primary" />
        </motion.div>
        <h3 className="text-base font-bold">
          {currentStreak > 0
            ? `${currentStreak}일째 연속 학습 중!`
            : '오늘 첫 학습을 시작해보세요!'}
        </h3>
      </div>

      <div className="flex items-center justify-between">
        {weekDays.map((day, i) => (
          <div key={i} className="flex flex-col items-center gap-2">
            <span className="text-muted-foreground text-xs font-medium">
              {day.label}
            </span>
            <div
              className={`flex size-8 items-center justify-center rounded-full text-sm font-medium transition-colors ${
                day.studied
                  ? 'bg-primary text-primary-foreground shadow-sm'
                  : day.isToday
                    ? 'bg-secondary text-primary'
                    : 'bg-muted text-muted-foreground/40'
              }`}
            >
              {day.studied ? <Check size={16} strokeWidth={3} /> : '-'}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
