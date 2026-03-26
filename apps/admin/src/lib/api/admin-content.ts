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
