'use client';

import { useState, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  BookOpen,
  ChevronLeft,
  ChevronRight,
  BookmarkPlus,
  Check,
  RotateCcw,
} from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { useAddWord } from '@/hooks/use-wordbook';
import { toast } from 'sonner';

type RecommendedExpression = {
  ja: string;
  ko: string;
};

type GrammarCorrection = {
  original: string;
  corrected: string;
  explanation: string;
};

type ExpressionFlashcardsProps = {
  expressions: RecommendedExpression[];
  corrections: GrammarCorrection[];
  conversationId: string;
};

export function ExpressionFlashcards({
  expressions,
  corrections,
  conversationId,
}: ExpressionFlashcardsProps) {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [flipped, setFlipped] = useState(false);
  const [savedExpressions, setSavedExpressions] = useState<Set<number>>(new Set());
  const [savedCorrections, setSavedCorrections] = useState<Set<number>>(new Set());
  const [savingAll, setSavingAll] = useState(false);
  const addWord = useAddWord();

  const hasExpressions = expressions.length > 0;
  const hasCorrections = corrections.length > 0;

  const handleFlip = useCallback(() => setFlipped((prev) => !prev), []);

  const handleNext = useCallback(() => {
    setFlipped(false);
    setCurrentIndex((prev) => Math.min(prev + 1, expressions.length - 1));
  }, [expressions.length]);

  const handlePrev = useCallback(() => {
    setFlipped(false);
    setCurrentIndex((prev) => Math.max(prev - 1, 0));
  }, []);

  const saveExpression = useCallback(
    async (index: number) => {
      if (savedExpressions.has(index)) return;
      const expr = expressions[index];
      try {
        await addWord.mutateAsync({
          word: expr.ja,
          reading: expr.ja,
          meaningKo: expr.ko,
          source: 'CONVERSATION',
          note: `통화 피드백에서 저장 (${conversationId.slice(0, 8)})`,
        });
        setSavedExpressions((prev) => new Set(prev).add(index));
        toast.success('단어장에 저장했어요');
      } catch {
        toast.error('저장에 실패했어요');
      }
    },
    [expressions, savedExpressions, addWord, conversationId]
  );

  const saveCorrection = useCallback(
    async (index: number) => {
      if (savedCorrections.has(index)) return;
      const corr = corrections[index];
      try {
        await addWord.mutateAsync({
          word: corr.corrected,
          reading: corr.corrected,
          meaningKo: corr.explanation,
          source: 'CONVERSATION',
          note: `❌ ${corr.original} → ✅ ${corr.corrected}`,
        });
        setSavedCorrections((prev) => new Set(prev).add(index));
        toast.success('단어장에 저장했어요');
      } catch {
        toast.error('저장에 실패했어요');
      }
    },
    [corrections, savedCorrections, addWord]
  );

  const saveAllExpressions = useCallback(async () => {
    setSavingAll(true);
    let savedCount = 0;
    for (let i = 0; i < expressions.length; i++) {
      if (savedExpressions.has(i)) continue;
      try {
        await addWord.mutateAsync({
          word: expressions[i].ja,
          reading: expressions[i].ja,
          meaningKo: expressions[i].ko,
          note: `통화 피드백에서 저장 (${conversationId.slice(0, 8)})`,
        });
        setSavedExpressions((prev) => new Set(prev).add(i));
        savedCount++;
      } catch {
        // skip duplicates
      }
    }
    setSavingAll(false);
    if (savedCount > 0) {
      toast.success(`${savedCount}개 표현을 단어장에 저장했어요`);
    } else {
      toast.info('이미 모든 표현이 저장되어 있어요');
    }
  }, [expressions, savedExpressions, addWord, conversationId]);

  if (!hasExpressions && !hasCorrections) return null;

  const allExpressionsSaved =
    expressions.length > 0 &&
    expressions.every((_, i) => savedExpressions.has(i));

  return (
    <div className="space-y-4">
      {/* Expression Flashcards */}
      {hasExpressions && (
        <Card className="py-4">
          <CardContent className="space-y-4 px-5">
            <div className="flex items-center justify-between">
              <h3 className="flex items-center gap-2 font-semibold">
                <BookOpen className="text-hk-info size-4" />
                추천 표현 학습
              </h3>
              <span className="text-muted-foreground text-xs">
                {currentIndex + 1} / {expressions.length}
              </span>
            </div>

            {/* Flashcard */}
            <div
              className="relative cursor-pointer perspective-1000"
              onClick={handleFlip}
              style={{ minHeight: 120 }}
            >
              <AnimatePresence mode="wait">
                <motion.div
                  key={`${currentIndex}-${flipped}`}
                  initial={{ rotateY: 90, opacity: 0 }}
                  animate={{ rotateY: 0, opacity: 1 }}
                  exit={{ rotateY: -90, opacity: 0 }}
                  transition={{ duration: 0.25 }}
                  className="bg-secondary/60 flex min-h-[120px] flex-col items-center justify-center rounded-xl px-6 py-5"
                >
                  {!flipped ? (
                    <>
                      <span className="font-jp text-center text-xl font-medium leading-relaxed">
                        {expressions[currentIndex].ja}
                      </span>
                      <span className="text-muted-foreground mt-2 text-xs">
                        탭하여 뜻 보기
                      </span>
                    </>
                  ) : (
                    <>
                      <span className="text-center text-base font-medium">
                        {expressions[currentIndex].ko}
                      </span>
                      <span className="font-jp text-muted-foreground mt-2 text-sm">
                        {expressions[currentIndex].ja}
                      </span>
                    </>
                  )}
                </motion.div>
              </AnimatePresence>
            </div>

            {/* Navigation + Save */}
            <div className="flex items-center justify-between">
              <Button
                variant="ghost"
                size="icon"
                className="size-9"
                onClick={handlePrev}
                disabled={currentIndex === 0}
              >
                <ChevronLeft className="size-5" />
              </Button>

              <Button
                variant="outline"
                size="sm"
                className="gap-1.5"
                onClick={() => saveExpression(currentIndex)}
                disabled={savedExpressions.has(currentIndex) || addWord.isPending}
              >
                {savedExpressions.has(currentIndex) ? (
                  <>
                    <Check className="size-3.5" />
                    저장됨
                  </>
                ) : (
                  <>
                    <BookmarkPlus className="size-3.5" />
                    단어장에 저장
                  </>
                )}
              </Button>

              <Button
                variant="ghost"
                size="icon"
                className="size-9"
                onClick={handleNext}
                disabled={currentIndex === expressions.length - 1}
              >
                <ChevronRight className="size-5" />
              </Button>
            </div>

            {/* Save all button */}
            {expressions.length > 1 && (
              <Button
                variant="secondary"
                className="w-full gap-2"
                size="sm"
                onClick={saveAllExpressions}
                disabled={allExpressionsSaved || savingAll}
              >
                {allExpressionsSaved ? (
                  <>
                    <Check className="size-3.5" />
                    전체 저장 완료
                  </>
                ) : savingAll ? (
                  '저장 중...'
                ) : (
                  <>
                    <BookmarkPlus className="size-3.5" />
                    전체 단어장에 저장 ({expressions.length}개)
                  </>
                )}
              </Button>
            )}
          </CardContent>
        </Card>
      )}

      {/* Corrections → Wordbook */}
      {hasCorrections && (
        <Card className="py-4">
          <CardContent className="space-y-3 px-5">
            <h3 className="flex items-center gap-2 font-semibold">
              <RotateCcw className="size-4 text-rose-500" />
              교정 표현 저장
            </h3>
            <p className="text-muted-foreground text-xs">
              틀린 표현을 단어장에 저장하여 복습하세요
            </p>
            <div className="space-y-2">
              {corrections.map((corr, i) => (
                <div
                  key={i}
                  className="bg-secondary/50 flex items-start gap-3 rounded-lg px-3 py-2.5"
                >
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-1.5 text-sm">
                      <span className="font-jp text-rose-500 line-through">
                        {corr.original}
                      </span>
                      <span className="text-muted-foreground">→</span>
                      <span className="font-jp font-medium text-emerald-600">
                        {corr.corrected}
                      </span>
                    </div>
                    <p className="text-muted-foreground mt-0.5 text-xs">
                      {corr.explanation}
                    </p>
                  </div>
                  <button
                    className={`mt-0.5 shrink-0 rounded-md px-2 py-1 text-xs font-medium transition-colors ${
                      savedCorrections.has(i)
                        ? 'bg-primary/10 text-primary'
                        : 'bg-secondary text-muted-foreground hover:text-foreground'
                    }`}
                    onClick={() => saveCorrection(i)}
                    disabled={savedCorrections.has(i) || addWord.isPending}
                  >
                    {savedCorrections.has(i) ? (
                      <Check className="size-3.5" />
                    ) : (
                      <BookmarkPlus className="size-3.5" />
                    )}
                  </button>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
