export const queryKeys = {
  dashboard: ['dashboard'] as const,
  profile: ['profile'] as const,
  missions: ['missions'] as const,
  notifications: ['notifications'] as const,
  scenarios: (category: string) => ['scenarios', category] as const,
  chatHistory: ['chat-history'] as const,
  learnedWords: (params: { page: number; sort: string; search: string; filter: string }) =>
    ['learned-words', params] as const,
  wordbook: (params: { page: number; sort: string; search: string; filter: string }) =>
    ['wordbook', params] as const,
  statsHistory: (year: number) => ['stats-history', year] as const,
  quizStats: ['quiz-stats'] as const,
  quizIncomplete: ['quiz-incomplete'] as const,
  conversation: (id: string) => ['conversation', id] as const,
  kanaCharacters: (type: string, category?: string) => ['kana-characters', type, category ?? 'all'] as const,
  kanaStages: (type: string) => ['kana-stages', type] as const,
  kanaProgress: ['kana-progress'] as const,
  characters: ['characters'] as const,
  character: (id: string) => ['character', id] as const,
  characterStats: ['character-stats'] as const,
  characterFavorites: ['character-favorites'] as const,
};
