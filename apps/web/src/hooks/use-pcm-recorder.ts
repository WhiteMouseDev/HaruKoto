'use client';

import { useState, useRef, useCallback, useEffect } from 'react';

type PcmRecorderOptions = {
  /** Called with base64 PCM chunks ready for WebSocket */
  onPcmChunk: (base64: string) => void;
};

type PcmRecorderReturn = {
  isRecording: boolean;
  analyserNode: AnalyserNode | null;
  start: () => Promise<void>;
  stop: () => void;
  setMuted: (muted: boolean) => void;
};

export function usePcmRecorder({ onPcmChunk }: PcmRecorderOptions): PcmRecorderReturn {
  const [isRecording, setIsRecording] = useState(false);
  const [analyserNode, setAnalyserNode] = useState<AnalyserNode | null>(null);

  const audioContextRef = useRef<AudioContext | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const workletNodeRef = useRef<AudioWorkletNode | null>(null);
  const sourceRef = useRef<MediaStreamAudioSourceNode | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const onPcmChunkRef = useRef(onPcmChunk);
  const mutedRef = useRef(false);

  onPcmChunkRef.current = onPcmChunk;

  const start = useCallback(async () => {
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: {
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
      },
    });
    streamRef.current = stream;

    const ctx = new AudioContext({ sampleRate: 48000 });
    audioContextRef.current = ctx;

    await ctx.audioWorklet.addModule('/pcm-processor.js');

    const source = ctx.createMediaStreamSource(stream);
    sourceRef.current = source;

    const analyser = ctx.createAnalyser();
    analyser.fftSize = 256;
    analyserRef.current = analyser;
    setAnalyserNode(analyser);

    source.connect(analyser);

    const worklet = new AudioWorkletNode(ctx, 'pcm-processor');
    workletNodeRef.current = worklet;

    worklet.port.onmessage = (e: MessageEvent<ArrayBuffer>) => {
      if (mutedRef.current) return;

      const int16 = new Int16Array(e.data);
      const bytes = new Uint8Array(int16.buffer);

      // Convert to base64
      let binary = '';
      for (let i = 0; i < bytes.length; i++) {
        binary += String.fromCharCode(bytes[i]);
      }
      const base64 = btoa(binary);
      onPcmChunkRef.current(base64);
    };

    source.connect(worklet);
    worklet.connect(ctx.destination); // needed for worklet to process

    setIsRecording(true);
  }, []);

  const stop = useCallback(() => {
    workletNodeRef.current?.disconnect();
    workletNodeRef.current = null;

    sourceRef.current?.disconnect();
    sourceRef.current = null;

    analyserRef.current = null;
    setAnalyserNode(null);

    streamRef.current?.getTracks().forEach((t) => t.stop());
    streamRef.current = null;

    if (audioContextRef.current?.state !== 'closed') {
      audioContextRef.current?.close();
    }
    audioContextRef.current = null;

    setIsRecording(false);
  }, []);

  const setMuted = useCallback((muted: boolean) => {
    mutedRef.current = muted;
    // Also mute the actual media tracks for privacy
    streamRef.current?.getAudioTracks().forEach((t) => {
      t.enabled = !muted;
    });
  }, []);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      workletNodeRef.current?.disconnect();
      sourceRef.current?.disconnect();
      streamRef.current?.getTracks().forEach((t) => t.stop());
      if (audioContextRef.current?.state !== 'closed') {
        audioContextRef.current?.close();
      }
    };
  }, []);

  return { isRecording, analyserNode, start, stop, setMuted };
}
