import { expect, test, type Page } from '@playwright/test';
import {
  cappedQuizReviewQueueResponse,
  emptyVocabularyReviewQueueResponse,
  reviewQueueUnavailableResponse,
} from './fixtures/admin-content';
import {
  mockAdminApi,
  mockReviewQueueResponse,
  type AdminApiMockState,
} from './helpers/mock-admin-api';

let apiState: AdminApiMockState;

test.beforeEach(async ({ page }) => {
  apiState = await mockAdminApi(page);
});

function latestListParam(contentType: string, key: string): string {
  const requests = apiState.listRequests.filter(
    (request) => request.contentType === contentType
  );
  const latestRequest = requests[requests.length - 1];
  return latestRequest?.searchParams[key] ?? '';
}

function latestQueueParam(contentType: string, key: string): string {
  const requests = apiState.queueRequests.filter(
    (request) => request.contentType === contentType
  );
  const latestRequest = requests[requests.length - 1];
  return latestRequest?.searchParams[key] ?? '';
}

async function mockTtsReviewApis(page: Page) {
  const batch = {
    batchId: 'tts-review-admin-vocabulary-fields',
    status: 'draft',
    reviewSurface: 'admin_existing_tts',
    sourceKind: 'topic_vocabulary_fields',
    targetIds: ['tts-vocabulary-word', 'tts-vocabulary-reading'],
    targetCount: 2,
    requiredBeforePublishCount: 2,
    generationStatusSummary: {
      missing: 2,
      generated: 0,
      approved: 0,
      rejected: 0,
      stale: 0,
    },
    adminExport: {
      mode: 'existing_admin_tts_fields',
      contentType: 'vocabulary',
      fieldMappings: [
        { audioField: 'word', adminField: 'word' },
        { audioField: 'reading', adminField: 'reading' },
      ],
      blockers: [],
    },
    reviewerChecklist: ['candidate mapping'],
    notesKo: 'review',
  };
  const targets = [
    {
      targetId: 'tts-vocabulary-word',
      topicId: 'topic-personal-pronouns',
      audioTargetType: 'vocabulary',
      audioField: 'word',
      textSource: 'curriculum-topics:topic-personal-pronouns:word',
      defaultSpeed: 0.9,
      requiredBeforePublish: true,
      preferredVoiceId: null,
      generationStatus: 'missing',
      cacheKeyStrategy: 'provider-model-speed-field-text-hash-v1',
      notesKo: 'review',
    },
    {
      targetId: 'tts-vocabulary-reading',
      topicId: 'topic-personal-pronouns',
      audioTargetType: 'vocabulary',
      audioField: 'reading',
      textSource: 'curriculum-topics:topic-personal-pronouns:reading',
      defaultSpeed: 0.9,
      requiredBeforePublish: true,
      preferredVoiceId: 'japanese_female_1',
      generationStatus: 'missing',
      cacheKeyStrategy: 'provider-model-speed-field-text-hash-v1',
      notesKo: 'review',
    },
  ];
  const planItems = targets.map((target) => ({
    target,
    adminContentType: 'vocabulary',
    adminField: target.audioField,
    operationStatus: 'manual_mapping_required',
    existingAdminTtsSupported: true,
    candidates: [
      {
        contentType: 'vocabulary',
        lookupType: 'vocabulary_level_order',
        topicId: target.topicId,
        adminField: target.audioField,
        jlptLevel: 'N5',
        grammarOrder: null,
        vocabularyOrder: 605,
        contentLabel: '私',
        contentReading: 'わたし',
        meaningKo: '저',
        matchType: 'partial',
        noteKo: 'review',
      },
    ],
    blockerCodes: ['topic_vocabulary_mapping_required'],
    notesKo: 'review',
  }));
  const previewItems = targets.map((target) => ({
    target,
    adminContentType: 'vocabulary',
    adminField: target.audioField,
    lookupStatus: 'not_lookup_ready',
    canGenerateWithCurrentService: false,
    candidate: planItems[0].candidates[0],
    contentItemId: null,
    contentLabel: null,
    notesKo: 'review',
  }));
  const baseUrl =
    'https://api.e2e.test/api/v1/admin/content/tts/review-batches';

  await page.route(new RegExp(`${baseUrl}(?:\\?.*)?$`), async (route) => {
    await route.fulfill({
      json: {
        schemaVersion: 1,
        status: 'draft',
        summary: {
          totalBatches: 1,
          totalTargets: 2,
          adminReadyTargets: 2,
          extensionRequiredTargets: 0,
          requiredBeforePublishTargets: 2,
          generationStatusSummary: batch.generationStatusSummary,
        },
        batches: [batch],
      },
    });
  });
  await page.route(`${baseUrl}/${batch.batchId}/targets`, async (route) => {
    await route.fulfill({
      json: {
        schemaVersion: 1,
        status: 'draft',
        batch,
        targets,
      },
    });
  });
  await page.route(
    `${baseUrl}/${batch.batchId}/generation-plan`,
    async (route) => {
      await route.fulfill({
        json: {
          schemaVersion: 1,
          status: 'draft',
          batch,
          summary: {
            totalTargets: 2,
            supportedTargets: 2,
            readyAfterDbLookupTargets: 0,
            manualMappingRequiredTargets: 2,
            blockedTargets: 0,
          },
          items: planItems,
        },
      });
    }
  );
  await page.route(
    `${baseUrl}/${batch.batchId}/execute-preview`,
    async (route) => {
      await route.fulfill({
        json: {
          schemaVersion: 1,
          status: 'draft',
          batch,
          summary: {
            totalTargets: 2,
            resolvedTargets: 0,
            missingTargets: 0,
            ambiguousTargets: 0,
            notLookupReadyTargets: 2,
            blockedTargets: 0,
            generatableTargets: 0,
          },
          items: previewItems,
        },
      });
    }
  );
}

test('renders the login page without a live Supabase session', async ({
  page,
}) => {
  await page.goto('/login');

  await expect(
    page.getByRole('heading', { name: 'HaruKoto 管理者' })
  ).toBeVisible();
  await expect(page.getByLabel('メールアドレス')).toBeVisible();
  await expect(page.getByLabel('パスワード')).toBeVisible();
  await expect(page.getByRole('button', { name: 'ログイン' })).toBeVisible();
});

test('renders the protected dashboard with mocked admin stats', async ({
  page,
}) => {
  await page.goto('/dashboard');

  await expect(
    page.getByRole('heading', { name: 'ダッシュボード' })
  ).toBeVisible();
  await expect(page.getByText('こんにちは、Reviewerさん')).toBeVisible();
  await expect(page.getByText('E2E Reviewer')).toBeVisible();
  await expect(
    page.getByRole('navigation', { name: 'メインナビゲーション' })
  ).toBeVisible();
  const mainContent = page.getByLabel('メインコンテンツ');
  await expect(mainContent.getByText('単語')).toBeVisible();
  await expect(mainContent.getByText('3').first()).toBeVisible();
  await expect(mainContent.getByText('64% 承認済み')).toBeVisible();
});

test('renders the TTS review manual mapping queue', async ({ page }) => {
  await mockTtsReviewApis(page);

  await page.goto('/tts-review');
  await expect(
    page.getByRole('heading', { name: 'TTS確認バッチ' })
  ).toBeVisible();

  await page.getByRole('button', { name: /対象を見る/ }).click();

  await expect(page.getByText('手動マッピングキュー')).toBeVisible();
  await expect(page.getByText('語彙topicマッピング必要').first()).toBeVisible();
  await expect(page.getByText('N5 #605 私').first()).toBeVisible();
  await expect(page.getByText('わたし · 저').first()).toBeVisible();
});

test('renders the vocabulary list and keeps filter state in the URL', async ({
  page,
}) => {
  await page.goto('/vocabulary');

  await expect(page.getByRole('heading', { name: '単語一覧' })).toBeVisible();
  await expect(page.getByRole('cell', { name: '食べる' })).toBeVisible();
  await expect(page.getByRole('cell', { name: 'たべる' })).toBeVisible();
  await expect(page.getByRole('cell', { name: '먹다' })).toBeVisible();
  await expect(page.getByRole('link', { name: '詳細' })).toHaveAttribute(
    'href',
    '/vocabulary/vocab-1'
  );

  await page.getByLabel('JLPTレベル').selectOption('N5');
  await expect(page).toHaveURL(/jlpt=N5/);
  await expect
    .poll(() => latestListParam('vocabulary', 'jlpt_level'))
    .toBe('N5');
});

test('filters the grammar list and opens the detail page', async ({ page }) => {
  await page.goto('/grammar');

  await expect(page.getByRole('heading', { name: '文法一覧' })).toBeVisible();
  await expect(
    page.getByRole('cell', { name: '〜てもいいですか' })
  ).toBeVisible();
  await expect(
    page.getByRole('cell', { name: '許可を求めるときに使う表現です。' })
  ).toBeVisible();

  await page.getByLabel('検索').fill('写真');
  await expect.poll(() => latestListParam('grammar', 'search')).toBe('写真');
  await expect(page).toHaveURL(/q=/);

  await page.getByLabel('ステータス').selectOption('needs_review');
  await expect
    .poll(() => latestListParam('grammar', 'review_status'))
    .toBe('needs_review');
  await expect(page).toHaveURL(/status=needs_review/);

  await page.getByRole('link', { name: '詳細' }).click();
  await expect(page).toHaveURL(/\/grammar\/grammar-1$/);
  await expect(page.getByRole('heading', { name: '文法を編集' })).toBeVisible();
});

test('filters the quiz list and preserves quiz type in detail links', async ({
  page,
}) => {
  await page.goto('/quiz');

  await expect(page.getByRole('heading', { name: 'クイズ一覧' })).toBeVisible();
  const clozeRow = page
    .getByRole('row')
    .filter({ hasText: '私は毎朝コーヒーを___。' });
  const arrangeRow = page
    .getByRole('row')
    .filter({ hasText: '図書館で日本語を勉強します。' });
  await expect(clozeRow.getByText('cloze')).toBeVisible();
  await expect(arrangeRow.getByText('sentence-arrange')).toBeVisible();
  await expect(clozeRow.getByRole('link', { name: '詳細' })).toHaveAttribute(
    'href',
    '/quiz/cloze-1?type=cloze'
  );
  await expect(arrangeRow.getByRole('link', { name: '詳細' })).toHaveAttribute(
    'href',
    '/quiz/arrange-1?type=sentence_arrange'
  );

  await page.getByLabel('検索').fill('図書館');
  await expect.poll(() => latestListParam('quiz', 'search')).toBe('図書館');
  await expect(page).toHaveURL(/q=/);

  await page.getByLabel('JLPTレベル').selectOption('N5');
  await expect.poll(() => latestListParam('quiz', 'jlpt_level')).toBe('N5');
  await expect(page).toHaveURL(/jlpt=N5/);

  await page.getByLabel('ステータス').selectOption('needs_review');
  await expect
    .poll(() => latestListParam('quiz', 'review_status'))
    .toBe('needs_review');
  await expect(page).toHaveURL(/status=needs_review/);

  await arrangeRow.getByRole('link', { name: '詳細' }).click();
  await expect(page).toHaveURL(/\/quiz\/arrange-1\?type=sentence_arrange$/);
  await expect(
    page.getByRole('heading', { name: 'クイズを編集' })
  ).toBeVisible();
});

test('starts the quiz review queue and navigates between queued items', async ({
  page,
}) => {
  await page.goto('/quiz?jlpt=N5');

  await page.getByRole('button', { name: 'レビュー開始' }).click();

  await expect.poll(() => latestQueueParam('quiz', 'jlpt_level')).toBe('N5');
  await expect(page).toHaveURL(/\/quiz\/cloze-1\?/);
  await expect(page).toHaveURL(/type=cloze/);
  await expect(page).toHaveURL(/qi=0/);
  await expect(page).toHaveURL(/queue=/);
  await expect(page.getByText('1 / 2')).toBeVisible();
  await expect(page.getByRole('button', { name: '前へ' })).toBeDisabled();
  await expect(page.getByRole('button', { name: '次へ' })).toBeEnabled();

  await page.getByRole('button', { name: '次へ' }).click();
  await expect(page).toHaveURL(/\/quiz\/arrange-1\?/);
  await expect(page).toHaveURL(/type=sentence_arrange/);
  await expect(page).toHaveURL(/qi=1/);
  await expect(page.getByText('2 / 2')).toBeVisible();
  await expect(page.getByRole('button', { name: '前へ' })).toBeEnabled();
  await expect(page.getByRole('button', { name: '次へ' })).toBeDisabled();

  await page.getByRole('button', { name: '前へ' }).click();
  await expect(page).toHaveURL(/\/quiz\/cloze-1\?/);
  await expect(page).toHaveURL(/type=cloze/);
  await expect(page).toHaveURL(/qi=0/);
  await expect(page.getByText('1 / 2')).toBeVisible();

  await page.getByRole('button', { name: 'キューを終了' }).click();
  await expect(page).toHaveURL(/\/quiz$/);
  await expect(page.getByRole('heading', { name: 'クイズ一覧' })).toBeVisible();
});

test('auto-advances after quiz queue review actions and exits after the final item', async ({
  page,
}) => {
  await page.goto('/quiz?jlpt=N5');

  await page.getByRole('button', { name: 'レビュー開始' }).click();
  await expect(page).toHaveURL(/\/quiz\/cloze-1\?/);
  await expect(page.getByText('1 / 2')).toBeVisible();

  await page.getByRole('button', { name: '承認' }).click();
  await expect
    .poll(() => apiState.reviewRequests)
    .toContainEqual({ action: 'approve' });
  await expect(page).toHaveURL(/\/quiz\/arrange-1\?/);
  await expect(page).toHaveURL(/type=sentence_arrange/);
  await expect(page).toHaveURL(/qi=1/);
  await expect(page.getByText('2 / 2')).toBeVisible();

  await page.getByRole('button', { name: '差し戻し' }).click();
  await page.getByLabel('差し戻し理由').fill('語順の説明を補ってください');
  await page.getByRole('button', { name: '差し戻す' }).click();

  await expect
    .poll(() => apiState.reviewRequests)
    .toEqual([
      { action: 'approve' },
      { action: 'reject', reason: '語順の説明を補ってください' },
    ]);
  await expect(page).toHaveURL(/\/quiz$/);
  await expect(page.getByRole('heading', { name: 'クイズ一覧' })).toBeVisible();
});

test('shows an empty queue message without leaving the vocabulary list', async ({
  page,
}) => {
  await mockReviewQueueResponse(page, apiState, 'vocabulary', {
    json: emptyVocabularyReviewQueueResponse,
  });

  await page.goto('/vocabulary?jlpt=N5');

  await page.getByRole('button', { name: 'レビュー開始' }).click();
  await expect
    .poll(() => latestQueueParam('vocabulary', 'jlpt_level'))
    .toBe('N5');
  await expect(page.getByText('レビュー待ち項目はありません')).toBeVisible();
  await expect(page).toHaveURL(/\/vocabulary\?jlpt=N5$/);
  await expect(page.getByRole('heading', { name: '単語一覧' })).toBeVisible();
});

test('exits automatically after approving a single-item vocabulary queue', async ({
  page,
}) => {
  await page.goto('/vocabulary?jlpt=N5');

  await page.getByRole('button', { name: 'レビュー開始' }).click();
  await expect
    .poll(() => latestQueueParam('vocabulary', 'jlpt_level'))
    .toBe('N5');
  await expect(page).toHaveURL(/\/vocabulary\/vocab-1\?/);
  await expect(page).toHaveURL(/qi=0/);
  await expect(page.getByText('1 / 1')).toBeVisible();

  await page.getByRole('button', { name: '承認' }).click();
  await expect
    .poll(() => apiState.reviewRequests)
    .toEqual([{ action: 'approve' }]);
  await expect(page).toHaveURL(/\/vocabulary$/);
  await expect(page.getByRole('heading', { name: '単語一覧' })).toBeVisible();
});

test('shows capped queue message while opening the first quiz item', async ({
  page,
}) => {
  await mockReviewQueueResponse(page, apiState, 'quiz', {
    json: cappedQuizReviewQueueResponse,
  });

  await page.goto('/quiz?jlpt=N5');

  await page.getByRole('button', { name: 'レビュー開始' }).click();
  await expect.poll(() => latestQueueParam('quiz', 'jlpt_level')).toBe('N5');
  await expect(
    page.getByText('レビューキューは最初の200件のみ表示しています')
  ).toBeVisible();
  await expect(page).toHaveURL(/\/quiz\/cloze-1\?/);
  await expect(page).toHaveURL(/type=cloze/);
  await expect(page).toHaveURL(/qi=0/);
  await expect(page.getByText('1 / 2')).toBeVisible();
});

test('shows an error and stays on the quiz list when queue loading fails', async ({
  page,
}) => {
  await mockReviewQueueResponse(page, apiState, 'quiz', {
    status: 500,
    json: reviewQueueUnavailableResponse,
  });

  await page.goto('/quiz?jlpt=N5');

  await page.getByRole('button', { name: 'レビュー開始' }).click();
  await expect.poll(() => latestQueueParam('quiz', 'jlpt_level')).toBe('N5');
  await expect(
    page.getByText(
      'レビューキューの読み込みに失敗しました。ページを再読み込みしてください。'
    )
  ).toBeVisible();
  await expect(page).toHaveURL(/\/quiz\?jlpt=N5$/);
  await expect(
    page.getByRole('button', { name: 'レビュー開始' })
  ).toBeEnabled();
});

test('splits quiz bulk approve into canonical content-type batches', async ({
  page,
}) => {
  await page.goto('/quiz');

  await page.getByLabel('行 cloze-1 を選択').click();
  await page.getByLabel('行 arrange-1 を選択').click();
  await expect(page.getByText('2件選択中')).toBeVisible();

  await page.getByRole('button', { name: '一括承認' }).click();

  await expect
    .poll(() =>
      apiState.batchReviewRequests
        .map((request) => JSON.stringify(request))
        .sort()
    )
    .toEqual([
      JSON.stringify({
        contentType: 'cloze',
        ids: ['cloze-1'],
        action: 'approve',
      }),
      JSON.stringify({
        contentType: 'sentence_arrange',
        ids: ['arrange-1'],
        action: 'approve',
      }),
    ]);
  await expect(page.getByText('2件選択中')).toBeHidden();
});

test('submits non-quiz bulk reject with a review reason', async ({ page }) => {
  await page.goto('/vocabulary');

  await page.getByLabel('行 vocab-1 を選択').click();
  await expect(page.getByText('1件選択中')).toBeVisible();

  await page.getByRole('button', { name: '一括差し戻し' }).click();
  await page.getByLabel('差し戻し理由').fill('例文をもう一度確認してください');
  await page.getByRole('button', { name: '差し戻す' }).click();

  await expect
    .poll(() => apiState.batchReviewRequests)
    .toEqual([
      {
        contentType: 'vocabulary',
        ids: ['vocab-1'],
        action: 'reject',
        reason: '例文をもう一度確認してください',
      },
    ]);
  await expect(page.getByText('1件選択中')).toBeHidden();
  await expect(page.getByLabel('差し戻し理由')).toBeHidden();
});

test('filters the conversation list and opens the detail page', async ({
  page,
}) => {
  await page.goto('/conversation');

  await expect(
    page.getByRole('heading', { name: '会話シナリオ一覧' })
  ).toBeVisible();
  await expect(
    page.getByRole('cell', { name: '카페 주문 연습' })
  ).toBeVisible();
  await expect(page.getByRole('cell', { name: '日常' })).toBeVisible();
  await expect(page.getByLabel('JLPTレベル')).toBeHidden();

  await page.getByLabel('検索').fill('카페');
  await expect
    .poll(() => latestListParam('conversation', 'search'))
    .toBe('카페');
  await expect(page).toHaveURL(/q=/);

  await page.getByLabel('カテゴリ').selectOption('DAILY');
  await expect
    .poll(() => latestListParam('conversation', 'category'))
    .toBe('DAILY');
  await expect(page).toHaveURL(/category=DAILY/);

  await page.getByLabel('ステータス').selectOption('needs_review');
  await expect
    .poll(() => latestListParam('conversation', 'review_status'))
    .toBe('needs_review');
  await expect(page).toHaveURL(/status=needs_review/);

  await page.getByRole('link', { name: '詳細' }).click();
  await expect(page).toHaveURL(/\/conversation\/conversation-1$/);
  await expect(
    page.getByRole('heading', { name: '会話シナリオを編集' })
  ).toBeVisible();
});
