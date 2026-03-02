'use client';

import { useState, useRef, useCallback, useEffect } from 'react';

type PcmPlayerReturn = {
  isPlaying: boolean;
  analyserNode: AnalyserNode | null;
  /** Call during user gesture (e.g. button click) to pre-create AudioContext */
  init: () => void;
  enqueue: (base64: string) => void;
  interrupt: () => void;
  stop: () => void;
};

/**
 * Plays PCM 24kHz Int16 audio chunks from Gemini Live API
 * with gapless scheduling via AudioBufferSourceNode.
 */
export function usePcmPlayer(): PcmPlayerReturn {
  const [isPlaying, setIsPlaying] = useState(false);
  const [analyserNode, setAnalyserNode] = useState<AnalyserNode | null>(null);

  const ctxRef = useRef<AudioContext | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const nextStartTimeRef = useRef(0);
  const activeSourcesRef = useRef<Set<AudioBufferSourceNode>>(new Set());
  const playingCountRef = useRef(0);

  const getContext = useCallback(() => {
    if (!ctxRef.current || ctxRef.current.state === 'closed') {
      const ctx = new AudioContext({ sampleRate: 24000 });
      ctxRef.current = ctx;

      const analyser = ctx.createAnalyser();
      analyser.fftSize = 256;
      analyser.connect(ctx.destination);
      analyserRef.current = analyser;
      setAnalyserNode(analyser);
    }

    // Resume if suspended (browser autoplay policy)
    const ctx = ctxRef.current;
    if (ctx.state === 'suspended') {
      ctx.resume();
    }

    return ctx;
  }, []);

  /** Pre-initialize AudioContext during user gesture to avoid autoplay block */
  const init = useCallback(() => {
    getContext();
  }, [getContext]);

  const enqueue = useCallback(
    (base64: string) => {
      const ctx = getContext();

      // base64 → Int16 → Float32
      const binaryStr = atob(base64);
      const bytes = new Uint8Array(binaryStr.length);
      for (let i = 0; i < binaryStr.length; i++) {
        bytes[i] = binaryStr.charCodeAt(i);
      }
      const int16 = new Int16Array(bytes.buffer);
      const float32 = new Float32Array(int16.length);
      for (let i = 0; i < int16.length; i++) {
        float32[i] = int16[i] / (int16[i] < 0 ? 0x8000 : 0x7fff);
      }

      const buffer = ctx.createBuffer(1, float32.length, 24000);
      buffer.getChannelData(0).set(float32);

      const source = ctx.createBufferSource();
      source.buffer = buffer;
      source.connect(analyserRef.current || ctx.destination);
      activeSourcesRef.current.add(source);

      // Schedule gapless playback
      const now = ctx.currentTime;
      const startAt = Math.max(now, nextStartTimeRef.current);
      nextStartTimeRef.current = startAt + buffer.duration;

      playingCountRef.current++;
      setIsPlaying(true);

      source.onended = () => {
        activeSourcesRef.current.delete(source);
        playingCountRef.current--;
        if (playingCountRef.current <= 0) {
          playingCountRef.current = 0;
          setIsPlaying(false);
        }
      };

      source.start(startAt);
    },
    [getContext]
  );

  const interrupt = useCallback(() => {
    // Barge-in: immediately stop all scheduled audio
    for (const source of activeSourcesRef.current) {
      try {
        source.stop();
      } catch {
        // already stopped
      }
    }
    activeSourcesRef.current.clear();
    nextStartTimeRef.current = 0;
    playingCountRef.current = 0;
    setIsPlaying(false);
  }, []);

  const stop = useCallback(() => {
    interrupt();
    if (ctxRef.current && ctxRef.current.state !== 'closed') {
      ctxRef.current.close();
    }
    ctxRef.current = null;
    analyserRef.current = null;
    setAnalyserNode(null);
  }, [interrupt]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      for (const source of activeSourcesRef.current) {
        try {
          source.stop();
        } catch {
          // already stopped
        }
      }
      if (ctxRef.current && ctxRef.current.state !== 'closed') {
        ctxRef.current.close();
      }
    };
  }, []);

  return { isPlaying, analyserNode, init, enqueue, interrupt, stop };
}
