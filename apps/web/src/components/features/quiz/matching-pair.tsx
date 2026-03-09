'use client';

import { useState, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Flame } from 'lucide-react';
import { cn } from '@/lib/utils';
import { playSound } from '@/lib/sounds';

type MatchingPair = {
  id: string;
  left: string;
  right: string;
};

type MatchingPairQuizProps = {
  pairs: MatchingPair[];
  onComplete: (result: {
    correct: number;
    total: number;
    wrongPairIds: string[];
  }) => void;
  onMatchResult?: (pairId: string, isCorrect: boolean) => void;
};

type FeedbackState = {
  type: 'idle' | 'correct' | 'incorrect';
  pairId?: string;
};

export function MatchingPairQuiz({
  pairs,
  onComplete,
  onMatchResult,
}: MatchingPairQuizProps) {
  const [selectedLeft, setSelectedLeft] = useState<string | null>(null);
  const [matchedPairs, setMatchedPairs] = useState<Set<string>>(new Set());
  const [wrongPairs, setWrongPairs] = useState<string[]>([]);
  const [feedback, setFeedback] = useState<FeedbackState>({ type: 'idle' });
  const [fadingOut, setFadingOut] = useState<Set<string>>(new Set());
  const [streak, setStreak] = useState(0);

  // Shuffle right column once on mount
  const [shuffledRight] = useState(() => {
    const rights = pairs.map((p) => ({ pairId: p.id, text: p.right }));
    for (let i = rights.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [rights[i], rights[j]] = [rights[j], rights[i]];
    }
    return rights;
  });

  const handleLeftSelect = useCallback(
    (pairId: string) => {
      if (feedback.type !== 'idle' || matchedPairs.has(pairId) || fadingOut.has(pairId)) return;
      setSelectedLeft((prev) => (prev === pairId ? null : pairId));
    },
    [feedback.type, matchedPairs, fadingOut]
  );

  const handleRightSelect = useCallback(
    (rightPairId: string) => {
      if (!selectedLeft || feedback.type !== 'idle') return;

      const isCorrect = selectedLeft === rightPairId;

      if (isCorrect) {
        playSound('correct');
        setStreak((prev) => prev + 1);
        setFeedback({ type: 'correct', pairId: selectedLeft });
        onMatchResult?.(selectedLeft, true);

        // Start fade-out after brief green highlight
        setTimeout(() => {
          setFadingOut((prev) => new Set(prev).add(selectedLeft));
        }, 400);

        // Remove from view after fade-out
        setTimeout(() => {
          const newMatched = new Set(matchedPairs).add(selectedLeft);
          setMatchedPairs(newMatched);
          setFadingOut((prev) => {
            const next = new Set(prev);
            next.delete(selectedLeft);
            return next;
          });
          setSelectedLeft(null);
          setFeedback({ type: 'idle' });

          // Check completion
          if (newMatched.size === pairs.length) {
            onComplete({
              correct: pairs.length - wrongPairs.length,
              total: pairs.length,
              wrongPairIds: wrongPairs,
            });
          }
        }, 800);
      } else {
        playSound('incorrect');
        setStreak(0);
        setFeedback({ type: 'incorrect', pairId: selectedLeft });
        onMatchResult?.(selectedLeft, false);

        if (!wrongPairs.includes(selectedLeft)) {
          setWrongPairs((prev) => [...prev, selectedLeft]);
        }

        setTimeout(() => {
          setSelectedLeft(null);
          setFeedback({ type: 'idle' });
        }, 600);
      }
    },
    [selectedLeft, feedback.type, matchedPairs, pairs.length, wrongPairs, onMatchResult, onComplete]
  );

  // Detect if text is Japanese (kana/kanji) for font styling
  const isJapanese = (text: string) =>
    /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]/.test(text);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex gap-3">
        {/* Left column */}
        <div className="flex flex-1 flex-col gap-2.5">
          <AnimatePresence>
            {pairs.map((pair) => {
              if (matchedPairs.has(pair.id)) return null;

              const isSelected = selectedLeft === pair.id;
              const isFading = fadingOut.has(pair.id);
              const isCorrectFeedback =
                feedback.type === 'correct' && feedback.pairId === pair.id;
              const isIncorrectFeedback =
                feedback.type === 'incorrect' && feedback.pairId === pair.id;

              return (
                <motion.button
                  key={`left-${pair.id}`}
                  layout
                  initial={{ opacity: 1, scale: 1 }}
                  animate={
                    isFading
                      ? { opacity: 0, scale: 0.95 }
                      : isCorrectFeedback
                        ? { scale: [1, 1.04, 1] }
                        : isIncorrectFeedback
                          ? { x: [0, -8, 8, -6, 6, -3, 3, 0] }
                          : { opacity: 1, scale: 1, x: 0 }
                  }
                  exit={{ opacity: 0, scale: 0.9 }}
                  transition={
                    isFading
                      ? { duration: 0.4 }
                      : isIncorrectFeedback
                        ? { duration: 0.4 }
                        : { duration: 0.3 }
                  }
                  onClick={() => handleLeftSelect(pair.id)}
                  disabled={isFading || feedback.type !== 'idle'}
                  className={cn(
                    'flex h-[52px] items-center justify-center rounded-xl border-2 px-3 text-center font-medium transition-colors disabled:cursor-default',
                    isJapanese(pair.left) ? 'font-jp text-lg' : 'text-sm',
                    isCorrectFeedback
                      ? 'border-hk-success bg-hk-success/10 text-hk-success'
                      : isIncorrectFeedback
                        ? 'border-hk-error bg-hk-error/10 text-hk-error'
                        : isSelected
                          ? 'border-primary bg-primary/5 text-primary'
                          : 'border-border bg-card hover:bg-accent'
                  )}
                >
                  {pair.left}
                </motion.button>
              );
            })}
          </AnimatePresence>
        </div>

        {/* Right column */}
        <div className="flex flex-1 flex-col gap-2.5">
          <AnimatePresence>
            {shuffledRight.map((item) => {
              if (matchedPairs.has(item.pairId)) return null;

              const isFading = fadingOut.has(item.pairId);
              const isCorrectFeedback =
                feedback.type === 'correct' && feedback.pairId === item.pairId;
              return (
                <motion.button
                  key={`right-${item.pairId}`}
                  layout
                  initial={{ opacity: 1, scale: 1 }}
                  animate={
                    isFading
                      ? { opacity: 0, scale: 0.95 }
                      : isCorrectFeedback
                        ? { scale: [1, 1.04, 1] }
                        : { opacity: 1, scale: 1 }
                  }
                  exit={{ opacity: 0, scale: 0.9 }}
                  transition={isFading ? { duration: 0.4 } : { duration: 0.3 }}
                  onClick={() => handleRightSelect(item.pairId)}
                  disabled={!selectedLeft || isFading || feedback.type !== 'idle'}
                  className={cn(
                    'flex h-[52px] items-center justify-center rounded-xl border-2 px-3 text-center font-medium transition-colors disabled:cursor-default',
                    isJapanese(item.text) ? 'font-jp text-lg' : 'text-sm',
                    isCorrectFeedback
                      ? 'border-hk-success bg-hk-success/10 text-hk-success'
                      : 'border-border bg-card',
                    selectedLeft && !isFading && feedback.type === 'idle'
                      ? 'hover:bg-accent'
                      : ''
                  )}
                >
                  {item.text}
                </motion.button>
              );
            })}
          </AnimatePresence>
        </div>
      </div>

      {/* Progress indicator */}
      <div className="text-muted-foreground flex items-center justify-center gap-2 text-center text-sm">
        <span>{matchedPairs.size}/{pairs.length} 매칭 완료</span>
        <AnimatePresence>
          {streak >= 3 && (
            <motion.span
              initial={{ scale: 0, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0, opacity: 0 }}
              className="flex items-center gap-1 text-orange-500"
            >
              <Flame className="size-3.5" />
              <span className="text-xs font-bold">{streak}연속!</span>
            </motion.span>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}

export type { MatchingPair, MatchingPairQuizProps };
