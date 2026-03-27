'use client';

import { createClient } from '@/lib/supabase/client';

const API_URL =
  process.env.NEXT_PUBLIC_FASTAPI_URL || 'http://localhost:8000';

// ---- Types ----

export type PaginatedResponse<T> = {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
};

export type VocabularyItem = {
  id: string;
  word: string;
  reading: string;
  meaningKo: string;
  jlptLevel: string;
  reviewStatus: string;
  createdAt: string;
  updatedAt: string;
};

export type GrammarItem = {
  id: string;
  pattern: string;
  explanation: string;
  jlptLevel: string;
  reviewStatus: string;
  createdAt: string;
  updatedAt: string;
};

export type QuizItem = {
  id: string;
  sentence: string;
  quizType: string;
  jlptLevel: string;
  reviewStatus: string;
  createdAt: string;
  updatedAt: string;
};

export type ConversationItem = {
  id: string;
  title: string;
  category: string;
  jlptLevel: string | null;
  reviewStatus: string;
  createdAt: string;
  updatedAt: string;
};

export type ContentStatsItem = {
  contentType: string;
  needsReview: number;
  approved: number;
  rejected: number;
  total: number;
};

export type ContentStatsResponse = {
  stats: ContentStatsItem[];
};

// ---- Helpers ----

async function getAuthHeaders(): Promise<HeadersInit> {
  const supabase = createClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();
  const token = session?.access_token;
  return token ? { Authorization: `Bearer ${token}` } : {};
}

// ---- API functions ----

export async function fetchAdminContent<T>(
  type: string,
  params: Record<string, string | undefined>
): Promise<PaginatedResponse<T>> {
  const headers = await getAuthHeaders();

  const url = new URL(`${API_URL}/api/v1/admin/content/${type}`);
  Object.entries(params).forEach(([k, v]) => {
    if (v) url.searchParams.set(k, v);
  });

  const res = await fetch(url.toString(), { headers });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json() as Promise<PaginatedResponse<T>>;
}

export async function fetchContentStats(): Promise<ContentStatsResponse> {
  const headers = await getAuthHeaders();

  const url = new URL(`${API_URL}/api/v1/admin/content/stats`);
  const res = await fetch(url.toString(), { headers });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json() as Promise<ContentStatsResponse>;
}

// ---- Detail / Edit API functions ----

export type AuditLogEntry = {
  id: string;
  action: string;
  changes: Record<string, unknown> | null;
  reason: string | null;
  reviewerEmail: string;
  createdAt: string;
};

export async function fetchAdminContentDetail<T>(
  contentType: string,
  id: string,
): Promise<T> {
  const headers = await getAuthHeaders();
  const url = new URL(`${API_URL}/api/v1/admin/content/${contentType}/${id}`);
  const res = await fetch(url.toString(), { headers });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json() as Promise<T>;
}

export async function patchAdminContent(
  contentType: string,
  id: string,
  data: Record<string, unknown>,
): Promise<void> {
  const headers = await getAuthHeaders();
  const url = new URL(`${API_URL}/api/v1/admin/content/${contentType}/${id}`);
  const res = await fetch(url.toString(), {
    method: 'PATCH',
    headers: { ...(headers as Record<string, string>), 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
}

export async function reviewContent(
  contentType: string,
  id: string,
  action: 'approve' | 'reject',
  reason?: string,
): Promise<void> {
  const headers = await getAuthHeaders();
  const url = new URL(`${API_URL}/api/v1/admin/content/${contentType}/${id}/review`);
  const res = await fetch(url.toString(), {
    method: 'POST',
    headers: { ...(headers as Record<string, string>), 'Content-Type': 'application/json' },
    body: JSON.stringify({ action, reason }),
  });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
}

export async function batchReviewContent(
  contentType: string,
  ids: string[],
  action: 'approve' | 'reject',
  reason?: string,
): Promise<void> {
  const headers = await getAuthHeaders();
  const url = new URL(`${API_URL}/api/v1/admin/content/batch-review`);
  const res = await fetch(url.toString(), {
    method: 'POST',
    headers: { ...(headers as Record<string, string>), 'Content-Type': 'application/json' },
    body: JSON.stringify({ contentType, ids, action, reason }),
  });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
}

export async function fetchAuditLogs(
  contentType: string,
  id: string,
): Promise<AuditLogEntry[]> {
  const headers = await getAuthHeaders();
  const url = new URL(`${API_URL}/api/v1/admin/content/${contentType}/${id}/audit-logs`);
  const res = await fetch(url.toString(), { headers });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json() as Promise<AuditLogEntry[]>;
}

// ---- TTS API functions ----

// IMPORTANT: Field names are snake_case to match FastAPI's Pydantic JSON serialization.
// FastAPI AdminTtsResponse has `audio_url`, `field`, `provider` — NOT camelCase.
export type TtsAudioResponse = {
  audio_url: string | null;
  field: string | null;
  provider: string | null;
};

export async function fetchTtsAudio(
  contentType: string,
  itemId: string,
): Promise<TtsAudioResponse> {
  const headers = await getAuthHeaders();
  const res = await fetch(
    `${API_URL}/api/v1/admin/content/${contentType}/${itemId}/tts`,
    { headers },
  );
  if (!res.ok) throw new Error('Failed to fetch TTS audio');
  return res.json() as Promise<TtsAudioResponse>;
}

export async function regenerateTts(
  contentType: string,
  itemId: string,
  field: string,
): Promise<TtsAudioResponse> {
  const headers = await getAuthHeaders();
  const res = await fetch(`${API_URL}/api/v1/admin/tts/regenerate`, {
    method: 'POST',
    headers: {
      ...(headers as Record<string, string>),
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      content_type: contentType,
      item_id: itemId,
      field,
    }),
  });
  if (res.status === 429) {
    const data = (await res.json()) as { detail?: string };
    throw new Error(data.detail ?? 'Cooldown active');
  }
  if (!res.ok) throw new Error('TTS regeneration failed');
  return res.json() as Promise<TtsAudioResponse>;
}
