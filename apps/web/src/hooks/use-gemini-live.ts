'use client';

import { useState, useRef, useCallback, useEffect } from 'react';
import { GoogleGenAI, Modality } from '@google/genai';
import type { Session } from '@google/genai';
import type { TranscriptEntry, LiveTokenResponse } from '@/types/gemini-live';
import { apiFetch } from '@/lib/api';

type ConnectionState =
  | 'disconnected'
  | 'connecting'
  | 'ready'
  | 'error';

type GeminiLiveOptions = {
  onAudioChunk: (base64: string) => void;
  onTextDelta: (text: string) => void;
  onTurnComplete: () => void;
  onInterrupted: () => void;
  onError: (error: string) => void;
};

type GeminiLiveReturn = {
  connectionState: ConnectionState;
  connect: () => Promise<void>;
  sendAudio: (base64: string) => void;
  disconnect: () => void;
  getTranscript: () => TranscriptEntry[];
};

const GEMINI_MODEL = 'gemini-2.5-flash-native-audio-preview-12-2025';
const GEMINI_VOICE = 'Kore';
const SYSTEM_INSTRUCTION = `あなたは「ハル」、韓国人のための日本語チューターです。
自然な日本語で会話し、学習者のレベルに合わせてください。
文法ミスはやさしく訂正し、返答は1〜3文で簡潔に。
最初の挨拶は「やっほー！ハルコトへようこそ！」`;

export function useGeminiLive(options: GeminiLiveOptions): GeminiLiveReturn {
  const [connectionState, setConnectionState] = useState<ConnectionState>('disconnected');

  const sessionRef = useRef<Session | null>(null);
  const transcriptRef = useRef<TranscriptEntry[]>([]);
  const currentAiTextRef = useRef('');
  const optionsRef = useRef(options);

  optionsRef.current = options;

  const connect = useCallback(async () => {
    if (sessionRef.current) return;

    setConnectionState('connecting');
    transcriptRef.current = [];

    // Fetch ephemeral token from our server
    const { token } = await apiFetch<LiveTokenResponse>(
      '/api/v1/chat/live-token',
      { method: 'POST' }
    );

    // Create client with ephemeral token
    const client = new GoogleGenAI({
      apiKey: token,
      httpOptions: { apiVersion: 'v1alpha' },
    });

    // Use SDK's live.connect — handles all WS protocol details
    const session = await client.live.connect({
      model: GEMINI_MODEL,
      config: {
        responseModalities: [Modality.AUDIO],
        speechConfig: {
          voiceConfig: {
            prebuiltVoiceConfig: { voiceName: GEMINI_VOICE },
          },
        },
        systemInstruction: SYSTEM_INSTRUCTION,
      },
      callbacks: {
        onopen: () => {},
        onmessage: (msg) => {
          try {
            const sc = msg.serverContent;
            if (!sc) return;

            // Process model turn parts
            // Native audio model emits thinking/reasoning as text — ignore it.
            // Only process inlineData (audio chunks).
            if (sc.modelTurn?.parts) {
              for (const part of sc.modelTurn.parts) {
                if ('inlineData' in part && part.inlineData) {
                  optionsRef.current.onAudioChunk(part.inlineData.data as string);
                }
              }
            }

            // Turn complete
            if (sc.turnComplete) {
              if (currentAiTextRef.current.trim()) {
                transcriptRef.current.push({
                  role: 'assistant',
                  text: currentAiTextRef.current.trim(),
                });
              }
              currentAiTextRef.current = '';
              optionsRef.current.onTurnComplete();
            }

            // Interrupted (barge-in)
            if (sc.interrupted) {
              currentAiTextRef.current = '';
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
          sessionRef.current = null;
          setConnectionState('disconnected');
        },
      },
    });

    sessionRef.current = session;
    setConnectionState('ready');

    // Send initial prompt to trigger AI greeting
    session.sendClientContent({
      turns: [{
        role: 'user',
        parts: [{ text: '会話を始めてください。' }],
      }],
      turnComplete: true,
    });
  }, []);

  const sendAudio = useCallback((base64: string) => {
    const session = sessionRef.current;
    if (!session) return;

    session.sendRealtimeInput({
      media: {
        mimeType: 'audio/pcm;rate=16000',
        data: base64,
      },
    });
  }, []);

  const disconnect = useCallback(() => {
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
    return [...transcriptRef.current];
  }, []);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
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
