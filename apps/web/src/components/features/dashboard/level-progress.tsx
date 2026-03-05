'use client';

import { motion } from 'framer-motion';

type LevelProgressProps = {
  currentLevel: string;
};

const JLPT_LEVELS = ['N5', 'N4', 'N3', 'N2', 'N1'] as const;

export function LevelProgress({ currentLevel }: LevelProgressProps) {
  const currentIndex = JLPT_LEVELS.indexOf(
    currentLevel as (typeof JLPT_LEVELS)[number]
  );

  return (
    <div className="rounded-3xl border border-border bg-card p-6 shadow-sm">
      <h2 className="mb-4 text-base font-bold">JLPT 레벨</h2>
      <div className="grid grid-cols-5 gap-2">
        {JLPT_LEVELS.map((level, i) => {
          const isCurrent = i === currentIndex;
          const isPast = i < currentIndex;

          return (
            <motion.div
              key={level}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.05 }}
              className={`flex flex-col items-center gap-1 rounded-2xl border p-3 ${
                isCurrent
                  ? 'border-primary bg-primary/10'
                  : isPast
                    ? 'border-primary/40 bg-primary/5'
                    : 'border-border opacity-50'
              }`}
            >
              <span className="text-sm font-bold">{level}</span>
              <span className="text-muted-foreground text-[10px]">
                {isCurrent ? '학습중' : isPast ? '완료' : '잠금'}
              </span>
            </motion.div>
          );
        })}
      </div>
    </div>
  );
}
