'use client';

import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { CheckCircle2, Circle, ChevronDown } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent } from '@/components/ui/card';
import type { LearnedWord } from '@/hooks/use-learned-words';

type LearnedWordCardProps = LearnedWord;

export function LearnedWordCard({
  word,
  reading,
  meaningKo,
  jlptLevel,
  exampleSentence,
  exampleTranslation,
  correctCount,
  incorrectCount,
  mastered,
  lastReviewedAt,
}: LearnedWordCardProps) {
  const [expanded, setExpanded] = useState(false);
  const total = correctCount + incorrectCount;
  const accuracy = total > 0 ? Math.round((correctCount / total) * 100) : 0;

  const reviewDate = lastReviewedAt
    ? new Date(lastReviewedAt).toLocaleDateString('ko-KR', {
        month: 'short',
        day: 'numeric',
      })
    : null;

  return (
    <motion.div
      layout
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.2 }}
    >
      <Card
        className="cursor-pointer transition-colors"
        onClick={() => setExpanded((v) => !v)}
      >
        <CardContent className="flex flex-col gap-0 px-4 py-3">
          <div className="flex items-center gap-3">
            {mastered ? (
              <CheckCircle2 className="text-primary size-4 shrink-0" />
            ) : (
              <Circle className="text-muted-foreground size-4 shrink-0" />
            )}
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2">
                <span className="font-jp truncate text-lg font-bold">
                  {word}
                </span>
                <span className="font-jp text-muted-foreground shrink-0 text-sm">
                  {reading}
                </span>
              </div>
              <p className="text-muted-foreground truncate text-sm">
                {meaningKo}
              </p>
            </div>
            <div className="flex shrink-0 items-center gap-1.5">
              {mastered ? (
                <Badge variant="ghost" className="bg-primary/10 text-primary">
                  마스터
                </Badge>
              ) : (
                <Badge variant="ghost" className="bg-hk-blue/10 text-hk-blue">
                  학습중
                </Badge>
              )}
              <ChevronDown
                className={`text-muted-foreground size-4 transition-transform ${
                  expanded ? 'rotate-180' : ''
                }`}
              />
            </div>
          </div>

          <AnimatePresence>
            {expanded && (
              <motion.div
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 'auto', opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                transition={{ duration: 0.2 }}
                className="overflow-hidden"
              >
                <div className="mt-3 flex flex-col gap-2.5 border-t pt-3">
                  {/* Stats */}
                  <div className="grid grid-cols-3 gap-2">
                    <div className="bg-secondary flex flex-col items-center rounded-lg py-2">
                      <span className="text-xs text-muted-foreground">정답률</span>
                      <span className="text-sm font-bold">{accuracy}%</span>
                    </div>
                    <div className="bg-secondary flex flex-col items-center rounded-lg py-2">
                      <span className="text-xs text-muted-foreground">풀이</span>
                      <span className="text-sm font-bold">{total}회</span>
                    </div>
                    <div className="bg-secondary flex flex-col items-center rounded-lg py-2">
                      <span className="text-xs text-muted-foreground">최근</span>
                      <span className="text-sm font-bold">{reviewDate ?? '-'}</span>
                    </div>
                  </div>

                  {/* Example sentence */}
                  {exampleSentence && (
                    <div className="bg-secondary rounded-lg px-3 py-2">
                      <p className="font-jp text-sm">{exampleSentence}</p>
                      {exampleTranslation && (
                        <p className="text-muted-foreground mt-0.5 text-xs">
                          {exampleTranslation}
                        </p>
                      )}
                    </div>
                  )}

                  {/* Meta */}
                  <div className="flex items-center gap-2">
                    <Badge variant="outline" className="text-[10px]">
                      {jlptLevel}
                    </Badge>
                  </div>
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </CardContent>
      </Card>
    </motion.div>
  );
}
