// ─── WebSocket Protocol Types ───────────────────────────────────────────────

/** Client → Gemini: initial setup message */
export type GeminiLiveSetupMessage = {
  setup: {
    model: string;
    generationConfig: {
      responseModalities: ('AUDIO' | 'TEXT')[];
      speechConfig: {
        voiceConfig: {
          prebuiltVoiceConfig: {
            voiceName: string;
          };
        };
      };
    };
    systemInstruction: {
      parts: { text: string }[];
    };
    realtimeInputConfig?: {
      automaticActivityDetection?: {
        disabled?: boolean;
        startOfSpeechSensitivity?: 'START_SENSITIVITY_LOW' | 'START_SENSITIVITY_MEDIUM' | 'START_SENSITIVITY_HIGH';
        endOfSpeechSensitivity?: 'END_SENSITIVITY_LOW' | 'END_SENSITIVITY_MEDIUM' | 'END_SENSITIVITY_HIGH';
      };
    };
  };
};

/** Client → Gemini: audio input chunk */
export type GeminiRealtimeInput = {
  realtimeInput: {
    mediaChunks: {
      mimeType: 'audio/pcm;rate=16000';
      data: string; // base64
    }[];
  };
};

/** Gemini → Client: server content (audio + text) */
export type GeminiServerContent = {
  serverContent?: {
    modelTurn?: {
      parts: GeminiPart[];
    };
    turnComplete?: boolean;
    interrupted?: boolean;
  };
  setupComplete?: Record<string, never>;
};

export type GeminiPart =
  | { inlineData: { mimeType: string; data: string } }
  | { text: string };

// ─── Hook State Types ───────────────────────────────────────────────────────

export type LiveCallState =
  | 'idle'
  | 'connecting'
  | 'connected'
  | 'ending'
  | 'ended';

export type LiveCallSubState =
  | 'idle'
  | 'ai_speaking'
  | 'user_speaking';

export type TranscriptEntry = {
  role: 'user' | 'assistant';
  text: string;
};

// ─── API Response Types ─────────────────────────────────────────────────────

export type LiveTokenResponse = {
  token: string;
  wsUri: string;
};

export type LiveFeedbackRequest = {
  transcript: TranscriptEntry[];
  durationSeconds: number;
};

export type LiveFeedbackResponse = {
  conversationId: string;
  feedbackSummary: Record<string, unknown> | null;
  xpEarned: number;
  events?: {
    type: 'level_up' | 'streak' | 'achievement';
    data: Record<string, unknown>;
    title: string;
    body: string;
    emoji: string;
  }[];
};
