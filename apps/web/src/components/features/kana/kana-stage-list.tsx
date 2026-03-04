'use client';

import { motion } from 'framer-motion';
import { Progress } from '@/components/ui/progress';
import { KanaStageCard } from '@/components/features/kana/kana-stage-card';
import type { KanaStageData } from '@/hooks/use-kana';

type KanaStageListProps = {
  stages: KanaStageData[];
  kanaType: 'HIRAGANA' | 'KATAKANA';
  onStageClick: (stageNumber: number) => void;
};

const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.06 },
  },
};

const item = {
  hidden: { y: 12, opacity: 0 },
  show: { y: 0, opacity: 1 },
};

export function KanaStageList({
  stages,
  kanaType,
  onStageClick,
}: KanaStageListProps) {
  const completedCount = stages.filter((s) => s.isCompleted).length;
  const totalCount = stages.length;
  const progressPercent =
    totalCount > 0 ? Math.round((completedCount / totalCount) * 100) : 0;

  const label = kanaType === 'HIRAGANA' ? '히라가나' : '가타카나';

  return (
    <div className="flex flex-col gap-4">
      {/* Progress bar */}
      <div className="flex flex-col gap-2">
        <div className="flex items-center justify-between text-sm">
          <span className="text-muted-foreground">{label} 학습 진행</span>
          <span className="font-medium">
            {completedCount}/{totalCount}
          </span>
        </div>
        <Progress value={progressPercent} />
        <span className="text-muted-foreground text-right text-xs">
          {progressPercent}%
        </span>
      </div>

      {/* Stage cards */}
      <motion.div
        className="flex flex-col gap-3"
        variants={container}
        initial="hidden"
        animate="show"
      >
        {stages.map((stage) => (
          <motion.div key={stage.id} variants={item}>
            <KanaStageCard
              stageNumber={stage.stageNumber}
              title={stage.title}
              description={stage.description}
              characters={stage.characters}
              isUnlocked={stage.isUnlocked}
              isCompleted={stage.isCompleted}
              quizScore={stage.quizScore}
              onClick={() => onStageClick(stage.stageNumber)}
            />
          </motion.div>
        ))}
      </motion.div>
    </div>
  );
}
