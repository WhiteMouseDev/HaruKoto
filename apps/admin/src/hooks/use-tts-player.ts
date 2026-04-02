'use client';

import { useEffect, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useTranslations } from 'next-intl';
import { toast } from 'sonner';

import {
  fetchTtsAudio,
  regenerateTts,
  type TtsAudioMapResponse,
} from '@/lib/api/admin-content';
import { type ContentType } from '@/lib/tts-fields';

export function useTtsPlayer(contentType: ContentType, itemId: string) {
  const t = useTranslations('tts');
  const queryClient = useQueryClient();
  const audioRef = useRef<HTMLAudioElement | null>(null);

  const [playingField, setPlayingField] = useState<string | null>(null);
  const [confirmField, setConfirmField] = useState<string | null>(null);

  // Cleanup audio on unmount
  useEffect(() => {
    return () => {
      if (audioRef.current) {
        audioRef.current.pause();
        audioRef.current = null;
      }
    };
  }, []);

  const ttsQuery = useQuery<TtsAudioMapResponse>({
    queryKey: ['admin-tts', contentType, itemId],
    queryFn: () => fetchTtsAudio(contentType, itemId),
    staleTime: 60_000,
  });

  const audios = ttsQuery.data?.audios ?? {};

  function handlePlayPause(field: string) {
    const url = audios[field]?.audioUrl;
    if (!url) return;

    if (playingField === field) {
      // Same row — pause
      audioRef.current?.pause();
      setPlayingField(null);
    } else {
      // Different row or nothing playing — stop current, play new
      audioRef.current?.pause();
      if (!audioRef.current || audioRef.current.src !== url) {
        audioRef.current = new Audio(url);
        audioRef.current.addEventListener('ended', () => setPlayingField(null));
      } else {
        audioRef.current.currentTime = 0;
      }
      void audioRef.current.play();
      setPlayingField(field);
    }
  }

  const regenerateMutation = useMutation({
    mutationFn: (field: string) => regenerateTts(contentType, itemId, field),
    onSuccess: (newData, field) => {
      void queryClient.invalidateQueries({
        queryKey: ['admin-tts', contentType, itemId],
      });

      // Auto-play new audio on the field that was just regenerated
      if (newData.audioUrl) {
        audioRef.current?.pause();
        audioRef.current = new Audio(newData.audioUrl);
        audioRef.current.addEventListener('ended', () => setPlayingField(null));
        void audioRef.current.play();
        setPlayingField(field);
      }

      setConfirmField(null);
      toast.success(t('regenerateSuccess'));
    },
    onError: () => {
      toast.error(t('regenerateError'));
      setConfirmField(null);
    },
  });

  return {
    audios,
    isLoading: ttsQuery.isLoading,
    playingField,
    confirmField,
    setConfirmField,
    handlePlayPause,
    regenerateMutation,
  };
}
