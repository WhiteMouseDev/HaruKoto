'use client';

import { motion } from 'framer-motion';
import { Lock, BookCheck, Loader } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Progress } from '@/components/ui/progress';

type LevelProgress = {
  vocabulary: { total: number; mastered: number; inProgress: number };
  grammar: { total: number; mastered: number; inProgress: number };
};

type JlptTabProps = {
  levelProgress: LevelProgress;
  currentLevel: string;
};

const JLPT_LEVELS = ['N5', 'N4', 'N3', 'N2', 'N1'] as const;

type LevelStatus = 'completed' | 'current' | 'locked';

const item = {
  hidden: { opacity: 0, y: 12 },
  show: { opacity: 1, y: 0, transition: { duration: 0.3 } },
};

export function JlptTab({ levelProgress, currentLevel }: JlptTabProps) {
  const currentIndex = JLPT_LEVELS.indexOf(
    currentLevel as (typeof JLPT_LEVELS)[number]
  );

  const vocabProgress =
    levelProgress.vocabulary.total > 0
      ? Math.round(
          (levelProgress.vocabulary.mastered /
            levelProgress.vocabulary.total) *
            100
        )
      : 0;

  const grammarProgress =
    levelProgress.grammar.total > 0
      ? Math.round(
          (levelProgress.grammar.mastered / levelProgress.grammar.total) * 100
        )
      : 0;

  const overallProgress = Math.round((vocabProgress + grammarProgress) / 2);

  return (
    <motion.div
      className="flex flex-col gap-4"
      initial="hidden"
      animate="show"
      variants={{ show: { transition: { staggerChildren: 0.08 } } }}
    >
      {/* Current Level Overview */}
      <motion.div variants={item}>
        <Card>
          <CardContent className="flex flex-col gap-4 p-4">
            <div className="flex items-center justify-between">
              <h3 className="font-semibold">현재 레벨</h3>
              <span className="bg-primary text-primary-foreground rounded-full px-3 py-1 text-sm font-bold">
                {currentLevel}
              </span>
            </div>

            {/* Overall progress */}
            <div className="flex flex-col gap-2">
              <div className="flex items-center justify-between text-sm">
                <span className="text-muted-foreground">전체 진도</span>
                <span className="font-medium">{overallProgress}%</span>
              </div>
              <Progress value={overallProgress} />
            </div>

            {/* Vocabulary */}
            <div className="flex flex-col gap-1.5">
              <div className="flex items-center justify-between text-sm">
                <span className="text-muted-foreground">단어</span>
                <span className="text-xs">
                  <span className="font-medium">
                    {levelProgress.vocabulary.mastered}
                  </span>
                  <span className="text-muted-foreground">
                    /{levelProgress.vocabulary.total}
                  </span>
                </span>
              </div>
              <Progress value={vocabProgress} />
            </div>

            {/* Grammar */}
            <div className="flex flex-col gap-1.5">
              <div className="flex items-center justify-between text-sm">
                <span className="text-muted-foreground">문법</span>
                <span className="text-xs">
                  <span className="font-medium">
                    {levelProgress.grammar.mastered}
                  </span>
                  <span className="text-muted-foreground">
                    /{levelProgress.grammar.total}
                  </span>
                </span>
              </div>
              <Progress value={grammarProgress} />
            </div>
          </CardContent>
        </Card>
      </motion.div>

      {/* JLPT Level Cards */}
      <motion.div variants={item}>
        <Card>
          <CardContent className="flex flex-col gap-3 p-4">
            <h3 className="font-semibold">JLPT 진도</h3>
            <div className="flex flex-col gap-2">
              {JLPT_LEVELS.map((level, i) => {
                const status: LevelStatus =
                  i < currentIndex
                    ? 'completed'
                    : i === currentIndex
                      ? 'current'
                      : 'locked';

                return (
                  <motion.div
                    key={level}
                    initial={{ opacity: 0, x: -10 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: i * 0.06, duration: 0.3 }}
                    className={`flex items-center justify-between rounded-xl border p-3 ${
                      status === 'current'
                        ? 'border-primary bg-primary/5'
                        : status === 'completed'
                          ? 'border-hk-green/40 bg-hk-green/5'
                          : 'border-border opacity-50'
                    }`}
                  >
                    <div className="flex items-center gap-3">
                      <div
                        className={`flex size-10 items-center justify-center rounded-full ${
                          status === 'current'
                            ? 'bg-primary/20'
                            : status === 'completed'
                              ? 'bg-hk-green/20'
                              : 'bg-secondary'
                        }`}
                      >
                        {status === 'completed' ? (
                          <BookCheck className="text-hk-green size-5" />
                        ) : status === 'current' ? (
                          <Loader className="text-primary size-5" />
                        ) : (
                          <Lock className="text-muted-foreground size-5" />
                        )}
                      </div>
                      <div>
                        <p className="font-bold">{level}</p>
                        <p className="text-muted-foreground text-xs">
                          {status === 'current'
                            ? '학습 중'
                            : status === 'completed'
                              ? '완료'
                              : '잠금'}
                        </p>
                      </div>
                    </div>
                    {status === 'current' && (
                      <span className="text-primary text-sm font-semibold">
                        {overallProgress}%
                      </span>
                    )}
                    {status === 'completed' && (
                      <span className="text-hk-green text-sm font-semibold">
                        완료
                      </span>
                    )}
                  </motion.div>
                );
              })}
            </div>
          </CardContent>
        </Card>
      </motion.div>
    </motion.div>
  );
}
