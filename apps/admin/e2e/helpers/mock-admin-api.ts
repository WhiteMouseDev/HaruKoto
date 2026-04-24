import type { Page, Request } from '@playwright/test';
import {
  conversationAuditLogsResponse,
  conversationDetailResponse,
  conversationListResponse,
  conversationTtsResponse,
  grammarAuditLogsResponse,
  grammarDetailResponse,
  grammarListResponse,
  grammarTtsResponse,
  statsResponse,
  supabaseUserResponse,
  vocabularyAuditLogsResponse,
  vocabularyDetailResponse,
  vocabularyListResponse,
  vocabularyTtsResponse,
} from '../fixtures/admin-content';

type ContentListRequest = {
  contentType: string;
  searchParams: Record<string, string>;
};

export type AdminApiMockState = {
  listRequests: ContentListRequest[];
  reviewRequests: Array<unknown>;
};

type ContentListMock = {
  contentType: string;
  list: unknown;
};

type ContentDetailMock = {
  contentType: string;
  itemId: string;
  detail: unknown;
  auditLogs: unknown;
  tts: unknown;
};

const contentListMocks: ContentListMock[] = [
  {
    contentType: 'vocabulary',
    list: vocabularyListResponse,
  },
  {
    contentType: 'grammar',
    list: grammarListResponse,
  },
  {
    contentType: 'conversation',
    list: conversationListResponse,
  },
];

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

function readSearchParams(request: Request): Record<string, string> {
  return Object.fromEntries(new URL(request.url()).searchParams.entries());
}

export async function mockAdminApi(page: Page): Promise<AdminApiMockState> {
  const state: AdminApiMockState = {
    listRequests: [],
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

  for (const content of contentListMocks) {
    await page.route(
      new RegExp(
        `https:\\/\\/api\\.e2e\\.test\\/api\\/v1\\/admin\\/content\\/${content.contentType}(?:\\?.*)?$`
      ),
      async (route) => {
        state.listRequests.push({
          contentType: content.contentType,
          searchParams: readSearchParams(route.request()),
        });
        await route.fulfill({ json: content.list });
      }
    );
  }

  return state;
}
