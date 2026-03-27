'use client';

import { useEffect, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import {
  fetchTtsAudio,
  regenerateTts,
  type TtsAudioResponse,
} from '@/lib/api/admin-content';
import { TTS_FIELDS, type ContentType } from '@/lib/tts-fields';

export function useTtsPlayer(contentType: ContentType, itemId: string) {
  const queryClient = useQueryClient();
  const audioRef = useRef<HTMLAudioElement | null>(null);

  const [isPlaying, setIsPlaying] = useState(false);
  const [selectedField, setSelectedField] = useState<string>(
    TTS_FIELDS[contentType].default,
  );
  const [confirmOpen, setConfirmOpen] = useState(false);

  // Cleanup audio on unmount
  useEffect(() => {
    return () => {
      if (audioRef.current) {
        audioRef.current.pause();
        audioRef.current = null;
      }
    };
  }, []);

  const ttsQuery = useQuery<TtsAudioResponse>({
    queryKey: ['admin-tts', contentType, itemId],
    queryFn: () => fetchTtsAudio(contentType, itemId),
    staleTime: 60_000,
  });

  const data = ttsQuery.data;

  function handlePlayPause() {
    const url = data?.audioUrl;
    if (!url) return;

    if (!audioRef.current) {
      audioRef.current = new Audio(url);
      audioRef.current.addEventListener('ended', () => {
        setIsPlaying(false);
      });
    }

    if (isPlaying) {
      audioRef.current.pause();
      setIsPlaying(false);
    } else {
      void audioRef.current.play();
      setIsPlaying(true);
    }
  }

  const regenerateMutation = useMutation({
    mutationFn: () => regenerateTts(contentType, itemId, selectedField),
    onSuccess: (newData) => {
      void queryClient.invalidateQueries({
        queryKey: ['admin-tts', contentType, itemId],
      });

      setConfirmOpen(false);

      // Auto-play new audio
      if (newData.audioUrl) {
        if (audioRef.current) {
          audioRef.current.pause();
        }
        audioRef.current = new Audio(newData.audioUrl);
        audioRef.current.addEventListener('ended', () => {
          setIsPlaying(false);
        });
        void audioRef.current.play();
        setIsPlaying(true);
      }

      toast.success('TTSを再生成しました');
    },
    onError: (err: Error) => {
      toast.error(err.message || '再生成に失敗しました。もう一度お試しください。');
      setConfirmOpen(false);
    },
  });

  return {
    audioUrl: data?.audioUrl ?? null,
    isLoading: ttsQuery.isLoading,
    isPlaying,
    selectedField,
    setSelectedField,
    confirmOpen,
    setConfirmOpen,
    handlePlayPause,
    regenerateMutation,
  };
}
