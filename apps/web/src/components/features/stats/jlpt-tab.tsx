'use client';

import { useMemo } from 'react';
import { motion } from 'framer-motion';
import { BookOpen, BookText, ArrowRight } from 'lucide-react';
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

const JLPT_INFO: Record<string, { label: string; desc: string }> = {
  N5: { label: 'N5', desc: '기초 일본어' },
  N4: { label: 'N4', desc: '기본적인 일본어' },
  N3: { label: 'N3', desc: '일상적인 일본어' },
  N2: { label: 'N2', desc: '일반적인 일본어' },
  N1: { label: 'N1', desc: '고급 일본어' },
};

const NEXT_LEVEL: Record<string, string | null> = {
  N5: 'N4',
  N4: 'N3',
  N3: 'N2',
  N2: 'N1',
  N1: null,
};

const item = {
  hidden: { opacity: 0, y: 12 },
  show: { opacity: 1, y: 0, transition: { duration: 0.3 } },
};

export function JlptTab({ levelProgress, currentLevel }: JlptTabProps) {
  const vocab = levelProgress.vocabulary;
  const grammar = levelProgress.grammar;

  const vocabPct = vocab.total > 0
    ? Math.round((vocab.mastered / vocab.total) * 100)
    : 0;
  const grammarPct = grammar.total > 0
    ? Math.round((grammar.mastered / grammar.total) * 100)
    : 0;

  // Weighted average based on actual item counts
  const overallPct = useMemo(() => {
    const totalItems = vocab.total + grammar.total;
    if (totalItems === 0) return 0;
    const totalMastered = vocab.mastered + grammar.mastered;
    return Math.round((totalMastered / totalItems) * 100);
  }, [vocab, grammar]);

  const vocabRemaining = Math.max(0, vocab.total - vocab.mastered);
  const grammarRemaining = Math.max(0, grammar.total - grammar.mastered);

  const nextLevel = NEXT_LEVEL[currentLevel];
  const currentInfo = JLPT_INFO[currentLevel] ?? JLPT_INFO.N5;

  return (
    <motion.div
      className="flex flex-col gap-3"
      initial="hidden"
      animate="show"
      variants={{ show: { transition: { staggerChildren: 0.08 } } }}
    >
      {/* Current Level Progress */}
      <motion.div variants={item}>
        <Card>
          <CardContent className="flex flex-col gap-5 p-4">
            {/* Level badge + overall */}
            <div className="flex items-center gap-4">
              <div className="bg-primary/10 flex size-16 shrink-0 items-center justify-center rounded-2xl">
                <span className="text-primary text-2xl font-black">
                  {currentLevel}
                </span>
              </div>
              <div className="flex flex-1 flex-col gap-1.5">
                <div className="flex items-baseline justify-between">
                  <span className="font-semibold">{currentInfo.desc}</span>
                  <span className="text-primary text-lg font-bold">{overallPct}%</span>
                </div>
                <Progress value={overallPct} className="h-2.5" />
                <span className="text-muted-foreground text-[11px]">
                  마스터 {vocab.mastered + grammar.mastered} / {vocab.total + grammar.total}개
                </span>
              </div>
            </div>

            {/* Vocab & Grammar breakdown */}
            <div className="flex flex-col gap-3">
              <div className="flex flex-col gap-1.5">
                <div className="flex items-center justify-between text-sm">
                  <div className="flex items-center gap-1.5">
                    <BookOpen className="text-primary size-4" />
                    <span className="font-medium">단어</span>
                  </div>
                  <span className="text-muted-foreground text-xs">
                    <span className="text-foreground font-medium">{vocab.mastered}</span>
                    /{vocab.total}
                  </span>
                </div>
                <Progress value={vocabPct} className="h-2" />
              </div>

              <div className="flex flex-col gap-1.5">
                <div className="flex items-center justify-between text-sm">
                  <div className="flex items-center gap-1.5">
                    <BookText className="text-hk-green size-4" />
                    <span className="font-medium">문법</span>
                  </div>
                  <span className="text-muted-foreground text-xs">
                    <span className="text-foreground font-medium">{grammar.mastered}</span>
                    /{grammar.total}
                  </span>
                </div>
                <Progress value={grammarPct} className="h-2" />
              </div>
            </div>

            {/* Remaining summary */}
            {(vocabRemaining > 0 || grammarRemaining > 0) && (
              <div className="bg-secondary/50 rounded-lg p-3">
                <p className="text-muted-foreground text-xs leading-relaxed">
                  {currentLevel} 마스터까지{' '}
                  {vocabRemaining > 0 && (
                    <>단어 <span className="text-foreground font-medium">{vocabRemaining}개</span></>
                  )}
                  {vocabRemaining > 0 && grammarRemaining > 0 && ', '}
                  {grammarRemaining > 0 && (
                    <>문법 <span className="text-foreground font-medium">{grammarRemaining}개</span></>
                  )}
                  {' '}남았어요
                </p>
              </div>
            )}

            {overallPct >= 100 && (
              <div className="bg-hk-green/10 rounded-lg p-3">
                <p className="text-hk-green text-center text-sm font-semibold">
                  {currentLevel} 완전 마스터!
                </p>
              </div>
            )}
          </CardContent>
        </Card>
      </motion.div>

      {/* Next Level Teaser */}
      {nextLevel && (
        <motion.div variants={item}>
          <Card>
            <CardContent className="flex items-center gap-3 p-4">
              <div className="bg-secondary flex size-12 shrink-0 items-center justify-center rounded-xl">
                <span className="text-muted-foreground text-lg font-bold">
                  {nextLevel}
                </span>
              </div>
              <div className="flex flex-1 flex-col">
                <span className="text-sm font-medium">
                  다음 목표: {JLPT_INFO[nextLevel]?.desc}
                </span>
                <span className="text-muted-foreground text-[11px]">
                  학습 탭에서 {nextLevel} 콘텐츠를 바로 시작할 수 있어요
                </span>
              </div>
              <ArrowRight className="text-muted-foreground size-4 shrink-0" />
            </CardContent>
          </Card>
        </motion.div>
      )}
    </motion.div>
  );
}
