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

const COOLDOWN_STORAGE_KEY = 'harukoto_admin_tts_cooldown';
const COOLDOWN_SECONDS = 600;

function getCooldownKey(contentType: string, itemId: string): string {
  return `${contentType}:${itemId}`;
}

function readCooldownSeconds(contentType: string, itemId: string): number {
  try {
    const raw = localStorage.getItem(COOLDOWN_STORAGE_KEY);
    if (!raw) return 0;
    const map = JSON.parse(raw) as Record<string, number>;
    const expiresAt = map[getCooldownKey(contentType, itemId)] ?? 0;
    const remaining = Math.floor((expiresAt - Date.now()) / 1000);
    return remaining > 0 ? remaining : 0;
  } catch {
    return 0;
  }
}

function writeCooldown(contentType: string, itemId: string): void {
  try {
    const raw = localStorage.getItem(COOLDOWN_STORAGE_KEY);
    const map: Record<string, number> = raw
      ? (JSON.parse(raw) as Record<string, number>)
      : {};
    map[getCooldownKey(contentType, itemId)] = Date.now() + COOLDOWN_SECONDS * 1000;
    localStorage.setItem(COOLDOWN_STORAGE_KEY, JSON.stringify(map));
  } catch {
    // localStorage may be unavailable; ignore
  }
}

export function useTtsPlayer(contentType: ContentType, itemId: string) {
  const queryClient = useQueryClient();
  const audioRef = useRef<HTMLAudioElement | null>(null);

  const [isPlaying, setIsPlaying] = useState(false);
  const [selectedField, setSelectedField] = useState<string>(
    TTS_FIELDS[contentType].default,
  );
  const [confirmOpen, setConfirmOpen] = useState(false);
  // Lazy initialization from localStorage to avoid setState-in-effect lint error
  const [remainingSeconds, setRemainingSeconds] = useState<number>(() =>
    readCooldownSeconds(contentType, itemId),
  );

  // Countdown tick
  useEffect(() => {
    if (remainingSeconds <= 0) return;
    const interval = setInterval(() => {
      setRemainingSeconds((prev) => {
        if (prev <= 1) {
          clearInterval(interval);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(interval);
  }, [remainingSeconds]);

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

      writeCooldown(contentType, itemId);
      setRemainingSeconds(COOLDOWN_SECONDS);
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
    remainingSeconds,
    selectedField,
    setSelectedField,
    confirmOpen,
    setConfirmOpen,
    handlePlayPause,
    regenerateMutation,
    cooldownMinutes: Math.ceil(remainingSeconds / 60),
  };
}
