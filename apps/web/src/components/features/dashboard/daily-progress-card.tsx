'use client';

import { motion } from 'framer-motion';
import { Target, BookOpen, Trophy } from 'lucide-react';
import { useCountUp } from '@/hooks/use-count-up';

type DailyProgressCardProps = {
  dailyGoal: number;
  wordsStudied: number;
  correctAnswers: number;
  totalAnswers: number;
  goalProgress: number;
};

export function DailyProgressCard({
  dailyGoal,
  wordsStudied,
  correctAnswers,
  totalAnswers,
  goalProgress,
}: DailyProgressCardProps) {
  const accuracyPercent =
    totalAnswers > 0 ? Math.round((correctAnswers / totalAnswers) * 100) : 0;
  const progressPercent = Math.round(goalProgress * 100);

  const animatedProgress = useCountUp(progressPercent, 0.8, 0.3);
  const animatedWords = useCountUp(wordsStudied, 0.8, 0.3);
  const animatedAccuracy = useCountUp(accuracyPercent, 0.8, 0.3);

  return (
    <div>
      <div className="mb-3 flex items-end justify-between">
        <h3 className="text-base font-bold">오늘의 학습</h3>
        <span className="text-muted-foreground text-sm font-medium">
          <span className="font-bold text-foreground">{wordsStudied}</span>/
          {dailyGoal}
        </span>
      </div>

      {/* Progress Bar */}
      <div className="bg-secondary mb-5 h-2 w-full overflow-hidden rounded-full">
        <motion.div
          className="bg-primary h-full rounded-full"
          initial={{ width: 0 }}
          animate={{ width: `${Math.max(progressPercent, 2)}%` }}
          transition={{ duration: 0.8, delay: 0.3, ease: 'easeOut' }}
        />
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-3 gap-3">
        <div className="bg-secondary flex flex-col items-center justify-center rounded-2xl p-4 text-center">
          <Target size={20} className="text-primary mb-2" />
          <span className="text-muted-foreground mb-1 text-xs font-medium">
            목표
          </span>
          <span className="text-lg font-bold">
            {animatedProgress}
            <span className="text-muted-foreground text-sm font-medium">
              %
            </span>
          </span>
        </div>
        <div className="bg-secondary flex flex-col items-center justify-center rounded-2xl p-4 text-center">
          <BookOpen size={20} className="text-hk-blue mb-2" />
          <span className="text-muted-foreground mb-1 text-xs font-medium">
            단어
          </span>
          <span className="text-lg font-bold">
            {animatedWords}
            <span className="text-muted-foreground text-sm font-medium">
              개
            </span>
          </span>
        </div>
        <div className="bg-secondary flex flex-col items-center justify-center rounded-2xl p-4 text-center">
          <Trophy size={20} className="text-hk-yellow mb-2" />
          <span className="text-muted-foreground mb-1 text-xs font-medium">
            정답률
          </span>
          <span className="text-lg font-bold">
            {totalAnswers > 0 ? animatedAccuracy : '--'}
            <span className="text-muted-foreground text-sm font-medium">
              %
            </span>
          </span>
        </div>
      </div>
    </div>
  );
}
