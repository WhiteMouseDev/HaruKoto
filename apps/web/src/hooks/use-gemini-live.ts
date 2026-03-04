'use client';

import { useState, useRef, useCallback, useEffect } from 'react';
import {
  GoogleGenAI,
  Modality,
  StartSensitivity,
  EndSensitivity,
} from '@google/genai';
import type { Session, LiveConnectParameters } from '@google/genai';
import type { TranscriptEntry, LiveTokenResponse } from '@/types/gemini-live';
import { apiFetch } from '@/lib/api';

type ConnectionState =
  | 'disconnected'
  | 'connecting'
  | 'ready'
  | 'error';

type GeminiLiveOptions = {
  nickname?: string;
  systemInstruction?: string;
  greeting?: string;
  silenceDurationMs?: number;
  voiceName?: string;
  onAudioChunk: (base64: string) => void;
  onAiTextDelta: (text: string) => void;
  onTranscript: (entry: TranscriptEntry) => void;
  onTurnComplete: () => void;
  onInterrupted: () => void;
  onError: (error: string) => void;
  onDisconnected?: () => void;
};

type GeminiLiveReturn = {
  connectionState: ConnectionState;
  connect: () => Promise<void>;
  sendAudio: (base64: string) => void;
  disconnect: () => void;
  getTranscript: () => TranscriptEntry[];
};

const GEMINI_MODEL = 'gemini-2.5-flash-native-audio-preview-12-2025';
const DEFAULT_VOICE = 'Kore';
const MAX_RECONNECT_ATTEMPTS = 3;
const RECONNECT_BASE_DELAY_MS = 1000;
const DEFAULT_SYSTEM_INSTRUCTION = `あなたは日本に住んでいる日本人で、韓国人の友達と電話するのが好き。
明るくてフレンドリーな性格。

## ルール
- これは電話の会話です。実際の友達同士の電話のように自然に振る舞ってください。
- 最初の挨拶は「もしもし」「やっほー」など電話らしく。
- 会話中に文法を直接訂正しないでください。自然に正しい表現を使い返してください。
- 返答は1〜2文で簡潔に。電話の会話は短いやりとりが基本です。
- 相手のレベルに合わせて語彙の難易度を調整してください。
- 相手の名前を時々呼んで親しみを出してください。`;

export function useGeminiLive(options: GeminiLiveOptions): GeminiLiveReturn {
  const [connectionState, setConnectionState] = useState<ConnectionState>('disconnected');

  const sessionRef = useRef<Session | null>(null);
  const aliveRef = useRef(false);
  const transcriptRef = useRef<TranscriptEntry[]>([]);
  const currentAiTranscriptRef = useRef('');
  const currentUserTranscriptRef = useRef('');
  const optionsRef = useRef(options);
  const resumptionHandleRef = useRef<string | null>(null);
  const reconnectAttemptsRef = useRef(0);
  const reconnectTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const intentionalDisconnectRef = useRef(false);
  const attemptReconnectRef = useRef<() => void>(() => {});

  useEffect(() => {
    optionsRef.current = options;
  });

  // --- Internal connection logic (shared by initial connect + reconnect) ---
  const connectInternal = useCallback(
    async (resumeHandle?: string) => {
      // Fetch ephemeral token from our server
      const { token } = await apiFetch<LiveTokenResponse>(
        '/api/v1/chat/live-token',
        { method: 'POST' }
      );

      const client = new GoogleGenAI({
        apiKey: token,
        httpOptions: { apiVersion: 'v1alpha' },
      });

      const config: LiveConnectParameters = {
        model: GEMINI_MODEL,
        config: {
          responseModalities: [Modality.AUDIO],
          speechConfig: {
            voiceConfig: {
              prebuiltVoiceConfig: { voiceName: optionsRef.current.voiceName ?? DEFAULT_VOICE },
            },
          },
          systemInstruction: optionsRef.current.systemInstruction ?? DEFAULT_SYSTEM_INSTRUCTION,
          enableAffectiveDialog: true,
          proactivity: { proactiveAudio: true },
          inputAudioTranscription: {},
          outputAudioTranscription: {},
          // VAD sensitivity — reduce false positives from background noise on mobile
          realtimeInputConfig: {
            automaticActivityDetection: {
              startOfSpeechSensitivity: StartSensitivity.START_SENSITIVITY_HIGH,
              endOfSpeechSensitivity: EndSensitivity.END_SENSITIVITY_HIGH,
              prefixPaddingMs: 300,
              silenceDurationMs: optionsRef.current.silenceDurationMs ?? 1200,
            },
          },
          // Session resumption — enables reconnection without losing context
          sessionResumption: {
            ...(resumeHandle ? { handle: resumeHandle } : {}),
          },
        },
        callbacks: {
          onopen: () => {
            // Reset reconnect counter on successful connection
            reconnectAttemptsRef.current = 0;
          },
          onmessage: (msg) => {
            try {
              // Session resumption handle updates
              if (msg.sessionResumptionUpdate) {
                const update = msg.sessionResumptionUpdate;
                if (update.resumable && update.newHandle) {
                  resumptionHandleRef.current = update.newHandle;
                }
              }

              // goAway — server will disconnect soon, attempt proactive reconnect
              if (msg.goAway) {
                const handle = resumptionHandleRef.current;
                if (handle) {
                  // Proactively reconnect before the server closes
                  attemptReconnectRef.current();
                }
                return;
              }

              const sc = msg.serverContent;
              if (!sc) return;

              // Helper: flush accumulated user speech as a single entry
              const flushUserTranscript = () => {
                const userText = currentUserTranscriptRef.current.trim();
                if (userText) {
                  const entry: TranscriptEntry = { role: 'user', text: userText };
                  transcriptRef.current.push(entry);
                  optionsRef.current.onTranscript(entry);
                  currentUserTranscriptRef.current = '';
                }
              };

              // Process model turn parts (audio only)
              // Flush any pending user text when AI starts responding
              if (sc.modelTurn?.parts) {
                flushUserTranscript();
                for (const part of sc.modelTurn.parts) {
                  if ('inlineData' in part && part.inlineData) {
                    optionsRef.current.onAudioChunk(
                      part.inlineData.data as string
                    );
                  }
                }
              }

              // Output transcription (AI speech → text)
              // Also flush user text if not already done
              if (sc.outputTranscription?.text) {
                flushUserTranscript();
                currentAiTranscriptRef.current += sc.outputTranscription.text;
                optionsRef.current.onAiTextDelta(sc.outputTranscription.text);
              }

              // Input transcription (User speech → text)
              // Just accumulate — will be flushed when AI responds
              if (sc.inputTranscription?.text) {
                currentUserTranscriptRef.current += sc.inputTranscription.text;
              }

              // Turn complete
              if (sc.turnComplete) {
                flushUserTranscript();
                const aiText = currentAiTranscriptRef.current.trim();
                if (aiText) {
                  const entry: TranscriptEntry = {
                    role: 'assistant',
                    text: aiText,
                  };
                  transcriptRef.current.push(entry);
                  optionsRef.current.onTranscript(entry);
                }
                currentAiTranscriptRef.current = '';
                optionsRef.current.onTurnComplete();
              }

              // Interrupted (barge-in)
              if (sc.interrupted) {
                flushUserTranscript();
                const aiText = currentAiTranscriptRef.current.trim();
                if (aiText) {
                  const entry: TranscriptEntry = {
                    role: 'assistant',
                    text: aiText,
                  };
                  transcriptRef.current.push(entry);
                  optionsRef.current.onTranscript(entry);
                }
                currentAiTranscriptRef.current = '';
                optionsRef.current.onInterrupted();
              }
            } catch {
              // Ignore parse errors
            }
          },
          onerror: (e) => {
            setConnectionState('error');
            optionsRef.current.onError(
              e instanceof Error ? e.message : 'WebSocket 연결 오류'
            );
          },
          onclose: () => {
            const wasAlive = aliveRef.current;
            sessionRef.current = null;
            aliveRef.current = false;

            // If intentional disconnect, just update state
            if (intentionalDisconnectRef.current) {
              setConnectionState('disconnected');
              return;
            }

            // Unexpected close — attempt reconnect if we have a handle
            if (wasAlive && resumptionHandleRef.current) {
              attemptReconnectRef.current();
            } else if (wasAlive) {
              setConnectionState('disconnected');
              optionsRef.current.onDisconnected?.();
            } else {
              setConnectionState('disconnected');
            }
          },
        },
      };

      const session = await client.live.connect(config);

      sessionRef.current = session;
      aliveRef.current = true;
      setConnectionState('ready');

      return session;
    },
    []
  );

  // --- Reconnect with exponential backoff ---
  const attemptReconnect = useCallback(() => {
    if (intentionalDisconnectRef.current) return;
    if (reconnectAttemptsRef.current >= MAX_RECONNECT_ATTEMPTS) {
      // Exhausted retries — give up and notify parent
      resumptionHandleRef.current = null;
      setConnectionState('disconnected');
      optionsRef.current.onDisconnected?.();
      return;
    }

    const attempt = reconnectAttemptsRef.current;
    reconnectAttemptsRef.current = attempt + 1;
    const delay = RECONNECT_BASE_DELAY_MS * Math.pow(2, attempt);

    setConnectionState('connecting');

    reconnectTimerRef.current = setTimeout(async () => {
      const handle = resumptionHandleRef.current;
      if (!handle || intentionalDisconnectRef.current) return;

      try {
        // Close old session if still lingering
        if (sessionRef.current) {
          try {
            sessionRef.current.close();
          } catch {
            // already closed
          }
          sessionRef.current = null;
        }

        await connectInternal(handle);
      } catch {
        // Reconnect failed — retry
        attemptReconnectRef.current();
      }
    }, delay);
  }, [connectInternal]);

  useEffect(() => {
    attemptReconnectRef.current = attemptReconnect;
  });

  // --- Public connect (initial) ---
  const connect = useCallback(async () => {
    if (sessionRef.current) return;

    setConnectionState('connecting');
    transcriptRef.current = [];
    intentionalDisconnectRef.current = false;
    reconnectAttemptsRef.current = 0;
    resumptionHandleRef.current = null;

    const session = await connectInternal();
    if (!session) return;

    // Send initial prompt to trigger AI greeting like a real phone call
    const name = optionsRef.current.nickname;
    const defaultGreeting = name
      ? `[システム] ${name}から電話がかかってきました。電話に出て「もしもし」から始めてください。`
      : '[システム] 友達から電話がかかってきました。電話に出て「もしもし」から始めてください。';
    const greeting = optionsRef.current.greeting ?? defaultGreeting;
    session.sendClientContent({
      turns: [
        {
          role: 'user',
          parts: [{ text: greeting }],
        },
      ],
      turnComplete: true,
    });
  }, [connectInternal]);

  const sendAudio = useCallback((base64: string) => {
    const session = sessionRef.current;
    if (!session || !aliveRef.current) return;

    try {
      session.sendRealtimeInput({
        media: {
          mimeType: 'audio/pcm;rate=16000',
          data: base64,
        },
      });
    } catch {
      // WebSocket already closing/closed — stop sending
      aliveRef.current = false;
    }
  }, []);

  const disconnect = useCallback(() => {
    intentionalDisconnectRef.current = true;
    aliveRef.current = false;

    // Cancel pending reconnect
    if (reconnectTimerRef.current) {
      clearTimeout(reconnectTimerRef.current);
      reconnectTimerRef.current = null;
    }

    if (sessionRef.current) {
      try {
        sessionRef.current.close();
      } catch {
        // already closed
      }
      sessionRef.current = null;
    }
    setConnectionState('disconnected');
  }, []);

  const getTranscript = useCallback((): TranscriptEntry[] => {
    // Flush any pending user text that hasn't been committed yet
    const pendingUser = currentUserTranscriptRef.current.trim();
    if (pendingUser) {
      transcriptRef.current.push({ role: 'user', text: pendingUser });
      currentUserTranscriptRef.current = '';
    }
    // Flush any pending AI text (e.g. interrupted mid-sentence)
    const pendingAi = currentAiTranscriptRef.current.trim();
    if (pendingAi) {
      transcriptRef.current.push({ role: 'assistant', text: pendingAi });
      currentAiTranscriptRef.current = '';
    }
    return [...transcriptRef.current];
  }, []);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      intentionalDisconnectRef.current = true;
      if (reconnectTimerRef.current) {
        clearTimeout(reconnectTimerRef.current);
      }
      if (sessionRef.current) {
        try {
          sessionRef.current.close();
        } catch {
          // already closed
        }
        sessionRef.current = null;
      }
    };
  }, []);

  return { connectionState, connect, sendAudio, disconnect, getTranscript };
}
