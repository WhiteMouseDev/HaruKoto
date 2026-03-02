import { openai } from '@ai-sdk/openai';
import { google } from '@ai-sdk/google';
import OpenAI from 'openai';
import { GoogleGenAI } from '@google/genai';

export const openaiClient = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

let _googleGenAI: GoogleGenAI | null = null;

/**
 * GoogleGenAI instance with v1alpha API version.
 * Required for authTokens.create() (ephemeral tokens for Live API).
 */
export function getGoogleGenAI(): GoogleGenAI {
  if (!_googleGenAI) {
    _googleGenAI = new GoogleGenAI({
      apiKey: process.env.GOOGLE_GENERATIVE_AI_API_KEY!,
      httpOptions: { apiVersion: 'v1alpha' },
    });
  }
  return _googleGenAI;
}

type ProviderType = 'openai' | 'google';

const AI_PROVIDER = (process.env.AI_PROVIDER as ProviderType) || 'openai';

export function getAIProvider() {
  switch (AI_PROVIDER) {
    case 'google':
      return google('gemini-2.5-flash');
    case 'openai':
    default:
      return openai('gpt-4o-mini');
  }
}

export function createConversation() {
  return getAIProvider();
}
