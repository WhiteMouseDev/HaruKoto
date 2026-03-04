'use client';

import { useState, useMemo } from 'react';
import { motion } from 'framer-motion';
import { ChevronRight, Lock } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Progress } from '@/components/ui/progress';
import { GameIcon } from '@/components/ui/game-icon';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from '@/components/ui/sheet';
import {
  ACHIEVEMENTS,
  type AchievementCategory,
} from '@/lib/gamification';

type UserAchievement = {
  achievementType: string;
  achievedAt: string;
};

type AchievementsSectionProps = {
  achievements: UserAchievement[];
};

type CategoryTab = 'all' | AchievementCategory;
type StatusFilter = 'all' | 'achieved' | 'locked';

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

const STATUS_FILTERS: { value: StatusFilter; label: string }[] = [
  { value: 'all', label: '전체' },
  { value: 'achieved', label: '완료' },
  { value: 'locked', label: '미완료' },
];

const gridContainer = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.03 },
  },
};

const gridItem = {
  hidden: { scale: 0.9, opacity: 0 },
  show: { scale: 1, opacity: 1 },
};

export function AchievementsSection({
  achievements,
}: AchievementsSectionProps) {
  const [sheetOpen, setSheetOpen] = useState(false);
  const [activeTab, setActiveTab] = useState<CategoryTab>('all');
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all');

  const achievedMap = useMemo(() => {
    const map = new Map<string, string>();
    for (const a of achievements) {
      map.set(a.achievementType, a.achievedAt);
    }
    return map;
  }, [achievements]);

  const filtered = useMemo(() => {
    let list =
      activeTab === 'all'
        ? ACHIEVEMENTS
        : ACHIEVEMENTS.filter((a) => a.category === activeTab);

    if (statusFilter === 'achieved') {
      list = list.filter((a) => achievedMap.has(a.type));
    } else if (statusFilter === 'locked') {
      list = list.filter((a) => !achievedMap.has(a.type));
    }

    // Sort: achieved first (by achievedAt descending), then locked
    return [...list].sort((a, b) => {
      const aAt = achievedMap.get(a.type);
      const bAt = achievedMap.get(b.type);
      if (aAt && !bAt) return -1;
      if (!aAt && bAt) return 1;
      if (aAt && bAt) return bAt.localeCompare(aAt);
      return 0;
    });
  }, [activeTab, statusFilter, achievedMap]);

  const achievedCount = achievements.length;
  const totalCount = ACHIEVEMENTS.length;

  // Get achieved achievements for the inline preview
  const achievedAchievements = useMemo(
    () => ACHIEVEMENTS.filter((a) => achievedMap.has(a.type)),
    [achievedMap]
  );

  return (
    <>
      <motion.div
        initial={{ y: 10, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.1 }}
      >
        <Card>
          <CardContent className="p-4">
            {/* Header Row */}
            <div className="mb-2 flex items-center justify-between">
              <h3 className="text-base font-bold">업적</h3>
              <button
                className="text-muted-foreground flex items-center gap-0.5 text-sm"
                onClick={() => setSheetOpen(true)}
              >
                <span>
                  {achievedCount}/{totalCount} 달성
                </span>
                <ChevronRight className="size-4" />
              </button>
            </div>

            {/* Progress Bar */}
            <Progress
              value={achievedCount}
              max={totalCount}
              className="mb-3 h-1.5"
            />

            {/* Achieved Icons Row */}
            {achievedAchievements.length > 0 ? (
              <div className="flex gap-2 overflow-x-auto pb-1">
                {achievedAchievements.map((achievement) => (
                  <div
                    key={achievement.type}
                    className="bg-secondary flex shrink-0 items-center justify-center rounded-lg p-2"
                  >
                    <GameIcon
                      name={achievement.emoji}
                      className="text-primary size-5"
                    />
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-muted-foreground text-center text-xs">
                첫 번째 업적을 달성해보세요!
              </p>
            )}
          </CardContent>
        </Card>
      </motion.div>

      {/* Full Achievements Sheet */}
      <Sheet open={sheetOpen} onOpenChange={setSheetOpen}>
        <SheetContent side="bottom" className="h-[85vh] rounded-t-2xl">
          <SheetHeader>
            <SheetTitle>업적</SheetTitle>
            <SheetDescription>
              {achievedCount}/{totalCount} 달성
            </SheetDescription>
          </SheetHeader>

          <div className="flex flex-1 flex-col overflow-hidden px-4 pb-4">
            {/* Sticky filter area */}
            <div className="bg-background sticky top-0 z-10 pb-2">
              {/* Category Tabs */}
              <div className="-mx-1 mb-2 flex gap-1.5 overflow-x-auto px-1 pb-1">
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

              {/* Status Filter */}
              <div className="border-border flex gap-1 rounded-lg border p-0.5">
                {STATUS_FILTERS.map((filter) => (
                  <button
                    key={filter.value}
                    onClick={() => setStatusFilter(filter.value)}
                    className={`flex-1 rounded-md px-2 py-1 text-xs font-medium transition-colors ${
                      statusFilter === filter.value
                        ? 'bg-secondary text-foreground'
                        : 'text-muted-foreground hover:text-foreground'
                    }`}
                  >
                    {filter.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Achievements Grid */}
            <motion.div
              className="grid grid-cols-3 gap-2.5 overflow-y-auto"
              variants={gridContainer}
              initial="hidden"
              animate="show"
              key={`${activeTab}-${statusFilter}`}
            >
              {filtered.map((achievement) => {
                const achievedAt = achievedMap.get(achievement.type);
                const isAchieved = !!achievedAt;

                return (
                  <motion.div
                    key={achievement.type}
                    variants={gridItem}
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
          </div>
        </SheetContent>
      </Sheet>
    </>
  );
}
