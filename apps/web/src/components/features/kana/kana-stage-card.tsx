'use client';

import { motion } from 'framer-motion';
import { Lock, Check, ChevronRight } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';

type KanaStageCardProps = {
  stageNumber: number;
  title: string;
  description: string;
  characters: string[];
  isUnlocked: boolean;
  isCompleted: boolean;
  quizScore: number | null;
  onClick: () => void;
};

export function KanaStageCard({
  stageNumber,
  title,
  description,
  characters,
  isUnlocked,
  isCompleted,
  quizScore,
  onClick,
}: KanaStageCardProps) {
  const isLocked = !isUnlocked;
  const isInProgress = isUnlocked && !isCompleted;

  return (
    <motion.div whileTap={isLocked ? undefined : { scale: 0.98 }}>
      <Card
        className={cn(
          'cursor-pointer py-3 transition-colors',
          isLocked && 'bg-muted opacity-60',
          isInProgress && 'border-primary bg-card',
          isCompleted && 'border-hk-success bg-hk-success/5'
        )}
        onClick={isLocked ? undefined : onClick}
        aria-disabled={isLocked}
      >
        <CardContent className="flex items-center gap-3 p-3">
          {/* Stage number badge */}
          <div
            className={cn(
              'flex size-10 shrink-0 items-center justify-center rounded-full text-sm font-bold',
              isLocked && 'bg-muted-foreground/20 text-muted-foreground',
              isInProgress && 'bg-primary text-primary-foreground',
              isCompleted && 'bg-hk-success text-white'
            )}
          >
            {isCompleted ? (
              <Check className="size-5" />
            ) : isLocked ? (
              <Lock className="size-4" />
            ) : (
              stageNumber
            )}
          </div>

          {/* Content */}
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2">
              <h4 className="truncate font-semibold">{title}</h4>
              {quizScore !== null && (
                <Badge
                  variant="secondary"
                  className="shrink-0 text-[10px] bg-hk-success/20 text-hk-success"
                >
                  {quizScore}점
                </Badge>
              )}
            </div>
            <p className="text-muted-foreground mt-0.5 text-xs">{description}</p>
            {/* Character preview */}
            <div className="font-jp text-muted-foreground mt-1 flex gap-1.5 text-sm">
              {characters.slice(0, 5).map((char) => (
                <span
                  key={char}
                  className={cn(
                    'flex size-7 items-center justify-center rounded-md bg-secondary text-xs',
                    isCompleted && 'bg-hk-success/10 text-hk-success'
                  )}
                >
                  {char}
                </span>
              ))}
              {characters.length > 5 && (
                <span className="flex size-7 items-center justify-center rounded-md bg-secondary text-[10px]">
                  +{characters.length - 5}
                </span>
              )}
            </div>
          </div>

          {/* Chevron */}
          {!isLocked && (
            <ChevronRight className="text-muted-foreground size-4 shrink-0" />
          )}
        </CardContent>
      </Card>
    </motion.div>
  );
}
