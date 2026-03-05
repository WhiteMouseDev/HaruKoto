'use client';

import { motion } from 'framer-motion';
import { Gift, Check, BookOpen, MessageCircle, Target, Sparkles } from 'lucide-react';
import { Button } from '@/components/ui/button';
import type { Mission } from '@/hooks/use-daily-missions';

type DailyMissionsCardProps = {
  missions: Mission[];
  completedCount: number;
  totalCount: number;
  onClaim: (missionId: string) => void;
  claiming: boolean;
};

const MISSION_ICONS: Record<string, typeof BookOpen> = {
  words: BookOpen,
  quiz: Target,
  correct: Sparkles,
  chat: MessageCircle,
};

function getMissionIcon(missionType: string) {
  const prefix = missionType.split('_')[0];
  return MISSION_ICONS[prefix] ?? Target;
}

const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.06 },
  },
};

const item = {
  hidden: { x: -8, opacity: 0 },
  show: { x: 0, opacity: 1 },
};

export function DailyMissionsCard({
  missions,
  completedCount,
  totalCount,
  onClaim,
  claiming,
}: DailyMissionsCardProps) {
  const allDone = completedCount === totalCount;

  return (
    <div className="overflow-hidden rounded-3xl border border-border bg-card p-6 shadow-sm">
      <div className="mb-5 flex items-end justify-between">
        <h3 className="text-base font-bold">오늘의 미션</h3>
        <span className="text-muted-foreground text-sm font-medium">
          <span className="font-bold text-foreground">{completedCount}</span>/
          {totalCount}
        </span>
      </div>

      {allDone && (
        <div className="bg-primary/10 text-primary mb-3 flex items-center gap-2 rounded-2xl px-3 py-2 text-sm font-medium">
          <Check className="size-4" />
          오늘의 미션을 모두 완료했어요!
        </div>
      )}

      <motion.div
        className="flex flex-col gap-3"
        variants={container}
        initial="hidden"
        animate="show"
      >
        {missions.map((mission) => {
          const Icon = getMissionIcon(mission.missionType);
          const canClaim = mission.isCompleted && !mission.rewardClaimed;

          return (
            <motion.div
              key={mission.id}
              variants={item}
              className={`group flex cursor-pointer items-center rounded-2xl border p-4 transition-colors ${
                mission.rewardClaimed
                  ? 'border-primary/20 bg-primary/5 opacity-60'
                  : 'border-border bg-card hover:border-primary/40 hover:bg-secondary'
              }`}
            >
              <div className="flex size-10 shrink-0 items-center justify-center rounded-full bg-secondary text-primary">
                {mission.rewardClaimed ? (
                  <Check className="size-[18px]" />
                ) : (
                  <Icon className="size-[18px]" />
                )}
              </div>
              <span
                className={`ml-3 flex-1 text-sm font-medium ${
                  mission.rewardClaimed
                    ? 'text-muted-foreground line-through'
                    : 'text-foreground/80 group-hover:text-foreground'
                }`}
              >
                {mission.label}
              </span>
              <div className="ml-3 shrink-0">
                {canClaim ? (
                  <Button
                    size="sm"
                    className="h-7 gap-1 rounded-lg px-2 text-xs"
                    onClick={() => onClaim(mission.id)}
                    disabled={claiming}
                  >
                    <Gift className="size-3" />
                    +{mission.xpReward}
                  </Button>
                ) : (
                  <span className="text-sm font-semibold text-muted-foreground">
                    {mission.currentCount}/{mission.targetCount}
                  </span>
                )}
              </div>
            </motion.div>
          );
        })}
      </motion.div>
    </div>
  );
}
