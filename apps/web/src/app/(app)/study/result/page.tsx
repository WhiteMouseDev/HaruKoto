'use client';

import { Suspense } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import {
  Trophy,
  Zap,
  Target,
  RotateCcw,
  Home,
  PartyPopper,
  ThumbsUp,
  Dumbbell,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';

export default function QuizResultPage() {
  return (
    <Suspense>
      <ResultContent />
    </Suspense>
  );
}

function ResultContent() {
  const router = useRouter();
  const searchParams = useSearchParams();

  const correct = parseInt(searchParams.get('correct') || '0');
  const total = parseInt(searchParams.get('total') || '0');
  const xp = parseInt(searchParams.get('xp') || '0');
  const accuracy = parseInt(searchParams.get('accuracy') || '0');
  const quizType = searchParams.get('type') || 'VOCABULARY';
  const jlptLevel = searchParams.get('level') || 'N5';
  const currentXp = parseInt(searchParams.get('currentXp') || '0');
  const xpForNext = parseInt(searchParams.get('xpForNext') || '100');

  const ResultIcon =
    accuracy >= 80 ? PartyPopper : accuracy >= 50 ? ThumbsUp : Dumbbell;
  const message =
    accuracy >= 80
      ? '훌륭해요!'
      : accuracy >= 50
        ? '잘 하셨어요!'
        : '다음엔 더 잘할 수 있어요!';

  return (
    <div className="flex min-h-dvh flex-col items-center justify-center gap-6 p-6">
      {/* Mascot & Message */}
      <motion.div
        className="flex flex-col items-center gap-2"
        initial={{ scale: 0.8, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{ duration: 0.5, type: 'spring' }}
      >
        <ResultIcon className="text-primary size-14" />
        <h1 className="text-2xl font-bold">{message}</h1>
      </motion.div>

      {/* Score Card */}
      <motion.div
        className="w-full max-w-sm"
        initial={{ y: 30, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.2 }}
      >
        <Card>
          <CardContent className="flex flex-col items-center gap-5 p-6">
            {/* Accuracy Circle */}
            <div className="relative flex size-28 items-center justify-center">
              <svg
                className="absolute size-full -rotate-90"
                viewBox="0 0 100 100"
              >
                <circle
                  cx="50"
                  cy="50"
                  r="42"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="8"
                  className="text-secondary"
                />
                <motion.circle
                  cx="50"
                  cy="50"
                  r="42"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="8"
                  strokeLinecap="round"
                  className="text-primary"
                  strokeDasharray={`${2 * Math.PI * 42}`}
                  initial={{ strokeDashoffset: 2 * Math.PI * 42 }}
                  animate={{
                    strokeDashoffset: 2 * Math.PI * 42 * (1 - accuracy / 100),
                  }}
                  transition={{ duration: 1, delay: 0.5, ease: 'easeOut' }}
                />
              </svg>
              <div className="flex flex-col items-center">
                <span className="text-2xl font-bold">{accuracy}%</span>
                <span className="text-muted-foreground text-xs">정답률</span>
              </div>
            </div>

            {/* Stats */}
            <div className="grid w-full grid-cols-3 gap-3">
              <div className="bg-secondary flex flex-col items-center gap-1 rounded-xl p-3">
                <Target className="text-primary size-4" />
                <span className="text-lg font-bold">
                  {correct}/{total}
                </span>
                <span className="text-muted-foreground text-[10px]">정답</span>
              </div>
              <div className="bg-secondary flex flex-col items-center gap-1 rounded-xl p-3">
                <Zap className="text-hk-yellow size-4" />
                <span className="text-lg font-bold">+{xp}</span>
                <span className="text-muted-foreground text-[10px]">XP</span>
                <div className="mt-1 h-1.5 w-full overflow-hidden rounded-full bg-black/10 dark:bg-white/10">
                  <motion.div
                    className="bg-hk-yellow h-full rounded-full"
                    initial={{ width: 0 }}
                    animate={{
                      width: `${Math.min(Math.round((currentXp / xpForNext) * 100), 100)}%`,
                    }}
                    transition={{ duration: 0.8, delay: 0.7, ease: 'easeOut' }}
                  />
                </div>
                <span className="text-muted-foreground text-[9px]">
                  다음 레벨까지 {xpForNext - currentXp} XP
                </span>
              </div>
              <div className="bg-secondary flex flex-col items-center gap-1 rounded-xl p-3">
                <Trophy className="text-hk-blue size-4" />
                <span className="text-lg font-bold">{total - correct}</span>
                <span className="text-muted-foreground text-[10px]">오답</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </motion.div>

      {/* Actions */}
      <motion.div
        className="flex w-full max-w-sm flex-col gap-2.5"
        initial={{ y: 20, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.4 }}
      >
        {total - correct > 0 && (
          <Button
            variant="outline"
            className="h-12 rounded-xl text-base"
            onClick={() =>
              router.replace(
                `/study/quiz?type=${quizType}&level=${jlptLevel}&count=10&mode=review`
              )
            }
          >
            <RotateCcw className="mr-2 size-4" />
            오답 복습하기
          </Button>
        )}
        <Button
          className="h-12 rounded-xl text-base"
          onClick={() =>
            router.replace(
              `/study/quiz?type=${quizType}&level=${jlptLevel}&count=10`
            )
          }
        >
          <RotateCcw className="mr-2 size-4" />한 번 더 도전
        </Button>
        <Button
          variant="ghost"
          className="h-12 rounded-xl text-base"
          onClick={() => router.replace('/home')}
        >
          <Home className="mr-2 size-4" />
          홈으로 돌아가기
        </Button>
      </motion.div>
    </div>
  );
}
