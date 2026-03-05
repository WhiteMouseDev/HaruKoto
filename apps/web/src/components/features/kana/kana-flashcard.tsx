'use client';

import { useState } from 'react';
import { motion, type PanInfo } from 'framer-motion';
import { ThumbsDown, ThumbsUp, RotateCw } from 'lucide-react';
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
    <div className="flex flex-col items-center gap-6">
      {/* Flashcard */}
      <motion.div
        aria-live="polite"
        aria-label={`플래시카드: ${character}`}
        drag="x"
        dragConstraints={{ left: 0, right: 0 }}
        dragElastic={0.3}
        onDragEnd={handleDragEnd}
        className="w-full max-w-[260px] cursor-grab active:cursor-grabbing"
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
          <div
            className="flex aspect-[4/5] flex-col items-center justify-center gap-4 rounded-3xl border bg-gradient-to-br from-background to-primary/5 shadow-lg"
            style={{ backfaceVisibility: 'hidden' }}
          >
            <div className="bg-primary/8 flex size-24 items-center justify-center rounded-2xl">
              <span className="font-jp text-primary text-6xl font-bold drop-shadow-sm">
                {character}
              </span>
            </div>
            <div className="flex items-center gap-1.5 text-muted-foreground">
              <RotateCw className="size-3.5" />
              <span className="text-xs font-medium">탭하여 뒤집기</span>
            </div>
          </div>

          {/* Back */}
          <div
            className="absolute inset-0 flex aspect-[4/5] flex-col items-center justify-center gap-5 rounded-3xl border bg-gradient-to-br from-primary/5 to-background shadow-lg"
            style={{
              backfaceVisibility: 'hidden',
              transform: 'rotateY(180deg)',
            }}
          >
            <div className="flex flex-col items-center gap-1">
              <span className="text-primary text-4xl font-extrabold">{romaji}</span>
              <span className="text-muted-foreground text-lg">
                {pronunciation}
              </span>
            </div>

            {exampleWord && (
              <div className="bg-secondary/80 flex flex-col items-center gap-0.5 rounded-xl px-5 py-3">
                <span className="font-jp text-lg font-semibold">
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

            <div className="flex items-center gap-1.5 text-muted-foreground">
              <RotateCw className="size-3.5" />
              <span className="text-xs font-medium">탭하여 뒤집기</span>
            </div>
          </div>
        </motion.div>
      </motion.div>

      {/* Action buttons */}
      <div className="flex w-full max-w-[260px] gap-3">
        <Button
          variant="outline"
          className="h-12 flex-1 gap-2 rounded-xl border-2 text-base font-semibold"
          onClick={onDontKnow}
          aria-label="모르겠다 - 다음 카드로"
        >
          <ThumbsDown className="size-4" />
          모르겠다
        </Button>
        <Button
          className="h-12 flex-1 gap-2 rounded-xl text-base font-semibold"
          onClick={onKnow}
          aria-label="알겠다 - 다음 카드로"
        >
          <ThumbsUp className="size-4" />
          알겠다
        </Button>
      </div>
    </div>
  );
}
