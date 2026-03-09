'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import { Volume2, Loader2, Pause, X } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { useAudioPlayer } from '@/hooks/use-audio-player';

type WordSource = 'QUIZ' | 'CONVERSATION' | 'MANUAL';

type WordbookEntryCardProps = {
  id: string;
  word: string;
  reading: string;
  meaningKo: string;
  source: WordSource;
  createdAt: string;
  onDelete: (id: string) => void;
};

const SOURCE_CONFIG: Record<WordSource, { label: string; className: string }> = {
  QUIZ: { label: '퀴즈', className: 'bg-hk-blue/10 text-hk-blue' },
  CONVERSATION: { label: '회화', className: 'bg-hk-success/10 text-hk-success' },
  MANUAL: { label: '직접추가', className: 'bg-secondary text-muted-foreground' },
};

export function WordbookEntryCard({
  id,
  word,
  reading,
  meaningKo,
  source,
  onDelete,
}: WordbookEntryCardProps) {
  const [confirming, setConfirming] = useState(false);
  const { isPlaying, isLoading, playBlob, pause } = useAudioPlayer();
  const sourceConfig = SOURCE_CONFIG[source];

  async function handlePlay() {
    if (isPlaying) {
      pause();
      return;
    }
    try {
      const res = await fetch('/api/v1/chat/tts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: word }),
      });
      if (!res.ok) return;
      const blob = await res.blob();
      playBlob(blob);
    } catch {
      // silently fail
    }
  }

  function handleDelete() {
    if (!confirming) {
      setConfirming(true);
      return;
    }
    onDelete(id);
  }

  return (
    <motion.div
      layout
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, x: -100 }}
      transition={{ duration: 0.2 }}
    >
      <Card>
        <CardContent className="flex items-center gap-3 px-4 py-3">
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2">
              <button
                onClick={handlePlay}
                disabled={isLoading}
                className="text-muted-foreground hover:text-primary transition-colors shrink-0"
                title="발음 듣기"
              >
                {isLoading ? (
                  <Loader2 className="size-4 animate-spin" />
                ) : isPlaying ? (
                  <Pause className="size-4" />
                ) : (
                  <Volume2 className="size-4" />
                )}
              </button>
              <span className="font-jp text-lg font-bold truncate">{word}</span>
              <span className="font-jp text-muted-foreground text-sm shrink-0">
                {reading}
              </span>
            </div>
            <p className="text-sm text-muted-foreground truncate">{meaningKo}</p>
          </div>

          <div className="flex items-center gap-2 shrink-0">
            <Badge variant="ghost" className={sourceConfig.className}>
              {sourceConfig.label}
            </Badge>

            {confirming ? (
              <div className="flex items-center gap-1">
                <Button
                  variant="destructive"
                  size="sm"
                  className="h-7 px-2 text-xs"
                  onClick={handleDelete}
                >
                  삭제
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  className="h-7 px-2 text-xs"
                  onClick={() => setConfirming(false)}
                >
                  취소
                </Button>
              </div>
            ) : (
              <button
                className="text-muted-foreground hover:text-foreground transition-colors p-1"
                onClick={handleDelete}
              >
                <X className="size-4" />
              </button>
            )}
          </div>
        </CardContent>
      </Card>
    </motion.div>
  );
}
