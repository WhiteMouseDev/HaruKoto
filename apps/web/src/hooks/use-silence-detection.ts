'use client';

import { useRef, useEffect } from 'react';

type UseSilenceDetectionOptions = {
  analyserNode: AnalyserNode | null;
  enabled: boolean;
  silenceThreshold?: number;
  silenceDurationMs?: number;
  minRecordingMs?: number;
  onSilenceDetected: () => void;
};

export function useSilenceDetection({
  analyserNode,
  enabled,
  silenceThreshold = 15,
  silenceDurationMs = 1500,
  minRecordingMs = 800,
  onSilenceDetected,
}: UseSilenceDetectionOptions) {
  const silenceStartRef = useRef<number | null>(null);
  const recordingStartRef = useRef<number | null>(null);
  const animFrameRef = useRef<number | null>(null);
  const callbackRef = useRef(onSilenceDetected);

  callbackRef.current = onSilenceDetected;

  useEffect(() => {
    if (!enabled || !analyserNode) {
      silenceStartRef.current = null;
      recordingStartRef.current = null;
      if (animFrameRef.current) {
        cancelAnimationFrame(animFrameRef.current);
        animFrameRef.current = null;
      }
      return;
    }

    recordingStartRef.current = Date.now();
    silenceStartRef.current = null;
    const dataArray = new Uint8Array(analyserNode.frequencyBinCount);

    function detect() {
      analyserNode!.getByteFrequencyData(dataArray);

      let sum = 0;
      for (let i = 0; i < dataArray.length; i++) {
        sum += dataArray[i];
      }
      const average = sum / dataArray.length;

      const now = Date.now();
      const elapsed = now - (recordingStartRef.current ?? now);

      if (average < silenceThreshold) {
        if (silenceStartRef.current === null) {
          silenceStartRef.current = now;
        }
        const silenceDuration = now - silenceStartRef.current;
        if (silenceDuration >= silenceDurationMs && elapsed >= minRecordingMs) {
          callbackRef.current();
          return;
        }
      } else {
        silenceStartRef.current = null;
      }

      animFrameRef.current = requestAnimationFrame(detect);
    }

    animFrameRef.current = requestAnimationFrame(detect);

    return () => {
      if (animFrameRef.current) {
        cancelAnimationFrame(animFrameRef.current);
        animFrameRef.current = null;
      }
    };
  }, [analyserNode, enabled, silenceThreshold, silenceDurationMs, minRecordingMs]);
}
