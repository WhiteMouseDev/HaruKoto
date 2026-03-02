'use client';

import { useState, useRef, useCallback, useEffect } from 'react';

type UseAudioPlayerReturn = {
  isPlaying: boolean;
  isLoading: boolean;
  duration: number;
  currentTime: number;
  play: (url: string) => void;
  playBlob: (blob: Blob) => void;
  pause: () => void;
  stop: () => void;
  setSpeed: (speed: number) => void;
};

export function useAudioPlayer(): UseAudioPlayerReturn {
  const [isPlaying, setIsPlaying] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [duration, setDuration] = useState(0);
  const [currentTime, setCurrentTime] = useState(0);

  const audioRef = useRef<HTMLAudioElement | null>(null);
  const objectUrlRef = useRef<string | null>(null);
  const animFrameRef = useRef<number | null>(null);

  const cleanupAudio = useCallback(() => {
    if (animFrameRef.current) {
      cancelAnimationFrame(animFrameRef.current);
      animFrameRef.current = null;
    }
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current.removeAttribute('src');
      audioRef.current.load();
      audioRef.current = null;
    }
    if (objectUrlRef.current) {
      URL.revokeObjectURL(objectUrlRef.current);
      objectUrlRef.current = null;
    }
    setIsPlaying(false);
    setCurrentTime(0);
    setDuration(0);
  }, []);

  useEffect(() => {
    return cleanupAudio;
  }, [cleanupAudio]);

  const trackTime = useCallback(() => {
    const audio = audioRef.current;
    if (!audio) return;
    setCurrentTime(audio.currentTime);
    if (!audio.paused) {
      animFrameRef.current = requestAnimationFrame(trackTime);
    }
  }, []);

  const playSource = useCallback(
    (src: string) => {
      cleanupAudio();
      setIsLoading(true);

      const audio = new Audio(src);
      audioRef.current = audio;

      audio.onloadedmetadata = () => {
        setDuration(audio.duration);
        setIsLoading(false);
      };

      audio.onplay = () => {
        setIsPlaying(true);
        animFrameRef.current = requestAnimationFrame(trackTime);
      };

      audio.onpause = () => {
        setIsPlaying(false);
      };

      audio.onended = () => {
        setIsPlaying(false);
        setCurrentTime(0);
      };

      audio.onerror = () => {
        setIsLoading(false);
        setIsPlaying(false);
      };

      audio.play().catch(() => {
        setIsLoading(false);
        setIsPlaying(false);
      });
    },
    [cleanupAudio, trackTime],
  );

  const play = useCallback(
    (url: string) => {
      playSource(url);
    },
    [playSource],
  );

  const playBlob = useCallback(
    (blob: Blob) => {
      const url = URL.createObjectURL(blob);
      playSource(url);
      // Set AFTER playSource — playSource calls cleanupAudio() which
      // revokes objectUrlRef, so we must set it after cleanup runs.
      objectUrlRef.current = url;
    },
    [playSource],
  );

  const pause = useCallback(() => {
    audioRef.current?.pause();
  }, []);

  const stop = useCallback(() => {
    cleanupAudio();
  }, [cleanupAudio]);

  const setSpeed = useCallback((speed: number) => {
    if (audioRef.current) {
      audioRef.current.playbackRate = speed;
    }
  }, []);

  return {
    isPlaying,
    isLoading,
    duration,
    currentTime,
    play,
    playBlob,
    pause,
    stop,
    setSpeed,
  };
}
