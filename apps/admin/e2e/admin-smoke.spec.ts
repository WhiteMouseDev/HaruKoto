import { expect, test } from '@playwright/test';
import { mockAdminApi } from './helpers/mock-admin-api';

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
