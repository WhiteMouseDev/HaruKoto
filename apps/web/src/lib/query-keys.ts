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
};
