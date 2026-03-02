'use client';

import { useState, useRef, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Mic, Square, X, RotateCcw, Pencil, Send, Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useAudioRecorder } from '@/hooks/use-audio-recorder';

type VoiceInputProps = {
  onSend: (text: string) => void;
  disabled: boolean;
  onCancel: () => void;
};

type VoiceState = 'idle' | 'recording' | 'transcribing' | 'preview';

function formatDuration(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${s.toString().padStart(2, '0')}`;
}

function WaveformCanvas({ analyserNode }: { analyserNode: AnalyserNode | null }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const animRef = useRef<number | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || !analyserNode) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const bufferLength = analyserNode.frequencyBinCount;
    const dataArray = new Uint8Array(bufferLength);

    function draw() {
      if (!ctx || !canvas || !analyserNode) return;
      animRef.current = requestAnimationFrame(draw);

      analyserNode.getByteFrequencyData(dataArray);

      ctx.clearRect(0, 0, canvas.width, canvas.height);

      const barCount = 32;
      const barWidth = canvas.width / barCount;
      const step = Math.floor(bufferLength / barCount);

      for (let i = 0; i < barCount; i++) {
        const value = dataArray[i * step] ?? 0;
        const barHeight = (value / 255) * canvas.height * 0.8;
        const x = i * barWidth;
        const y = (canvas.height - barHeight) / 2;

        ctx.fillStyle = 'hsl(var(--primary))';
        ctx.roundRect(x + 1, y, barWidth - 2, barHeight, 2);
        ctx.fill();
      }
    }

    draw();

    return () => {
      if (animRef.current) {
        cancelAnimationFrame(animRef.current);
      }
    };
  }, [analyserNode]);

  return (
    <canvas
      ref={canvasRef}
      width={192}
      height={40}
      className="h-10 w-48"
    />
  );
}

export function VoiceInput({ onSend, disabled, onCancel }: VoiceInputProps) {
  const [state, setState] = useState<VoiceState>('idle');
  const [transcription, setTranscription] = useState('');
  const [isEditing, setIsEditing] = useState(false);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const {
    isRecording,
    duration,
    audioBlob,
    analyserNode,
    startRecording,
    stopRecording,
    cancelRecording,
    error,
  } = useAudioRecorder();

  const handleStartRecording = useCallback(async () => {
    setState('recording');
    await startRecording();
  }, [startRecording]);

  const handleStopRecording = useCallback(() => {
    stopRecording();
  }, [stopRecording]);

  const handleCancel = useCallback(() => {
    cancelRecording();
    setState('idle');
    onCancel();
  }, [cancelRecording, onCancel]);

  // When audioBlob is produced, trigger STT
  useEffect(() => {
    if (!audioBlob || state !== 'recording') return;

    setState('transcribing');

    const transcribe = async () => {
      try {
        const formData = new FormData();
        formData.append('audio', audioBlob, 'recording.webm');
        const res = await fetch('/api/v1/chat/voice/transcribe', {
          method: 'POST',
          body: formData,
        });
        if (!res.ok) throw new Error('STT 요청 실패');
        const data = await res.json();
        setTranscription(data.transcription);
        setState('preview');
      } catch {
        setState('idle');
        onCancel();
      }
    };

    transcribe();
  }, [audioBlob, state, onCancel]);

  // Handle recorder error
  useEffect(() => {
    if (error) {
      setState('idle');
    }
  }, [error]);

  const handleReRecord = useCallback(() => {
    setTranscription('');
    setIsEditing(false);
    handleStartRecording();
  }, [handleStartRecording]);

  const handleEdit = useCallback(() => {
    setIsEditing(true);
    setTimeout(() => textareaRef.current?.focus(), 0);
  }, []);

  const handleSend = useCallback(() => {
    const text = transcription.trim();
    if (!text) return;
    onSend(text);
    setTranscription('');
    setState('idle');
    setIsEditing(false);
  }, [transcription, onSend]);

  // Auto-start recording on mount if idle
  useEffect(() => {
    if (state === 'idle' && !error) {
      handleStartRecording();
    }
    // Only run on mount
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="border-t bg-background safe-area-bottom">
      <AnimatePresence mode="wait">
        {/* Error state */}
        {error && (
          <motion.div
            key="error"
            className="flex items-center gap-2 p-3"
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
          >
            <p className="text-hk-error flex-1 text-sm">{error}</p>
            <Button variant="ghost" size="sm" onClick={onCancel}>
              닫기
            </Button>
          </motion.div>
        )}

        {/* Recording state */}
        {state === 'recording' && !error && (
          <motion.div
            key="recording"
            className="flex items-center gap-3 p-3"
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
          >
            <motion.div
              animate={{ scale: [1, 1.2, 1] }}
              transition={{ repeat: Infinity, duration: 1.5 }}
            >
              <Mic className="text-hk-error size-5" />
            </motion.div>

            <WaveformCanvas analyserNode={analyserNode} />

            <span className="text-muted-foreground min-w-[3ch] text-sm tabular-nums">
              {formatDuration(duration)}
            </span>

            <div className="ml-auto flex items-center gap-1">
              <Button
                variant="ghost"
                size="icon-sm"
                onClick={handleStopRecording}
                className="text-primary"
              >
                <Square className="size-4" />
              </Button>
              <Button
                variant="ghost"
                size="icon-sm"
                onClick={handleCancel}
                className="text-muted-foreground"
              >
                <X className="size-4" />
              </Button>
            </div>
          </motion.div>
        )}

        {/* Transcribing state */}
        {state === 'transcribing' && (
          <motion.div
            key="transcribing"
            className="flex items-center justify-center gap-2 p-4"
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
          >
            <Loader2 className="text-primary size-4 animate-spin" />
            <span className="text-muted-foreground text-sm">변환 중...</span>
          </motion.div>
        )}

        {/* Preview state */}
        {state === 'preview' && (
          <motion.div
            key="preview"
            className="space-y-2 p-3"
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
          >
            {isEditing ? (
              <textarea
                ref={textareaRef}
                value={transcription}
                onChange={(e) => setTranscription(e.target.value)}
                className="font-jp border-input bg-secondary/50 w-full resize-none rounded-xl border px-3 py-2.5 text-sm outline-none focus:ring-2 focus:ring-primary/30"
                rows={2}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    handleSend();
                  }
                }}
              />
            ) : (
              <div className="bg-secondary/50 rounded-xl px-3 py-2.5">
                <p className="font-jp text-sm">{transcription}</p>
              </div>
            )}

            <div className="flex items-center gap-1.5">
              <Button
                variant="ghost"
                size="sm"
                onClick={handleReRecord}
                disabled={disabled}
                className="text-muted-foreground gap-1.5"
              >
                <RotateCcw className="size-3.5" />
                다시
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={isEditing ? () => setIsEditing(false) : handleEdit}
                className="text-muted-foreground gap-1.5"
              >
                <Pencil className="size-3.5" />
                {isEditing ? '완료' : '수정'}
              </Button>
              <div className="flex-1" />
              <Button
                size="sm"
                onClick={handleSend}
                disabled={disabled || !transcription.trim()}
                className="gap-1.5 rounded-full"
              >
                <Send className="size-3.5" />
                전송
              </Button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
