'use client';

import { motion } from 'framer-motion';
import { Gift, Check, BookOpen, MessageCircle, Target, Sparkles } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Progress } from '@/components/ui/progress';
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
    <Card>
      <CardContent className="flex flex-col gap-3 p-4">
        <div className="flex items-center justify-between">
          <h2 className="font-semibold">오늘의 미션</h2>
          <span className="text-muted-foreground text-sm">
            {completedCount}/{totalCount}
          </span>
        </div>

        {allDone && (
          <div className="bg-primary/10 text-primary flex items-center gap-2 rounded-xl px-3 py-2 text-sm font-medium">
            <Check className="size-4" />
            오늘의 미션을 모두 완료했어요!
          </div>
        )}

        <motion.div
          className="flex flex-col gap-2"
          variants={container}
          initial="hidden"
          animate="show"
        >
          {missions.map((mission) => {
            const Icon = getMissionIcon(mission.missionType);
            const progress = Math.min(
              mission.currentCount / mission.targetCount,
              1
            );
            const canClaim = mission.isCompleted && !mission.rewardClaimed;

            return (
              <motion.div
                key={mission.id}
                variants={item}
                className={`flex items-center gap-3 rounded-xl border p-3 transition-colors ${
                  mission.rewardClaimed
                    ? 'border-primary/20 bg-primary/5'
                    : 'border-border'
                }`}
              >
                <div
                  className={`flex size-9 shrink-0 items-center justify-center rounded-lg ${
                    mission.isCompleted
                      ? 'bg-primary/10 text-primary'
                      : 'bg-secondary text-muted-foreground'
                  }`}
                >
                  {mission.rewardClaimed ? (
                    <Check className="size-4" />
                  ) : (
                    <Icon className="size-4" />
                  )}
                </div>

                <div className="flex min-w-0 flex-1 flex-col gap-1">
                  <div className="flex items-center justify-between">
                    <span
                      className={`text-sm font-medium ${
                        mission.rewardClaimed
                          ? 'text-muted-foreground line-through'
                          : ''
                      }`}
                    >
                      {mission.label}
                    </span>
                    <span className="text-muted-foreground text-xs">
                      {mission.currentCount}/{mission.targetCount}
                    </span>
                  </div>
                  <Progress value={progress * 100} className="h-1.5" />
                </div>

                {canClaim && (
                  <Button
                    size="sm"
                    className="h-7 shrink-0 gap-1 rounded-lg px-2 text-xs"
                    onClick={() => onClaim(mission.id)}
                    disabled={claiming}
                  >
                    <Gift className="size-3" />
                    +{mission.xpReward}
                  </Button>
                )}
              </motion.div>
            );
          })}
        </motion.div>
      </CardContent>
    </Card>
  );
}
