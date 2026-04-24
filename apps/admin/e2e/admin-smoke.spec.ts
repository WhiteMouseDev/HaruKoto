import { expect, type Page, test } from '@playwright/test';

const statsResponse = {
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

const vocabularyResponse = {
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

const supabaseUserResponse = {
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

async function mockAdminApi(page: Page): Promise<void> {
  await page.route(
    'https://example.supabase.co/auth/v1/user',
    async (route) => {
      await route.fulfill({ json: supabaseUserResponse });
    }
  );

  await page.route(
    'https://api.e2e.test/api/v1/admin/content/stats',
    async (route) => {
      await route.fulfill({ json: statsResponse });
    }
  );

  await page.route(
    /https:\/\/api\.e2e\.test\/api\/v1\/admin\/content\/vocabulary(?:\?.*)?$/,
    async (route) => {
      await route.fulfill({ json: vocabularyResponse });
    }
  );
}

test.beforeEach(async ({ page }) => {
  await mockAdminApi(page);
});

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
});
