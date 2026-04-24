import type { Page, Request } from '@playwright/test';
import {
  conversationAuditLogsResponse,
  conversationDetailResponse,
  conversationTtsResponse,
  grammarAuditLogsResponse,
  grammarDetailResponse,
  grammarTtsResponse,
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

type ContentDetailMock = {
  contentType: string;
  itemId: string;
  detail: unknown;
  auditLogs: unknown;
  tts: unknown;
};

const contentDetailMocks: ContentDetailMock[] = [
  {
    contentType: 'vocabulary',
    itemId: 'vocab-1',
    detail: vocabularyDetailResponse,
    auditLogs: vocabularyAuditLogsResponse,
    tts: vocabularyTtsResponse,
  },
  {
    contentType: 'grammar',
    itemId: 'grammar-1',
    detail: grammarDetailResponse,
    auditLogs: grammarAuditLogsResponse,
    tts: grammarTtsResponse,
  },
  {
    contentType: 'conversation',
    itemId: 'conversation-1',
    detail: conversationDetailResponse,
    auditLogs: conversationAuditLogsResponse,
    tts: conversationTtsResponse,
  },
];

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

  for (const content of contentDetailMocks) {
    const baseUrl = `https://api.e2e.test/api/v1/admin/content/${content.contentType}/${content.itemId}`;

    await page.route(baseUrl, async (route) => {
      await route.fulfill({ json: content.detail });
    });

    await page.route(`${baseUrl}/audit-logs`, async (route) => {
      await route.fulfill({ json: content.auditLogs });
    });

    await page.route(`${baseUrl}/tts`, async (route) => {
      await route.fulfill({ json: content.tts });
    });

    await page.route(`${baseUrl}/review`, async (route) => {
      state.reviewRequests.push(await readJsonBody(route.request()));
      await route.fulfill({ status: 204 });
    });
  }

  await page.route(
    /https:\/\/api\.e2e\.test\/api\/v1\/admin\/content\/vocabulary(?:\?.*)?$/,
    async (route) => {
      await route.fulfill({ json: vocabularyListResponse });
    }
  );

  return state;
}
