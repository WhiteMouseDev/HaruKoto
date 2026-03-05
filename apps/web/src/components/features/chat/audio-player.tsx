'use client';

import { useRef, useCallback, useState } from 'react';
import { motion } from 'framer-motion';
import { Volume2, Pause, Loader2, Turtle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useAudioPlayer } from '@/hooks/use-audio-player';
import { cn } from '@/lib/utils';

type AudioPlayerProps = {
  text: string;
  className?: string;
};

export function AudioPlayer({ text, className }: AudioPlayerProps) {
  const { isPlaying, isLoading, playBlob, pause, stop, setSpeed } = useAudioPlayer();
  const [slow, setSlow] = useState(false);
  const cacheRef = useRef<Map<string, Blob>>(new Map());

  const fetchTTS = useCallback(
    async (speed: number): Promise<Blob> => {
      const cacheKey = `${text}:${speed}`;
      const cached = cacheRef.current.get(cacheKey);
      if (cached) return cached;

      const res = await fetch('/api/v1/chat/tts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text, speed }),
      });

      if (!res.ok) throw new Error('TTS 요청 실패');

      const blob = await res.blob();
      cacheRef.current.set(cacheKey, blob);
      return blob;
    },
    [text],
  );

  const handlePlayPause = useCallback(async () => {
    if (isPlaying) {
      pause();
      return;
    }

    const speed = slow ? 0.8 : 1.0;
    try {
      const blob = await fetchTTS(speed);
      playBlob(blob);
      setSpeed(speed);
    } catch {
      // silently fail
    }
  }, [isPlaying, slow, pause, fetchTTS, playBlob, setSpeed]);

  const handleToggleSpeed = useCallback(() => {
    const next = !slow;
    setSlow(next);
    if (isPlaying) {
      stop();
    }
  }, [slow, isPlaying, stop]);

  return (
    <div className={cn('mt-1.5 flex items-center gap-1', className)}>
      <Button
        variant="ghost"
        size="icon-xs"
        onClick={handlePlayPause}
        disabled={isLoading}
        className="text-muted-foreground hover:text-primary"
      >
        {isLoading ? (
          <Loader2 className="size-3 animate-spin" />
        ) : isPlaying ? (
          <Pause className="size-3" />
        ) : (
          <Volume2 className="size-3" />
        )}
      </Button>

      <motion.div whileTap={{ scale: 0.9 }}>
        <Button
          variant="ghost"
          size="icon-xs"
          onClick={handleToggleSpeed}
          className={cn(
            'text-muted-foreground',
            slow && 'text-primary bg-primary/10',
          )}
          title={slow ? '느리게 재생' : '일반 속도'}
        >
          <Turtle className="size-3" />
        </Button>
      </motion.div>

      {slow && (
        <span className="text-muted-foreground text-[10px]">느리게</span>
      )}
    </div>
  );
}
