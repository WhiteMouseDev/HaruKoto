'use client';

import { motion } from 'framer-motion';
import { Target, BookOpen, Trophy } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { cardHoverVariants } from '@/lib/motion';
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

  const animatedWords = useCountUp(wordsStudied, 0.8, 0.3);
  const animatedAccuracy = useCountUp(accuracyPercent, 0.8, 0.3);

  return (
    <motion.div
      variants={cardHoverVariants}
      initial="rest"
      whileHover="hover"
      whileTap="tap"
    >
      <Card>
        <CardContent className="flex flex-col gap-4 p-4">
          <h2 className="font-semibold">오늘의 학습</h2>

          {/* Goal progress bar */}
          <div className="flex flex-col gap-2">
            <div className="flex items-center justify-between text-sm">
              <span className="text-muted-foreground">하루 목표</span>
              <span className="font-medium">
                {wordsStudied}/{dailyGoal}
              </span>
            </div>
            <div className="bg-secondary h-2 overflow-hidden rounded-full">
              <motion.div
                className="bg-primary h-full rounded-full"
                initial={{ width: 0 }}
                animate={{ width: `${progressPercent}%` }}
                transition={{ duration: 0.8, delay: 0.3, ease: 'easeOut' }}
              />
            </div>
            <span className="text-muted-foreground text-right text-xs">
              {progressPercent}%
            </span>
          </div>

          {/* Stats grid */}
          <div className="grid grid-cols-3 gap-3">
            <div className="bg-secondary flex flex-col items-center gap-1 rounded-xl p-3">
              <Target className="text-primary size-5" />
              <span className="text-muted-foreground text-xs">목표</span>
              <span className="text-lg font-bold">
                {animatedWords}/{dailyGoal}
              </span>
            </div>
            <div className="bg-secondary flex flex-col items-center gap-1 rounded-xl p-3">
              <BookOpen className="text-hk-blue size-5" />
              <span className="text-muted-foreground text-xs">단어</span>
              <span className="text-lg font-bold">{animatedWords}개</span>
            </div>
            <div className="bg-secondary flex flex-col items-center gap-1 rounded-xl p-3">
              <Trophy className="text-hk-yellow size-5" />
              <span className="text-muted-foreground text-xs">정답률</span>
              <span className="text-lg font-bold">
                {totalAnswers > 0 ? `${animatedAccuracy}%` : '--%'}
              </span>
            </div>
          </div>
        </CardContent>
      </Card>
    </motion.div>
  );
}
