'use client';

import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { Check, BookOpen, MessageCircle, Target, Sparkles, Zap } from 'lucide-react';
import type { Mission } from '@/hooks/use-daily-missions';

type DailyMissionsCardProps = {
  missions: Mission[];
  completedCount: number;
  totalCount: number;
};

const MISSION_ICONS: Record<string, typeof BookOpen> = {
  words: BookOpen,
  quiz: Target,
  correct: Sparkles,
  chat: MessageCircle,
  kana: BookOpen,
};

const MISSION_ROUTES: Record<string, string> = {
  words: '/study',
  quiz: '/study',
  correct: '/study',
  chat: '/chat',
  kana: '/study/kana',
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

function getMissionRoute(missionType: string): string {
  const prefix = missionType.split('_')[0];
  return MISSION_ROUTES[prefix] ?? '/study';
}

export function DailyMissionsCard({
  missions,
  completedCount,
  totalCount,
}: DailyMissionsCardProps) {
  const router = useRouter();
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
        {[...missions].sort((a, b) => {
          // 미완료 미션을 위쪽에 배치
          if (a.rewardClaimed !== b.rewardClaimed) return a.rewardClaimed ? 1 : -1;
          return 0;
        }).map((mission) => {
          const Icon = getMissionIcon(mission.missionType);
          const isDone = mission.rewardClaimed;

          return (
            <motion.div
              key={mission.id}
              variants={item}
              className={`group flex items-center rounded-2xl border p-4 transition-colors ${
                isDone
                  ? 'border-primary/30 bg-primary/5'
                  : 'cursor-pointer border-border bg-card hover:border-primary/40 hover:bg-secondary'
              }`}
              onClick={() => {
                if (!isDone) {
                  router.push(getMissionRoute(mission.missionType));
                }
              }}
            >
              <div className={`flex size-10 shrink-0 items-center justify-center rounded-full ${
                isDone
                  ? 'bg-primary text-primary-foreground'
                  : 'bg-secondary text-primary'
              }`}>
                {isDone ? (
                  <Check className="size-[18px]" strokeWidth={3} />
                ) : (
                  <Icon className="size-[18px]" />
                )}
              </div>
              <span
                className={`ml-3 flex-1 text-sm font-medium ${
                  isDone
                    ? 'text-muted-foreground line-through'
                    : 'text-foreground/80 group-hover:text-foreground'
                }`}
              >
                {mission.label}
              </span>
              <div className="ml-3 shrink-0">
                {isDone ? (
                  <span className="flex items-center gap-1 text-xs font-semibold text-primary">
                    <Zap className="size-3" />
                    +{mission.xpReward}
                  </span>
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
