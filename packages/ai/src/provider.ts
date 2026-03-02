import { openai } from '@ai-sdk/openai';
import { google } from '@ai-sdk/google';

type ProviderType = 'openai' | 'google';

const AI_PROVIDER = (process.env.AI_PROVIDER as ProviderType) || 'openai';

export function getAIProvider() {
  switch (AI_PROVIDER) {
    case 'google':
      return google('gemini-1.5-flash');
    case 'openai':
    default:
      return openai('gpt-4o-mini');
  }
}

export function createConversation() {
  return getAIProvider();
}
