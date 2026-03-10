import { useState, useCallback } from 'react';
import { useAudioPlayer } from '@/hooks/use-audio-player';

// Client-side cache: vocabId → audioUrl
const audioUrlCache = new Map<string, string>();

export function useVocabTTS() {
  const { isPlaying, isLoading: playerLoading, play, pause } = useAudioPlayer();
  const [generating, setGenerating] = useState(false);

  const playVocab = useCallback(
    async (vocabId: string) => {
      if (isPlaying) {
        pause();
        return;
      }

      // Check client cache first
      const cached = audioUrlCache.get(vocabId);
      if (cached) {
        play(cached);
        return;
      }

      // Fetch from API (will return cached GCS URL or generate new)
      setGenerating(true);
      try {
        const res = await fetch(`/api/v1/vocab/tts?id=${vocabId}`);
        if (!res.ok) return;
        const data = await res.json();
        if (data.audioUrl) {
          audioUrlCache.set(vocabId, data.audioUrl);
          play(data.audioUrl);
        }
      } catch {
        // silently fail
      } finally {
        setGenerating(false);
      }
    },
    [isPlaying, pause, play]
  );

  return {
    playVocab,
    isPlaying,
    isLoading: playerLoading || generating,
  };
}
