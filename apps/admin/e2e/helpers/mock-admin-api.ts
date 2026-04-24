import type { Page, Request } from '@playwright/test';
import {
  statsResponse,
  supabaseUserResponse,
  vocabularyAuditLogsResponse,
  vocabularyDetailResponse,
  vocabularyListResponse,
  vocabularyTtsResponse,
} from '../fixtures/admin-content';

export type AdminApiMockState = {
  reviewRequests: Array<unknown>;
};

async function readJsonBody(request: Request): Promise<unknown> {
  try {
    return request.postDataJSON();
  } catch {
    return null;
  }
}

export async function mockAdminApi(page: Page): Promise<AdminApiMockState> {
  const state: AdminApiMockState = {
    reviewRequests: [],
  };

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
    'https://api.e2e.test/api/v1/admin/content/vocabulary/vocab-1',
    async (route) => {
      await route.fulfill({ json: vocabularyDetailResponse });
    }
  );

  await page.route(
    'https://api.e2e.test/api/v1/admin/content/vocabulary/vocab-1/audit-logs',
    async (route) => {
      await route.fulfill({ json: vocabularyAuditLogsResponse });
    }
  );

  await page.route(
    'https://api.e2e.test/api/v1/admin/content/vocabulary/vocab-1/tts',
    async (route) => {
      await route.fulfill({ json: vocabularyTtsResponse });
    }
  );

  await page.route(
    'https://api.e2e.test/api/v1/admin/content/vocabulary/vocab-1/review',
    async (route) => {
      state.reviewRequests.push(await readJsonBody(route.request()));
      await route.fulfill({ status: 204 });
    }
  );

  await page.route(
    /https:\/\/api\.e2e\.test\/api\/v1\/admin\/content\/vocabulary(?:\?.*)?$/,
    async (route) => {
      await route.fulfill({ json: vocabularyListResponse });
    }
  );

  return state;
}
