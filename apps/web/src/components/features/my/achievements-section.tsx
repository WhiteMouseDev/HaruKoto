'use client';

import { useState, useMemo } from 'react';
import { motion } from 'framer-motion';
import { Lock } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { GameIcon } from '@/components/ui/game-icon';
import {
  ACHIEVEMENTS,
  type AchievementCategory,
  type AchievementType,
} from '@/lib/gamification';

type UserAchievement = {
  achievementType: string;
  achievedAt: string;
};

type AchievementsSectionProps = {
  achievements: UserAchievement[];
};

type CategoryTab = 'all' | AchievementCategory;

const CATEGORY_TABS: { value: CategoryTab; label: string }[] = [
  { value: 'all', label: '전체' },
  { value: 'quiz', label: '퀴즈' },
  { value: 'conversation', label: '회화' },
  { value: 'streak', label: '스트릭' },
  { value: 'words', label: '단어' },
  { value: 'level', label: '레벨' },
  { value: 'xp', label: 'XP' },
  { value: 'special', label: '특별' },
];

const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.03 },
  },
};

const item = {
  hidden: { scale: 0.9, opacity: 0 },
  show: { scale: 1, opacity: 1 },
};

export function AchievementsSection({
  achievements,
}: AchievementsSectionProps) {
  const [activeTab, setActiveTab] = useState<CategoryTab>('all');

  const achievedMap = useMemo(() => {
    const map = new Map<string, string>();
    for (const a of achievements) {
      map.set(a.achievementType, a.achievedAt);
    }
    return map;
  }, [achievements]);

  const filtered = useMemo(
    () =>
      activeTab === 'all'
        ? ACHIEVEMENTS
        : ACHIEVEMENTS.filter((a) => a.category === activeTab),
    [activeTab]
  );

  const achievedCount = achievements.length;

  return (
    <motion.div
      initial={{ y: 10, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ delay: 0.1 }}
    >
      <Card>
        <CardContent className="p-4">
          <div className="mb-3 flex items-center justify-between">
            <h3 className="text-base font-bold">업적</h3>
            <span className="text-muted-foreground text-sm">
              {achievedCount}/{ACHIEVEMENTS.length}
            </span>
          </div>

          <div className="-mx-1 mb-4 flex gap-1.5 overflow-x-auto px-1 pb-1">
            {CATEGORY_TABS.map((tab) => (
              <button
                key={tab.value}
                onClick={() => setActiveTab(tab.value)}
                className={`shrink-0 rounded-full px-3 py-1.5 text-xs font-medium transition-colors ${
                  activeTab === tab.value
                    ? 'bg-primary text-primary-foreground'
                    : 'bg-secondary text-muted-foreground hover:bg-secondary/80'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>

          <motion.div
            className="grid grid-cols-3 gap-2.5"
            variants={container}
            initial="hidden"
            animate="show"
            key={activeTab}
          >
            {filtered.map((achievement) => {
              const achievedAt = achievedMap.get(achievement.type);
              const isAchieved = !!achievedAt;

              return (
                <motion.div
                  key={achievement.type}
                  variants={item}
                  className={`relative flex flex-col items-center gap-1 rounded-xl p-3 ${
                    isAchieved ? 'bg-secondary' : 'bg-secondary opacity-40'
                  }`}
                >
                  {!isAchieved && (
                    <div className="absolute right-1.5 top-1.5">
                      <Lock className="text-muted-foreground size-3" />
                    </div>
                  )}
                  <GameIcon
                    name={achievement.emoji}
                    className={`size-7 ${isAchieved ? 'text-primary' : 'text-muted-foreground'}`}
                  />
                  <span className="text-center text-[11px] font-medium leading-tight">
                    {achievement.title}
                  </span>
                  {isAchieved && achievedAt && (
                    <span className="text-muted-foreground text-[10px]">
                      {new Date(achievedAt).toLocaleDateString('ko-KR', {
                        month: 'short',
                        day: 'numeric',
                      })}
                    </span>
                  )}
                </motion.div>
              );
            })}
          </motion.div>
        </CardContent>
      </Card>
    </motion.div>
  );
}
