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
