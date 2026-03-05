import { openai } from '@ai-sdk/openai';
import { google } from '@ai-sdk/google';
import type { LanguageModelV1 } from '@ai-sdk/provider';
import { GoogleGenAI } from '@google/genai';

let _googleGenAI: GoogleGenAI | null = null;

export function getGoogleGenAI(): GoogleGenAI {
  if (!_googleGenAI) {
    _googleGenAI = new GoogleGenAI({
      apiKey: process.env.GOOGLE_GENERATIVE_AI_API_KEY!,
    });
  }
  return _googleGenAI;
}

let _googleGenAIAlpha: GoogleGenAI | null = null;

/**
 * GoogleGenAI instance with v1alpha API version.
 * Required for authTokens.create() (ephemeral tokens for Live API).
 */
export function getGoogleGenAIAlpha(): GoogleGenAI {
  if (!_googleGenAIAlpha) {
    _googleGenAIAlpha = new GoogleGenAI({
      apiKey: process.env.GOOGLE_GENERATIVE_AI_API_KEY!,
      httpOptions: { apiVersion: 'v1alpha' },
    });
  }
  return _googleGenAIAlpha;
}

/**
 * Gemini 2.5 Flash TTS — returns raw PCM audio (24kHz, 16-bit, mono).
 */
export async function generateTTS(text: string, voice = 'Kore'): Promise<Buffer> {
  const ai = getGoogleGenAI();
  const response = await ai.models.generateContent({
    model: 'gemini-2.5-flash-preview-tts',
    contents: [{ parts: [{ text }] }],
    config: {
      responseModalities: ['AUDIO'],
      speechConfig: {
        voiceConfig: {
          prebuiltVoiceConfig: { voiceName: voice },
        },
      },
    },
  });
  const data = response.candidates?.[0]?.content?.parts?.[0]?.inlineData?.data;
  if (!data) throw new Error('TTS: No audio data returned');
  return Buffer.from(data, 'base64');
}

/**
 * Gemini 2.5 Flash STT — transcribes audio to Japanese text.
 */
export async function transcribeAudio(audioBuffer: Buffer, mimeType: string): Promise<string> {
  const ai = getGoogleGenAI();
  const response = await ai.models.generateContent({
    model: 'gemini-2.5-flash',
    contents: [{
      parts: [
        { inlineData: { data: audioBuffer.toString('base64'), mimeType } },
        { text: 'この音声を日本語で正確に文字起こししてください。音声のテキストのみを返してください。' },
      ],
    }],
  });
  return response.text?.trim() ?? '';
}

type ProviderType = 'openai' | 'google';

const AI_PROVIDER = (process.env.AI_PROVIDER as ProviderType) || 'openai';

export function getAIProvider(): LanguageModelV1 {
  switch (AI_PROVIDER) {
    case 'google':
      return google('gemini-2.5-flash');
    case 'openai':
    default:
      return openai('gpt-4o-mini');
  }
}

export function createConversation(): LanguageModelV1 {
  return getAIProvider();
}
