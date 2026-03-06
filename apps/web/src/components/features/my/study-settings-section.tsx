'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import {
  ChevronRight,
  BookOpen,
  Languages,
  Target,
} from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Switch } from '@/components/ui/switch';
import { Separator } from '@/components/ui/separator';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from '@/components/ui/sheet';
import { SectionLabel } from './section-label';

type JlptLevel = 'N5' | 'N4' | 'N3' | 'N2' | 'N1';

const JLPT_LEVELS: JlptLevel[] = ['N5', 'N4', 'N3', 'N2', 'N1'];
const DAILY_GOALS = [5, 10, 15, 20, 30, 50, 100];

type StudySettingsSectionProps = {
  jlptLevel: string;
  dailyGoal: number;
  showKana: boolean;
  onUpdate: (field: string, value: unknown) => Promise<void>;
};

export function StudySettingsSection({
  jlptLevel,
  dailyGoal,
  showKana,
  onUpdate,
}: StudySettingsSectionProps) {
  const [levelSheetOpen, setLevelSheetOpen] = useState(false);
  const [goalSheetOpen, setGoalSheetOpen] = useState(false);

  const handleLevelChange = (level: JlptLevel) => {
    setLevelSheetOpen(false);
    onUpdate('jlptLevel', level);
  };

  const handleGoalChange = (goal: number) => {
    setGoalSheetOpen(false);
    onUpdate('dailyGoal', goal);
  };

  return (
    <>
      <motion.div
        initial={{ y: 10, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.1 }}
        className="flex flex-col gap-1.5"
      >
        <SectionLabel>학습 설정</SectionLabel>
        <Card>
          <CardContent className="flex flex-col p-0">
            {/* JLPT Level */}
            <button
              className="hover:bg-accent flex items-center justify-between px-4 py-3.5 text-left transition-colors"
              onClick={() => setLevelSheetOpen(true)}
            >
              <div className="flex items-center gap-3">
                <BookOpen className="text-primary size-5" />
                <span className="text-sm font-medium">JLPT 레벨</span>
              </div>
              <div className="flex items-center gap-1">
                <span className="text-muted-foreground text-sm">
                  {jlptLevel}
                </span>
                <ChevronRight className="text-muted-foreground size-4" />
              </div>
            </button>

            <Separator />

            {/* Daily Goal */}
            <button
              className="hover:bg-accent flex items-center justify-between px-4 py-3.5 text-left transition-colors"
              onClick={() => setGoalSheetOpen(true)}
            >
              <div className="flex items-center gap-3">
                <Target className="text-hk-blue size-5" />
                <span className="text-sm font-medium">일일 목표</span>
              </div>
              <div className="flex items-center gap-1">
                <span className="text-muted-foreground text-sm">
                  {dailyGoal}문제
                </span>
                <ChevronRight className="text-muted-foreground size-4" />
              </div>
            </button>

            <Separator />

            {/* Show Kana */}
            <div className="flex items-center justify-between px-4 py-3.5">
              <div className="flex items-center gap-3">
                <Languages className="text-emerald-500 size-5" />
                <span className="text-sm font-medium">가나 학습 표시</span>
              </div>
              <Switch
                checked={showKana}
                onCheckedChange={(checked) => onUpdate('showKana', checked)}
              />
            </div>
          </CardContent>
        </Card>
      </motion.div>

      {/* JLPT Level Sheet */}
      <Sheet open={levelSheetOpen} onOpenChange={setLevelSheetOpen}>
        <SheetContent side="bottom" className="rounded-t-2xl">
          <SheetHeader>
            <SheetTitle>JLPT 레벨 변경</SheetTitle>
            <SheetDescription>학습할 JLPT 레벨을 선택하세요.</SheetDescription>
          </SheetHeader>
          <div className="flex flex-col gap-2 px-4 pb-6">
            {JLPT_LEVELS.map((level) => (
              <button
                key={level}
                className={`rounded-xl border px-4 py-3 text-left text-sm font-medium transition-colors ${
                  level === jlptLevel
                    ? 'border-primary bg-primary/10 text-primary'
                    : 'border-border hover:bg-accent'
                }`}
                onClick={() => handleLevelChange(level)}
              >
                {level}
                {level === jlptLevel && ' (현재)'}
              </button>
            ))}
          </div>
        </SheetContent>
      </Sheet>

      {/* Daily Goal Sheet */}
      <Sheet open={goalSheetOpen} onOpenChange={setGoalSheetOpen}>
        <SheetContent side="bottom" className="rounded-t-2xl">
          <SheetHeader>
            <SheetTitle>일일 목표 변경</SheetTitle>
            <SheetDescription>
              하루에 풀 문제 수를 선택하세요.
            </SheetDescription>
          </SheetHeader>
          <div className="flex flex-col gap-2 px-4 pb-6">
            {DAILY_GOALS.map((goal) => (
              <button
                key={goal}
                className={`rounded-xl border px-4 py-3 text-left text-sm font-medium transition-colors ${
                  goal === dailyGoal
                    ? 'border-primary bg-primary/10 text-primary'
                    : 'border-border hover:bg-accent'
                }`}
                onClick={() => handleGoalChange(goal)}
              >
                {goal}문제
                {goal === dailyGoal && ' (현재)'}
              </button>
            ))}
          </div>
        </SheetContent>
      </Sheet>
    </>
  );
}
