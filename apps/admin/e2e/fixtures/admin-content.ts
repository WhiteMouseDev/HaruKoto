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
