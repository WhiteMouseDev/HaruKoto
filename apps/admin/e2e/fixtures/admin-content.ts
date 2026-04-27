export const statsResponse = {
  stats: [
    {
      contentType: 'vocabulary',
      needsReview: 3,
      approved: 7,
      rejected: 1,
      total: 11,
    },
    {
      contentType: 'grammar',
      needsReview: 2,
      approved: 5,
      rejected: 0,
      total: 7,
    },
    {
      contentType: 'cloze',
      needsReview: 1,
      approved: 4,
      rejected: 0,
      total: 5,
    },
    {
      contentType: 'sentence_arrange',
      needsReview: 1,
      approved: 3,
      rejected: 1,
      total: 5,
    },
    {
      contentType: 'conversation',
      needsReview: 4,
      approved: 6,
      rejected: 2,
      total: 12,
    },
  ],
};

export const vocabularyListResponse = {
  items: [
    {
      id: 'vocab-1',
      word: '食べる',
      reading: 'たべる',
      meaningKo: '먹다',
      jlptLevel: 'N5',
      reviewStatus: 'needs_review',
      createdAt: '2026-04-24T00:00:00.000Z',
    },
  ],
  total: 1,
  page: 1,
  pageSize: 20,
  totalPages: 1,
};

export const grammarListResponse = {
  items: [
    {
      id: 'grammar-1',
      pattern: '〜てもいいですか',
      explanation: '許可を求めるときに使う表現です。',
      jlptLevel: 'N5',
      reviewStatus: 'needs_review',
      createdAt: '2026-04-24T00:00:00.000Z',
    },
  ],
  total: 1,
  page: 1,
  pageSize: 20,
  totalPages: 1,
};

export const quizListResponse = {
  items: [
    {
      id: 'cloze-1',
      sentence: '私は毎朝コーヒーを___。',
      quizType: 'cloze',
      jlptLevel: 'N5',
      reviewStatus: 'needs_review',
      createdAt: '2026-04-24T00:00:00.000Z',
    },
    {
      id: 'arrange-1',
      sentence: '図書館で日本語を勉強します。',
      quizType: 'sentence_arrange',
      jlptLevel: 'N5',
      reviewStatus: 'needs_review',
      createdAt: '2026-04-24T00:05:00.000Z',
    },
  ],
  total: 2,
  page: 1,
  pageSize: 20,
  totalPages: 1,
};

export const reviewQueueResponses = {
  vocabulary: {
    ids: [{ id: 'vocab-1' }],
    total: 1,
    capped: false,
  },
  grammar: {
    ids: [{ id: 'grammar-1' }],
    total: 1,
    capped: false,
  },
  quiz: {
    ids: [
      { id: 'cloze-1', quizType: 'cloze' },
      { id: 'arrange-1', quizType: 'sentence_arrange' },
    ],
    total: 2,
    capped: false,
  },
  conversation: {
    ids: [{ id: 'conversation-1' }],
    total: 1,
    capped: false,
  },
};

export const emptyVocabularyReviewQueueResponse = {
  ids: [],
  total: 0,
  capped: false,
};

export const cappedQuizReviewQueueResponse = {
  ids: [
    { id: 'cloze-1', quizType: 'cloze' },
    { id: 'arrange-1', quizType: 'sentence_arrange' },
  ],
  total: 250,
  capped: true,
};

export const reviewQueueUnavailableResponse = {
  detail: 'Queue unavailable',
};

export const vocabularyDetailResponse = {
  id: 'vocab-1',
  word: '食べる',
  reading: 'たべる',
  meaningKo: '먹다',
  jlptLevel: 'N5',
  partOfSpeech: 'verb',
  exampleSentence: '朝ごはんを食べる。',
  exampleReading: 'あさごはんをたべる。',
  exampleTranslation: '아침밥을 먹다.',
  reviewStatus: 'needs_review',
  createdAt: '2026-04-24T00:00:00.000Z',
  updatedAt: '2026-04-24T01:00:00.000Z',
};

export const vocabularyAuditLogsResponse = [
  {
    id: 'audit-1',
    action: 'edit',
    changes: {
      meaningKo: '먹다',
    },
    reason: null,
    reviewerId: '00000000-0000-4000-8000-000000000001',
    reviewerEmail: 'reviewer@harukoto.test',
    createdAt: '2026-04-24T02:00:00.000Z',
  },
];

export const vocabularyTtsResponse = {
  audios: {
    reading: {
      audioUrl: 'https://cdn.e2e.test/audio/reading.mp3',
      provider: 'elevenlabs',
      createdAt: '2026-04-24T00:00:00.000Z',
    },
    word: null,
    example_sentence: null,
  },
};

export const grammarDetailResponse = {
  id: 'grammar-1',
  pattern: '〜てもいいですか',
  meaningKo: '~해도 될까요',
  explanation: '許可を求めるときに使う表現です。',
  exampleSentences: [
    {
      ja: 'ここで写真を撮ってもいいですか。',
      ko: '여기에서 사진을 찍어도 될까요?',
    },
  ],
  jlptLevel: 'N5',
  reviewStatus: 'needs_review',
  createdAt: '2026-04-24T00:00:00.000Z',
  updatedAt: '2026-04-24T01:00:00.000Z',
};

export const grammarAuditLogsResponse = [
  {
    id: 'audit-grammar-1',
    action: 'edit',
    changes: {
      explanation: '許可を求めるときに使う表現です。',
    },
    reason: null,
    reviewerId: '00000000-0000-4000-8000-000000000001',
    reviewerEmail: 'grammar-reviewer@harukoto.test',
    createdAt: '2026-04-24T02:10:00.000Z',
  },
];

export const grammarTtsResponse = {
  audios: {
    pattern: {
      audioUrl: 'https://cdn.e2e.test/audio/grammar-pattern.mp3',
      provider: 'elevenlabs',
      createdAt: '2026-04-24T00:00:00.000Z',
    },
    example_sentences: null,
  },
};

export const clozeDetailResponse = {
  id: 'cloze-1',
  sentence: '私は毎朝コーヒーを___。',
  translation: '나는 매일 아침 커피를 마신다.',
  correctAnswer: '飲みます',
  options: ['飲みます', '食べます', '行きます'],
  explanation: '飲み物には「飲みます」を使います。',
  jlptLevel: 'N5',
  reviewStatus: 'needs_review',
  createdAt: '2026-04-24T00:00:00.000Z',
  updatedAt: '2026-04-24T01:00:00.000Z',
};

export const clozeAuditLogsResponse = [
  {
    id: 'audit-cloze-1',
    action: 'edit',
    changes: {
      correctAnswer: '飲みます',
    },
    reason: null,
    reviewerId: '00000000-0000-4000-8000-000000000001',
    reviewerEmail: 'quiz-reviewer@harukoto.test',
    createdAt: '2026-04-24T02:30:00.000Z',
  },
];

export const clozeTtsResponse = {
  audios: {
    sentence: null,
  },
};

export const sentenceArrangeDetailResponse = {
  id: 'arrange-1',
  koreanSentence: '도서관에서 일본어를 공부합니다.',
  japaneseSentence: '図書館で日本語を勉強します。',
  tokens: ['図書館', 'で', '日本語', 'を', '勉強', 'します'],
  explanation: '場所を表す「で」を使います。',
  jlptLevel: 'N5',
  reviewStatus: 'needs_review',
  createdAt: '2026-04-24T00:05:00.000Z',
  updatedAt: '2026-04-24T01:05:00.000Z',
};

export const sentenceArrangeAuditLogsResponse = [
  {
    id: 'audit-arrange-1',
    action: 'edit',
    changes: {
      japaneseSentence: '図書館で日本語を勉強します。',
    },
    reason: null,
    reviewerId: '00000000-0000-4000-8000-000000000001',
    reviewerEmail: 'arrange-reviewer@harukoto.test',
    createdAt: '2026-04-24T02:40:00.000Z',
  },
];

export const sentenceArrangeTtsResponse = {
  audios: {
    japanese_sentence: {
      audioUrl: 'https://cdn.e2e.test/audio/sentence-arrange.mp3',
      provider: 'elevenlabs',
      createdAt: '2026-04-24T00:05:00.000Z',
    },
  },
};

export const conversationDetailResponse = {
  id: 'conversation-1',
  title: '카페 주문 연습',
  titleJa: 'カフェで注文する',
  description: '카페에서 음료를 주문하는 상황을 연습합니다.',
  situation: 'カフェで飲み物を注文する',
  yourRole: '客',
  aiRole: '店員',
  systemPrompt: '学習者が自然に注文できるように会話を進めてください。',
  keyExpressions: ['アイスコーヒーをください', '店内でお願いします'],
  category: 'daily',
  reviewStatus: 'needs_review',
  createdAt: '2026-04-24T00:00:00.000Z',
  updatedAt: '2026-04-24T01:00:00.000Z',
};

export const conversationListResponse = {
  items: [
    {
      id: 'conversation-1',
      title: '카페 주문 연습',
      category: 'DAILY',
      jlptLevel: null,
      reviewStatus: 'needs_review',
      createdAt: '2026-04-24T00:00:00.000Z',
    },
  ],
  total: 1,
  page: 1,
  pageSize: 20,
  totalPages: 1,
};

export const conversationAuditLogsResponse = [
  {
    id: 'audit-conversation-1',
    action: 'edit',
    changes: {
      situation: 'カフェで飲み物を注文する',
    },
    reason: null,
    reviewerId: '00000000-0000-4000-8000-000000000001',
    reviewerEmail: 'conversation-reviewer@harukoto.test',
    createdAt: '2026-04-24T02:20:00.000Z',
  },
];

export const conversationTtsResponse = {
  audios: {
    situation: null,
  },
};

export const supabaseUserResponse = {
  id: '00000000-0000-4000-8000-000000000001',
  aud: 'authenticated',
  role: 'authenticated',
  email: 'e2e-reviewer@harukoto.test',
  app_metadata: {
    provider: 'email',
    reviewer: true,
  },
  user_metadata: {
    full_name: 'E2E Reviewer',
  },
  created_at: '2026-01-01T00:00:00.000Z',
  updated_at: '2026-01-01T00:00:00.000Z',
};
