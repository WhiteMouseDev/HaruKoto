import { expect, test } from '@playwright/test';
import { mockAdminApi, type AdminApiMockState } from './helpers/mock-admin-api';

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

test('shows an error and stays on the quiz list when queue loading fails', async ({
  page,
}) => {
  let queueSearchParams: Record<string, string> = {};
  await page.route(
    /https:\/\/api\.e2e\.test\/api\/v1\/admin\/content\/review-queue\/quiz(?:\?.*)?$/,
    async (route) => {
      queueSearchParams = Object.fromEntries(
        new URL(route.request().url()).searchParams.entries()
      );
      await route.fulfill({
        status: 500,
        json: { detail: 'Queue unavailable' },
      });
    }
  );

  await page.goto('/quiz?jlpt=N5');

  await page.getByRole('button', { name: 'レビュー開始' }).click();
  await expect.poll(() => queueSearchParams.jlpt_level ?? '').toBe('N5');
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
