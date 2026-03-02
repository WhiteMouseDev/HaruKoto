'use client';

import { motion, AnimatePresence } from 'framer-motion';
import { Phone, PhoneOff, MicOff, Mic, FileText, FileX } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { CallWaveform } from '@/components/features/chat/call-waveform';
import type { VoiceCallReturn } from '@/hooks/use-voice-call';

type CallScreenProps = {
  call: VoiceCallReturn;
};

const STATUS_TEXT: Record<string, string> = {
  idle: '',
  connecting: '연결 중...',
  connected_idle: '대기 중...',
  connected_ai_speaking: '하루가 말하고 있어요',
  connected_user_speaking: '듣고 있어요...',
  ending: '통화 종료 중...',
  ended: '통화가 종료되었습니다',
};

function getStatusKey(state: string, subState: string): string {
  if (state === 'connected') return `connected_${subState}`;
  return state;
}

function formatTime(seconds: number) {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

export function CallScreen({ call }: CallScreenProps) {
  const {
    state,
    subState,
    callDuration,
    currentAiText,
    subtitles,
    userAnalyserNode,
    aiAnalyserNode,
    isMuted,
    analysisEnabled,
    startCall,
    endCall,
    toggleMute,
    toggleAnalysis,
  } = call;

  const statusKey = getStatusKey(state, subState);

  // Derive waveform mode and analyser from subState
  const waveformMode =
    subState === 'user_speaking'
      ? 'listening'
      : subState === 'ai_speaking'
        ? 'speaking'
        : 'idle';

  const activeAnalyser =
    subState === 'user_speaking'
      ? userAnalyserNode
      : subState === 'ai_speaking'
        ? aiAnalyserNode
        : null;

  // Idle screen — show start button
  if (state === 'idle') {
    return (
      <div className="flex h-full flex-col items-center justify-center gap-8">
        <CallWaveform analyserNode={null} mode="idle" />
        <div className="text-center">
          <h2 className="text-xl font-bold text-white">ハルさん (하루)</h2>
          <p className="mt-1 text-sm text-white/60">AI 전화 통화</p>
        </div>
        {call.error && (
          <p className="rounded-lg bg-red-500/20 px-4 py-2 text-center text-sm text-red-300">
            {call.error}
          </p>
        )}
        <motion.div whileTap={{ scale: 0.95 }}>
          <Button
            size="lg"
            className="size-20 rounded-full bg-emerald-500 text-white shadow-lg shadow-emerald-500/30 hover:bg-emerald-600"
            onClick={startCall}
          >
            <Phone className="size-8" />
          </Button>
        </motion.div>
        <p className="text-sm text-white/40">탭하여 통화 시작</p>
      </div>
    );
  }

  return (
    <div className="pt-safe-top flex h-full flex-col items-center px-6">
      {/* Status text */}
      <motion.div
        className="mt-16"
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
      >
        <AnimatePresence mode="wait">
          <motion.p
            key={statusKey}
            className="text-sm font-medium text-white/70"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
          >
            {STATUS_TEXT[statusKey] || ''}
          </motion.p>
        </AnimatePresence>
      </motion.div>

      {/* Call duration */}
      <p className="mt-2 font-mono text-2xl font-light tracking-wider text-white/90">
        {formatTime(callDuration)}
      </p>

      {/* Avatar + waveform */}
      <div className="mt-12 flex flex-1 flex-col items-center">
        <CallWaveform analyserNode={activeAnalyser} mode={waveformMode} />

        {/* Name */}
        <h2 className="mt-8 text-2xl font-bold text-white">하루</h2>

        {/* Subtitles — recent transcript + current streaming text */}
        <div className="mt-4 flex max-w-[300px] flex-col items-center gap-1.5">
          <AnimatePresence>
            {subtitles.map((sub, i) => {
              const age = (Date.now() - sub.timestamp) / 1000;
              // Older entries fade out progressively
              const opacity = Math.max(0.25, 1 - age / 6);
              return (
                <motion.p
                  key={sub.id}
                  className="font-jp text-center text-sm leading-relaxed text-white/60"
                  style={{ opacity: i === subtitles.length - 1 ? undefined : opacity }}
                  initial={{ opacity: 0, y: 8 }}
                  animate={{ opacity: i === subtitles.length - 1 ? 0.7 : opacity }}
                  exit={{ opacity: 0, y: -4 }}
                  transition={{ duration: 0.3 }}
                >
                  {sub.text}
                </motion.p>
              );
            })}
          </AnimatePresence>
          {/* Current streaming AI text */}
          <AnimatePresence>
            {currentAiText && (
              <motion.p
                key="streaming"
                className="font-jp text-center text-sm leading-relaxed text-white/80"
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.2 }}
              >
                {currentAiText}
              </motion.p>
            )}
          </AnimatePresence>
        </div>
      </div>

      {/* Controls */}
      <div className="mb-safe-bottom flex w-full items-center justify-center gap-8 pb-12">
        {/* Mute */}
        <motion.div whileTap={{ scale: 0.9 }}>
          <Button
            variant="ghost"
            size="icon"
            className={`size-14 rounded-full ${
              isMuted
                ? 'bg-white/20 text-white'
                : 'bg-white/10 text-white/70 hover:text-white'
            }`}
            onClick={toggleMute}
            disabled={state === 'connecting' || state === 'ending'}
          >
            {isMuted ? (
              <MicOff className="size-6" />
            ) : (
              <Mic className="size-6" />
            )}
          </Button>
        </motion.div>

        {/* End call */}
        <motion.div whileTap={{ scale: 0.9 }}>
          <Button
            size="icon"
            className="size-16 rounded-full bg-red-500 text-white shadow-lg shadow-red-500/30 hover:bg-red-600"
            onClick={endCall}
            disabled={state === 'ending'}
          >
            <PhoneOff className="size-7" />
          </Button>
        </motion.div>

        {/* Analysis toggle */}
        <motion.div whileTap={{ scale: 0.9 }}>
          <Button
            variant="ghost"
            size="icon"
            className={`size-14 rounded-full ${
              analysisEnabled
                ? 'bg-emerald-500/20 text-emerald-400'
                : 'bg-white/10 text-white/40 hover:text-white/60'
            }`}
            onClick={toggleAnalysis}
            disabled={state === 'connecting' || state === 'ending'}
          >
            {analysisEnabled ? (
              <FileText className="size-6" />
            ) : (
              <FileX className="size-6" />
            )}
          </Button>
        </motion.div>
      </div>

      {/* Analysis hint */}
      <p className="mb-safe-bottom pb-2 text-xs text-white/30">
        {analysisEnabled ? '통화 분석 ON' : '통화 분석 OFF'}
      </p>
    </div>
  );
}
