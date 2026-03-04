'use client';

import { useRef, useEffect, useState } from 'react';
import { motion } from 'framer-motion';

type CallWaveformProps = {
  analyserNode: AnalyserNode | null;
  mode: 'idle' | 'speaking' | 'listening';
  avatarUrl?: string;
};

const RING_COUNT = 4;
const BASE_SCALE = [1.3, 1.55, 1.8, 2.05];
const BASE_OPACITY = [0.25, 0.18, 0.12, 0.06];

export function CallWaveform({ analyserNode, mode, avatarUrl }: CallWaveformProps) {
  const [amplitude, setAmplitude] = useState(0);
  const animFrameRef = useRef<number | null>(null);

  useEffect(() => {
    if (mode !== 'listening' || !analyserNode) {
      if (animFrameRef.current) {
        cancelAnimationFrame(animFrameRef.current);
        animFrameRef.current = null;
      }
      // Reset amplitude on next frame to avoid synchronous setState
      animFrameRef.current = requestAnimationFrame(() => {
        setAmplitude(0);
        animFrameRef.current = null;
      });
      return;
    }

    const dataArray = new Uint8Array(analyserNode.frequencyBinCount);

    function update() {
      analyserNode!.getByteFrequencyData(dataArray);
      let sum = 0;
      for (let i = 0; i < dataArray.length; i++) {
        sum += dataArray[i];
      }
      const avg = sum / dataArray.length / 255;
      setAmplitude(avg);
      animFrameRef.current = requestAnimationFrame(update);
    }

    animFrameRef.current = requestAnimationFrame(update);
    return () => {
      if (animFrameRef.current) {
        cancelAnimationFrame(animFrameRef.current);
        animFrameRef.current = null;
      }
    };
  }, [analyserNode, mode]);

  return (
    <div className="relative flex items-center justify-center">
      {/* Rings */}
      {Array.from({ length: RING_COUNT }).map((_, i) => {
        const dynamicScale = mode === 'listening'
          ? BASE_SCALE[i] + amplitude * 0.4
          : BASE_SCALE[i];

        return mode === 'speaking' ? (
          <motion.div
            key={i}
            className="absolute size-32 rounded-full border border-emerald-400/30"
            animate={{
              scale: [BASE_SCALE[i], BASE_SCALE[i] + 0.15, BASE_SCALE[i]],
              opacity: [BASE_OPACITY[i], BASE_OPACITY[i] + 0.08, BASE_OPACITY[i]],
            }}
            transition={{
              duration: 1.5,
              repeat: Infinity,
              delay: i * 0.3,
              ease: 'easeInOut',
            }}
          />
        ) : (
          <motion.div
            key={i}
            className="absolute size-32 rounded-full border border-emerald-400/30"
            animate={{
              scale: mode === 'idle' ? BASE_SCALE[i] : dynamicScale,
              opacity: mode === 'idle' ? BASE_OPACITY[i] * 0.5 : BASE_OPACITY[i],
            }}
            transition={{ duration: 0.15, ease: 'easeOut' }}
          />
        );
      })}

      {/* Avatar */}
      <div className="relative z-10 size-32 overflow-hidden rounded-full shadow-lg shadow-emerald-500/25">
        <img
          src={avatarUrl ?? '/images/haru-avatar.png'}
          alt="character"
          width={128}
          height={128}
          className="size-full object-cover"
        />
      </div>
    </div>
  );
}
