import { expect, test } from '@playwright/test';
import { mockAdminApi } from './helpers/mock-admin-api';

test('renders vocabulary detail with audit history and per-field TTS state', async ({
  page,
}) => {
  await mockAdminApi(page);

  await page.goto('/vocabulary/vocab-1');

  await expect(page.getByRole('heading', { name: '単語を編集' })).toBeVisible();
  await expect(
    page.getByRole('textbox', { name: '単語', exact: true })
  ).toHaveValue('食べる');
  await expect(
    page.getByRole('textbox', { name: '読み方', exact: true })
  ).toHaveValue('たべる');
  await expect(page.getByLabel('意味（韓国語）')).toHaveValue('먹다');
  await expect(page.getByText('変更履歴')).toBeVisible();
  await expect(page.getByText('reviewer@harukoto.test')).toBeVisible();

  await expect(
    page.getByRole('button', { name: '再生', exact: true })
  ).toBeVisible();
  await expect(page.getByText('オーディオなし')).toHaveCount(2);
  await expect(
    page.getByRole('button', { name: '生成する' }).first()
  ).toBeVisible();
});

test('submits approve and reject review actions from vocabulary detail', async ({
  page,
}) => {
  const api = await mockAdminApi(page);

  await page.goto('/vocabulary/vocab-1');

  await page.getByRole('button', { name: '承認' }).click();
  await expect
    .poll(() => api.reviewRequests)
    .toContainEqual({
      action: 'approve',
    });

  await page.getByRole('button', { name: '差し戻し' }).click();
  await page.getByLabel('差し戻し理由').fill('例文の自然さを確認してください');
  await page.getByRole('button', { name: '差し戻す' }).click();

  await expect
    .poll(() => api.reviewRequests)
    .toContainEqual({
      action: 'reject',
      reason: '例文の自然さを確認してください',
    });
});

test('opens the TTS generate confirmation dialog for a missing field', async ({
  page,
}) => {
  await mockAdminApi(page);

  await page.goto('/vocabulary/vocab-1');

  await page.getByRole('button', { name: '生成する' }).first().click();

  await expect(
    page.getByRole('heading', {
      name: '食べるのTTSを再生成しますか？',
    })
  ).toBeVisible();
  await expect(page.getByRole('button', { name: '再生成する' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'キャンセル' })).toBeVisible();
});
