'use client';

import { useState, useRef, useCallback, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import { usePcmRecorder } from '@/hooks/use-pcm-recorder';
import { usePcmPlayer } from '@/hooks/use-pcm-player';
import { useGeminiLive } from '@/hooks/use-gemini-live';
import type {
  LiveCallState,
  LiveCallSubState,
  TranscriptEntry,
} from '@/types/gemini-live';
import type { CharacterDetail } from '@/hooks/use-characters';

export type CallScenario = {
  id: string;
  title: string;
  titleJa: string;
  situation: string;
  yourRole: string;
  aiRole: string;
  systemPrompt: string | null;
  keyExpressions: string[];
};

export type CallSettings = {
  silenceDurationMs?: number;
  aiResponseSpeed?: number;
  subtitleEnabled?: boolean;
  autoAnalysis?: boolean;
};

type VoiceCallOptions = {
  nickname?: string;
  jlptLevel?: string;
  scenario?: CallScenario;
  callSettings?: CallSettings;
  character?: CharacterDetail;
};

const JLPT_VOICE_LEVELS: Record<string, string> = {
  N5: `## ユーザーレベル: JLPT N5 (初級)
- 基本的な挨拶と簡単な文だけ分かります
- N5レベルの語彙のみ使用（約800語以内）
- です/ます形、基本的な助詞のみ
- 短く簡潔な返答（1文）`,
  N4: `## ユーザーレベル: JLPT N4 (初級上)
- 基本的な日常会話ができます
- N5〜N4レベルの語彙（約1,500語以内）
- て形、ない形、可能形を使用可能
- 返答は1〜2文`,
  N3: `## ユーザーレベル: JLPT N3 (中級)
- 日常会話がある程度できます
- N5〜N3レベルの語彙（約3,000語以内）
- 自然な口語表現を使用`,
  N2: `## ユーザーレベル: JLPT N2 (上級)
- 複雑な会話も理解できます
- 語彙制限少なめ、慣用句も使用可能`,
  N1: `## ユーザーレベル: JLPT N1 (最上級)
- ネイティブに近い理解力があります
- 語彙制限なし`,
};

function buildCallSystemInstruction(
  scenario?: CallScenario,
  jlptLevel?: string,
  character?: CharacterDetail
): string | undefined {
  const levelSection = JLPT_VOICE_LEVELS[jlptLevel ?? 'N5'] ?? JLPT_VOICE_LEVELS.N5;

  // Character personality takes priority as the base prompt
  if (character?.personality) {
    const base = character.personality;

    if (scenario) {
      const scenarioSection = scenario.systemPrompt
        ? scenario.systemPrompt
        : `## シナリオ
- 状況: ${scenario.situation}
- ユーザーの役割: ${scenario.yourRole}
- あなたの役割: ${scenario.aiRole}
${scenario.keyExpressions.length > 0 ? `- キーフレーズ: ${scenario.keyExpressions.join(', ')}` : ''}`;

      return `${base}

${scenarioSection}

${levelSection}

## 重要なルール
- これは電話の会話です。実際の電話のように自然に振る舞ってください。
- 会話中に文法を直接訂正しないでください。自然に正しい表現を使い返してください。
- 返答は1〜2文で簡潔に。電話の会話は短いやりとりが基本です。`;
    }

    return `${base}

${levelSection}`;
  }

  // No character — legacy behavior
  if (!scenario) return undefined; // use default in useGeminiLive

  if (scenario.systemPrompt) {
    return `${scenario.systemPrompt}

${levelSection}

## 重要なルール
- これは電話の会話です。実際の電話のように自然に振る舞ってください。
- 会話中に文法を直接訂正しないでください。自然に正しい表現を使い返してください。
- 返答は1〜2文で簡潔に。電話の会話は短いやりとりが基本です。`;
  }

  return `あなたは日本に住んでいる日本人で、韓国人の友達と電話するのが好き。
明るくてフレンドリーな性格。

## シナリオ
- 状況: ${scenario.situation}
- ユーザーの役割: ${scenario.yourRole}
- あなたの役割: ${scenario.aiRole}
${scenario.keyExpressions.length > 0 ? `- キーフレーズ: ${scenario.keyExpressions.join(', ')}` : ''}

${levelSection}

## ルール
- これは電話の会話です。実際の電話のように自然に振る舞ってください。
- 会話中に文法を直接訂正しないでください。自然に正しい表現を使い返してください。
- 返答は1〜2文で簡潔に。電話の会話は短いやりとりが基本です。
- シナリオの状況と役割に沿って会話を進めてください。
- 相手のレベルに合わせて語彙の難易度を調整してください。`;
}

function buildCallGreeting(
  scenario?: CallScenario,
  nickname?: string,
  character?: CharacterDetail
): string | undefined {
  const nameStr = nickname ?? '友達';

  if (scenario) {
    return `[システム] ${nameStr}から電話がかかってきました。あなたは「${scenario.aiRole}」の役割です。状況は「${scenario.situation}」です。電話に出て、この状況に合った挨拶から始めてください。`;
  }

  if (character) {
    return `[システム] ${nameStr}から電話がかかってきました。電話に出て「もしもし」から始めてください。`;
  }

  return undefined; // use default in useGeminiLive
}

export type SubtitleEntry = {
  id: number;
  role: 'user' | 'assistant';
  text: string;
  timestamp: number;
};

export type VoiceCallReturn = {
  state: LiveCallState;
  subState: LiveCallSubState;
  callDuration: number;
  currentAiText: string;
  subtitles: SubtitleEntry[];
  userAnalyserNode: AnalyserNode | null;
  aiAnalyserNode: AnalyserNode | null;
  error: string | null;
  isMuted: boolean;
  isReconnecting: boolean;
  analysisEnabled: boolean;
  subtitleEnabled: boolean;
  startCall: () => Promise<void>;
  endCall: () => void;
  toggleMute: () => void;
  toggleAnalysis: () => void;
};

export function useVoiceCall(options?: VoiceCallOptions): VoiceCallReturn {
  const { nickname, jlptLevel, scenario, callSettings, character } = options ?? {};
  const router = useRouter();
  const [state, setState] = useState<LiveCallState>('idle');
  const [subState, setSubState] = useState<LiveCallSubState>('idle');
  const [callDuration, setCallDuration] = useState(0);
  const [currentAiText, setCurrentAiText] = useState('');
  const [subtitles, setSubtitles] = useState<SubtitleEntry[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [isMuted, setIsMuted] = useState(false);
  const [analysisEnabled, setAnalysisEnabled] = useState(callSettings?.autoAnalysis ?? true);

  const stateRef = useRef<LiveCallState>('idle');
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const callStartRef = useRef(0);
  const ringtoneRef = useRef<HTMLAudioElement | null>(null);
  const analysisEnabledRef = useRef(true);
  const subtitleIdRef = useRef(0);
  const endCallRef = useRef<() => void>(() => {});
  const scenarioIdRef = useRef(scenario?.id);
  const characterRef = useRef(character);

  stateRef.current = state;
  analysisEnabledRef.current = analysisEnabled;
  scenarioIdRef.current = scenario?.id;
  characterRef.current = character;

  // --- Ringtone ---
  const playRingtone = useCallback(() => {
    const audio = new Audio('/sounds/ringtone.wav');
    audio.loop = true;
    audio.volume = 0.5;
    audio.play().catch(() => {});
    ringtoneRef.current = audio;
  }, []);

  const stopRingtone = useCallback(() => {
    if (ringtoneRef.current) {
      ringtoneRef.current.pause();
      ringtoneRef.current.currentTime = 0;
      ringtoneRef.current = null;
    }
  }, []);

  // --- PCM Player (AI audio output) ---
  const player = usePcmPlayer();

  // --- Gemini Live WebSocket ---
  const gemini = useGeminiLive({
    nickname,
    systemInstruction: buildCallSystemInstruction(scenario, jlptLevel, character),
    greeting: buildCallGreeting(scenario, nickname, character),
    silenceDurationMs: callSettings?.silenceDurationMs ?? character?.silenceMs,
    voiceName: character?.voiceName,
    onAudioChunk: useCallback(
      (base64: string) => {
        if (stateRef.current !== 'connected') return;
        setSubState('ai_speaking');
        player.enqueue(base64);
      },
      [player]
    ),
    onAiTextDelta: useCallback((text: string) => {
      setCurrentAiText((prev) => prev + text);
    }, []),
    onTranscript: useCallback((entry: TranscriptEntry) => {
      // Only show AI subtitles (user speech doesn't need display)
      if (entry.role !== 'assistant') return;
      setSubtitles((prev) => {
        const next = [
          ...prev,
          {
            id: ++subtitleIdRef.current,
            role: 'assistant' as const,
            text: entry.text,
            timestamp: Date.now(),
          },
        ];
        // Keep only last 3
        return next.slice(-3);
      });
    }, []),
    onTurnComplete: useCallback(() => {
      setSubState('idle');
      setCurrentAiText('');
    }, []),
    onInterrupted: useCallback(() => {
      player.interrupt();
      setSubState('user_speaking');
      setCurrentAiText('');
    }, [player]),
    onError: useCallback((msg: string) => {
      toast.error(msg);
      setError(msg);
    }, []),
    onDisconnected: useCallback(() => {
      // Gemini closed the connection unexpectedly (e.g. silence timeout)
      if (stateRef.current === 'connected') {
        toast.info('연결이 종료되었습니다.');
        endCallRef.current();
      }
    }, []),
  });

  // --- PCM Recorder (User mic input) ---
  const recorder = usePcmRecorder({
    onPcmChunk: useCallback(
      (base64: string) => {
        gemini.sendAudio(base64);
      },
      [gemini]
    ),
  });

  // Track subState from player
  useEffect(() => {
    if (!player.isPlaying && subState === 'ai_speaking') {
      setSubState('idle');
    }
  }, [player.isPlaying, subState]);

  // --- Call duration timer ---
  const startTimer = useCallback(() => {
    setCallDuration(0);
    callStartRef.current = Date.now();
    timerRef.current = setInterval(() => {
      setCallDuration(Math.floor((Date.now() - callStartRef.current) / 1000));
    }, 1000);
  }, []);

  const stopTimer = useCallback(() => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
  }, []);

  // --- Start call ---
  const startCall = useCallback(async () => {
    if (stateRef.current !== 'idle') return;
    setState('connecting');
    stateRef.current = 'connecting';
    setError(null);

    // Init AudioContext during user gesture to avoid autoplay block
    player.init();

    // Play ringtone while connecting
    playRingtone();

    try {
      // Connect to Gemini Live — waits for setupComplete
      await gemini.connect();

      // Stop ringtone once connected
      stopRingtone();

      // Start recording mic
      await recorder.start();

      setState('connected');
      stateRef.current = 'connected';
      setSubState('idle');
      startTimer();
    } catch (err) {
      stopRingtone();
      setError(err instanceof Error ? err.message : '통화를 시작할 수 없습니다.');
      setState('idle');
      stateRef.current = 'idle';
      recorder.stop();
      gemini.disconnect();
    }
  }, [gemini, player, recorder, startTimer, playRingtone, stopRingtone]);

  // --- End call ---
  const endCall = useCallback(() => {
    if (stateRef.current === 'idle' || stateRef.current === 'ending' || stateRef.current === 'ended') return;

    setState('ending');
    stateRef.current = 'ending';
    stopTimer();
    stopRingtone();

    // Stop all audio
    recorder.stop();
    player.stop();

    // Get transcript and duration before disconnecting
    const transcript = gemini.getTranscript();
    const durationSeconds = callStartRef.current
      ? Math.floor((Date.now() - callStartRef.current) / 1000)
      : 0;

    gemini.disconnect();

    if (analysisEnabledRef.current && transcript.length > 0) {
      // Store data for the analyzing page, navigate immediately
      const char = characterRef.current;
      sessionStorage.setItem(
        'call_analysis_data',
        JSON.stringify({
          transcript,
          durationSeconds,
          scenarioId: scenarioIdRef.current,
          characterId: char?.id,
          character: char
            ? { name: char.name, nameJa: char.nameJa, avatarUrl: char.avatarUrl }
            : undefined,
        })
      );
      router.push('/chat/call/analyzing');
    } else {
      // No analysis — just go back
      setState('ended');
      stateRef.current = 'ended';
      router.push('/chat');
    }
  }, [gemini, player, recorder, router, stopTimer, stopRingtone]);

  endCallRef.current = endCall;

  // --- Toggle mute ---
  const toggleMute = useCallback(() => {
    setIsMuted((prev) => {
      const next = !prev;
      recorder.setMuted(next);
      return next;
    });
  }, [recorder]);

  // --- Toggle analysis ---
  const toggleAnalysis = useCallback(() => {
    setAnalysisEnabled((prev) => !prev);
  }, []);

  // Auto-remove old subtitles after 6 seconds
  useEffect(() => {
    if (subtitles.length === 0) return;
    const interval = setInterval(() => {
      const cutoff = Date.now() - 6000;
      setSubtitles((prev) => prev.filter((s) => s.timestamp > cutoff));
    }, 1000);
    return () => clearInterval(interval);
  }, [subtitles.length]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
      ringtoneRef.current?.pause();
      recorder.stop();
      player.stop();
      gemini.disconnect();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Reconnecting = call is logically active but WebSocket is re-establishing
  const isReconnecting =
    state === 'connected' && gemini.connectionState === 'connecting';

  return {
    state,
    subState,
    callDuration,
    currentAiText,
    subtitles,
    userAnalyserNode: recorder.analyserNode,
    aiAnalyserNode: player.analyserNode,
    error,
    isMuted,
    isReconnecting,
    analysisEnabled,
    subtitleEnabled: callSettings?.subtitleEnabled ?? true,
    startCall,
    endCall,
    toggleMute,
    toggleAnalysis,
  };
}
