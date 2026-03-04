'use client';

import { motion } from 'framer-motion';
import { Check, Flame } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';

type StreakBadgeProps = {
  currentStreak: number;
  weeklyStats: { date: string; wordsStudied: number }[];
};

const DAY_LABELS = ['월', '화', '수', '목', '금', '토', '일'];

export function StreakBadge({ currentStreak, weeklyStats }: StreakBadgeProps) {
  // Map weeklyStats to day-of-week completion indicators
  const weekDays = weeklyStats.map((day) => {
    const date = new Date(day.date + 'T00:00:00Z');
    const dayIndex = (date.getUTCDay() + 6) % 7; // Convert Sun=0 to Mon=0
    return {
      label: DAY_LABELS[dayIndex],
      studied: day.wordsStudied > 0,
    };
  });

  return (
    <Card>
      <CardContent className="flex flex-col gap-3 p-4">
        <div className="flex items-center gap-2">
          <motion.div
            animate={{ scale: [1, 1.2, 1] }}
            transition={{ duration: 1.5, repeat: Infinity, repeatDelay: 2 }}
          >
            <Flame className="text-hk-red size-5" />
          </motion.div>
          <span className="font-semibold">
            {currentStreak > 0
              ? `${currentStreak}일째 연속 학습 중!`
              : '오늘 첫 학습을 시작해보세요!'}
          </span>
        </div>
        <div className="flex justify-between gap-1">
          {weekDays.map((day, i) => (
            <div key={i} className="flex flex-col items-center gap-1.5">
              <span className="text-muted-foreground text-[10px]">
                {day.label}
              </span>
              <div
                className={`flex size-7 items-center justify-center rounded-full text-xs ${
                  day.studied
                    ? 'bg-primary text-primary-foreground'
                    : 'bg-secondary text-muted-foreground'
                }`}
              >
                {day.studied ? <Check className="size-3.5" strokeWidth={3} /> : '-'}
              </div>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  );
}
