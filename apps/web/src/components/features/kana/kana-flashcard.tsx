'use client';

import { useState } from 'react';
import { motion, type PanInfo } from 'framer-motion';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';

type KanaFlashcardProps = {
  character: string;
  romaji: string;
  pronunciation: string;
  exampleWord: string | null;
  exampleReading: string | null;
  exampleMeaning: string | null;
  onKnow: () => void;
  onDontKnow: () => void;
};

const SWIPE_THRESHOLD = 80;

export function KanaFlashcard({
  character,
  romaji,
  pronunciation,
  exampleWord,
  exampleReading,
  exampleMeaning,
  onKnow,
  onDontKnow,
}: KanaFlashcardProps) {
  const [isFlipped, setIsFlipped] = useState(false);

  function handleDragEnd(_: MouseEvent | TouchEvent | PointerEvent, info: PanInfo) {
    if (info.offset.x > SWIPE_THRESHOLD) {
      onKnow();
    } else if (info.offset.x < -SWIPE_THRESHOLD) {
      onDontKnow();
    }
  }

  return (
    <div className="flex flex-col gap-4">
      {/* Flashcard */}
      <motion.div
        aria-live="polite"
        aria-label={`플래시카드: ${character}`}
        drag="x"
        dragConstraints={{ left: 0, right: 0 }}
        dragElastic={0.3}
        onDragEnd={handleDragEnd}
        className="cursor-grab active:cursor-grabbing"
        style={{ perspective: 1000 }}
      >
        <motion.div
          className="relative"
          animate={{ rotateY: isFlipped ? 180 : 0 }}
          transition={{ duration: 0.4, ease: 'easeInOut' }}
          style={{ transformStyle: 'preserve-3d' }}
          onClick={() => setIsFlipped((v) => !v)}
        >
          {/* Front */}
          <Card
            className="min-h-[300px]"
            style={{ backfaceVisibility: 'hidden' }}
          >
            <CardContent className="flex min-h-[300px] flex-col items-center justify-center gap-3 p-6">
              <span className="font-jp text-7xl font-bold">{character}</span>
              <span className="text-muted-foreground text-sm">
                탭하여 뒤집기
              </span>
            </CardContent>
          </Card>

          {/* Back */}
          <Card
            className="absolute inset-0 min-h-[300px]"
            style={{
              backfaceVisibility: 'hidden',
              transform: 'rotateY(180deg)',
            }}
          >
            <CardContent className="flex min-h-[300px] flex-col items-center justify-center gap-4 p-6">
              <span className="text-3xl font-bold">{romaji}</span>
              <span className="text-muted-foreground text-xl">
                {pronunciation}
              </span>
              {exampleWord && (
                <div className="bg-secondary mt-2 flex flex-col items-center gap-1 rounded-xl px-4 py-3">
                  <span className="font-jp text-lg font-medium">
                    {exampleWord}
                  </span>
                  {exampleReading && (
                    <span className="font-jp text-muted-foreground text-sm">
                      {exampleReading}
                    </span>
                  )}
                  {exampleMeaning && (
                    <span className="text-muted-foreground text-sm">
                      {exampleMeaning}
                    </span>
                  )}
                </div>
              )}
            </CardContent>
          </Card>
        </motion.div>
      </motion.div>

      {/* Action buttons */}
      <div className="flex gap-3">
        <Button
          variant="outline"
          className="flex-1 border-destructive/30 text-destructive hover:bg-destructive/10"
          onClick={onDontKnow}
          aria-label="모르겠다 - 다음 카드로"
        >
          모르겠다
        </Button>
        <Button
          className="flex-1"
          onClick={onKnow}
          aria-label="알겠다 - 다음 카드로"
        >
          알겠다
        </Button>
      </div>
    </div>
  );
}
