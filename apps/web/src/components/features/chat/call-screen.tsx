'use client';

import { motion, AnimatePresence } from 'framer-motion';
import { Phone, PhoneOff, MicOff, Mic, FileText, FileX, WifiOff, ArrowLeft } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { CallWaveform } from '@/components/features/chat/call-waveform';
import type { VoiceCallReturn } from '@/hooks/use-voice-call';

type CallScreenProps = {
  call: VoiceCallReturn;
  scenarioTitle?: string;
  characterName?: string;
  characterNameJa?: string;
  avatarUrl?: string;
  onBack?: () => void;
};

function getStatusText(state: string, subState: string, name?: string): string {
  const displayName = name ?? '하루';
  if (state === 'connecting') return '연결 중...';
  if (state === 'ending') return '통화 종료 중...';
  if (state === 'ended') return '통화가 종료되었습니다';
  if (state === 'connected') {
    if (subState === 'ai_speaking') return `${displayName}가 말하고 있어요`;
    if (subState === 'user_speaking') return '듣고 있어요...';
    return '대기 중...';
  }
  return '';
}

function formatTime(seconds: number) {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

export function CallScreen({ call, scenarioTitle, characterName, characterNameJa, avatarUrl, onBack }: CallScreenProps) {
  const {
    state,
    subState,
    callDuration,
    currentAiText,
    subtitles,
    userAnalyserNode,
    aiAnalyserNode,
    isMuted,
    isReconnecting,
    analysisEnabled,
    subtitleEnabled,
    startCall,
    endCall,
    toggleMute,
    toggleAnalysis,
  } = call;

  const displayName = characterName ?? '하루';
  const displayNameJa = characterNameJa ?? 'ハル';
  const statusText = getStatusText(state, subState, displayName);
  const statusKey = `${state}_${subState}`;

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
      <div className="relative flex h-full flex-col items-center justify-center gap-8">
        {/* Back button */}
        {onBack && (
          <button
            onClick={onBack}
            className="absolute left-4 top-[max(1rem,env(safe-area-inset-top))] flex items-center gap-1 text-sm text-white/60 transition-colors hover:text-white/90"
          >
            <ArrowLeft className="size-5" />
            <span>돌아가기</span>
          </button>
        )}
        <CallWaveform analyserNode={null} mode="idle" avatarUrl={avatarUrl} />
        <div className="text-center">
          <h2 className="text-xl font-bold text-white">{displayNameJa}</h2>
          <p className="mt-1 text-sm text-white/60">{displayName}</p>
          {scenarioTitle && (
            <p className="mt-3 rounded-full bg-violet-500/20 px-4 py-1.5 text-sm font-medium text-violet-300">
              {scenarioTitle}
            </p>
          )}
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
      {/* Network reconnecting banner */}
      <AnimatePresence>
        {isReconnecting && (
          <motion.div
            className="absolute left-0 right-0 top-0 z-10 flex items-center justify-center gap-2 bg-amber-500/90 px-4 py-2 pt-[max(0.5rem,env(safe-area-inset-top))] backdrop-blur-sm"
            initial={{ opacity: 0, y: -40 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -40 }}
            transition={{ duration: 0.3 }}
          >
            <WifiOff className="size-4 text-white" />
            <span className="text-sm font-medium text-white">
              네트워크 연결이 불안정합니다. 재연결 중...
            </span>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Scenario badge */}
      {scenarioTitle && (
        <motion.div
          className="mt-12"
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
        >
          <span className="rounded-full bg-violet-500/20 px-3 py-1 text-xs font-medium text-violet-300">
            {scenarioTitle}
          </span>
        </motion.div>
      )}

      {/* Status text */}
      <motion.div
        className={scenarioTitle ? 'mt-3' : 'mt-16'}
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
            {statusText}
          </motion.p>
        </AnimatePresence>
      </motion.div>

      {/* Call duration */}
      <p className="mt-2 font-mono text-2xl font-light tracking-wider text-white/90">
        {formatTime(callDuration)}
      </p>

      {/* Avatar + waveform */}
      <div className="mt-12 flex flex-1 flex-col items-center">
        <CallWaveform analyserNode={activeAnalyser} mode={waveformMode} avatarUrl={avatarUrl} />

        {/* Name */}
        <h2 className="mt-8 text-2xl font-bold text-white">{displayName}</h2>

        {/* Subtitles — recent transcript + current streaming text */}
        {subtitleEnabled && <div className="mt-4 flex max-w-[300px] flex-col items-center gap-1.5">
          <AnimatePresence>
            {subtitles.map((sub, i) => {
              // Older entries fade out progressively based on position
              const posFromEnd = subtitles.length - 1 - i;
              const opacity = posFromEnd === 0 ? 0.7 : Math.max(0.25, 0.7 - posFromEnd * 0.2);
              return (
                <motion.p
                  key={sub.id}
                  className="font-jp text-center text-sm leading-relaxed text-white/60"
                  initial={{ opacity: 0, y: 8 }}
                  animate={{ opacity }}
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
        </div>}
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
