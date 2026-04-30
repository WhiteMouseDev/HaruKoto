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
};

export type GrammarItem = {
  id: string;
  pattern: string;
  explanation: string;
  jlptLevel: string;
  reviewStatus: string;
  createdAt: string;
};

export type QuizItem = {
  id: string;
  sentence: string;
  quizType: string;
  jlptLevel: string;
  reviewStatus: string;
  createdAt: string;
};

export type ConversationItem = {
  id: string;
  title: string;
  category: string;
  jlptLevel: string | null;
  reviewStatus: string;
  createdAt: string;
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

// FastAPI errors come back as { detail: string | ValidationError[] }. Extract the
// human-readable string when present so toasts surface the real reason (e.g. "TTS
// 生成に失敗しました") instead of "API error: 500". Falls back to status code when
// the body is missing or non-JSON.
async function throwIfNotOk(res: Response): Promise<void> {
  if (res.ok) return;
  let detail: string | null = null;
  try {
    const body = (await res.clone().json()) as { detail?: unknown };
    if (typeof body.detail === 'string') detail = body.detail;
  } catch {
    // Non-JSON body (HTML error page, empty 502, etc.) — fall through to status.
  }
  throw new Error(detail ?? `API error: ${res.status}`);
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
  await throwIfNotOk(res);
  return res.json() as Promise<PaginatedResponse<T>>;
}

export async function fetchContentStats(): Promise<ContentStatsResponse> {
  const headers = await getAuthHeaders();

  const url = new URL(`${API_URL}/api/v1/admin/content/stats`);
  const res = await fetch(url.toString(), { headers });
  await throwIfNotOk(res);
  return res.json() as Promise<ContentStatsResponse>;
}

// ---- Detail / Edit API functions ----

export type AuditLogEntry = {
  id: string;
  action: string;
  changes: Record<string, unknown> | null;
  reason: string | null;
  reviewerId: string;
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
  await throwIfNotOk(res);
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
  await throwIfNotOk(res);
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
  await throwIfNotOk(res);
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
  await throwIfNotOk(res);
}

// Quiz uses compound path (quiz/cloze, quiz/sentence-arrange) for detail/patch/review,
// but audit_logs DB records store the canonical single-segment type (cloze, sentence_arrange).
// The audit-logs endpoint is also defined with single-segment content_type, so callers
// must normalize before hitting it.
function toAuditContentType(contentType: string): string {
  if (contentType === 'quiz/cloze') return 'cloze';
  if (contentType === 'quiz/sentence-arrange') return 'sentence_arrange';
  return contentType;
}

export async function fetchAuditLogs(
  contentType: string,
  id: string,
): Promise<AuditLogEntry[]> {
  const headers = await getAuthHeaders();
  const auditType = toAuditContentType(contentType);
  const url = new URL(`${API_URL}/api/v1/admin/content/${auditType}/${id}/audit-logs`);
  const res = await fetch(url.toString(), { headers });
  await throwIfNotOk(res);
  return res.json() as Promise<AuditLogEntry[]>;
}

// ---- TTS API functions ----

// AdminTtsResponse extends CamelModel — FastAPI returns camelCase JSON.
export type TtsAudioResponse = {
  audioUrl: string | null;
  field: string | null;
  provider: string | null;
};

export type AudioFieldInfo = {
  audioUrl: string;
  provider: string;
  createdAt: string;
};

export type TtsAudioMapResponse = {
  audios: Record<string, AudioFieldInfo | null>;
};

export async function fetchTtsAudio(
  contentType: string,
  itemId: string,
): Promise<TtsAudioMapResponse> {
  const headers = await getAuthHeaders();
  const res = await fetch(
    `${API_URL}/api/v1/admin/content/${contentType}/${itemId}/tts`,
    { headers },
  );
  await throwIfNotOk(res);
  return res.json() as Promise<TtsAudioMapResponse>;
}

export async function regenerateTts(
  contentType: string,
  itemId: string,
  field: string,
): Promise<TtsAudioResponse> {
  const headers = await getAuthHeaders();
  const res = await fetch(`${API_URL}/api/v1/admin/content/tts/regenerate`, {
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
  await throwIfNotOk(res);
  return res.json() as Promise<TtsAudioResponse>;
}

export type TtsReviewSurface =
  | 'admin_existing_tts'
  | 'admin_extension_required';

export type TtsGenerationStatusSummary = {
  missing: number;
  generated: number;
  approved: number;
  rejected: number;
  stale: number;
};

export type TtsReviewFieldMapping = {
  audioField:
    | 'word'
    | 'reading'
    | 'japanese'
    | 'pattern'
    | 'example_sentence'
    | 'script_line'
    | 'question_prompt';
  adminField: string;
};

export type TtsReviewExportInfo = {
  mode: 'existing_admin_tts_fields' | 'requires_admin_extension';
  contentType:
    | 'vocabulary'
    | 'grammar'
    | 'kana'
    | 'example_sentence_pool'
    | 'lesson_seed_candidate';
  fieldMappings: TtsReviewFieldMapping[];
  blockers: Array<
    | 'admin_tts_field_gap'
    | 'admin_content_type_gap'
    | 'lesson_seed_admin_surface_gap'
  >;
};

export type TtsReviewBatchItem = {
  batchId: string;
  status: 'draft' | 'review' | 'approved';
  reviewSurface: TtsReviewSurface;
  sourceKind:
    | 'topic_vocabulary_fields'
    | 'topic_grammar_fields'
    | 'topic_grammar_question_prompts'
    | 'topic_kana_fields'
    | 'example_sentence_fields'
    | 'seed_candidate_script_lines'
    | 'seed_candidate_question_prompts';
  targetIds: string[];
  targetCount: number;
  requiredBeforePublishCount: number;
  generationStatusSummary: TtsGenerationStatusSummary;
  adminExport: TtsReviewExportInfo;
  reviewerChecklist: string[];
  notesKo: string;
};

export type TtsReviewTargetItem = {
  targetId: string;
  topicId: string;
  audioTargetType:
    | 'vocabulary'
    | 'grammar'
    | 'kana'
    | 'lesson_script'
    | 'example_sentence'
    | 'question_prompt';
  audioField:
    | 'word'
    | 'reading'
    | 'japanese'
    | 'pattern'
    | 'example_sentence'
    | 'script_line'
    | 'question_prompt';
  textSource: string;
  defaultSpeed: number;
  requiredBeforePublish: boolean;
  preferredVoiceId: string | null;
  generationStatus: 'missing' | 'generated' | 'approved' | 'rejected' | 'stale';
  cacheKeyStrategy: 'provider-model-speed-field-text-hash-v1';
  notesKo: string;
};

export type TtsReviewBatchSummary = {
  totalBatches: number;
  totalTargets: number;
  adminReadyTargets: number;
  extensionRequiredTargets: number;
  requiredBeforePublishTargets: number;
  generationStatusSummary: TtsGenerationStatusSummary;
};

export type TtsReviewBatchListResponse = {
  schemaVersion: number;
  status: string;
  batches: TtsReviewBatchItem[];
  summary: TtsReviewBatchSummary;
};

export type TtsReviewBatchTargetsResponse = {
  schemaVersion: number;
  status: string;
  batch: TtsReviewBatchItem;
  targets: TtsReviewTargetItem[];
};

export type TtsReviewGenerationPlanCandidate = {
  contentType: 'vocabulary' | 'grammar';
  lookupType: 'topic_id' | 'grammar_level_order' | 'vocabulary_level_order';
  topicId: string;
  adminField: string;
  jlptLevel: string | null;
  grammarOrder: number | null;
  vocabularyOrder: number | null;
  matchType: 'exact' | 'partial' | 'related' | null;
  noteKo: string;
};

export type TtsReviewGenerationPlanItem = {
  target: TtsReviewTargetItem;
  adminContentType: string;
  adminField: string | null;
  operationStatus:
    | 'ready_after_db_lookup'
    | 'manual_mapping_required'
    | 'blocked';
  existingAdminTtsSupported: boolean;
  candidates: TtsReviewGenerationPlanCandidate[];
  blockerCodes: Array<
    | 'admin_extension_required'
    | 'unsupported_admin_tts_field'
    | 'missing_admin_field_mapping'
    | 'topic_vocabulary_mapping_required'
    | 'ambiguous_or_partial_vocabulary_mapping'
    | 'topic_grammar_mapping_required'
    | 'ambiguous_or_partial_grammar_mapping'
  >;
  notesKo: string;
};

export type TtsReviewGenerationPlanSummary = {
  totalTargets: number;
  supportedTargets: number;
  readyAfterDbLookupTargets: number;
  manualMappingRequiredTargets: number;
  blockedTargets: number;
};

export type TtsReviewGenerationPlanResponse = {
  schemaVersion: number;
  status: string;
  batch: TtsReviewBatchItem;
  summary: TtsReviewGenerationPlanSummary;
  items: TtsReviewGenerationPlanItem[];
};

export type TtsReviewExecutePreviewItem = {
  target: TtsReviewTargetItem;
  adminContentType: string;
  adminField: string | null;
  lookupStatus:
    | 'resolved'
    | 'missing'
    | 'ambiguous'
    | 'not_lookup_ready'
    | 'blocked';
  canGenerateWithCurrentService: boolean;
  candidate: TtsReviewGenerationPlanCandidate | null;
  contentItemId: string | null;
  contentLabel: string | null;
  notesKo: string;
};

export type TtsReviewExecutePreviewSummary = {
  totalTargets: number;
  resolvedTargets: number;
  missingTargets: number;
  ambiguousTargets: number;
  notLookupReadyTargets: number;
  blockedTargets: number;
  generatableTargets: number;
};

export type TtsReviewExecutePreviewResponse = {
  schemaVersion: number;
  status: string;
  batch: TtsReviewBatchItem;
  summary: TtsReviewExecutePreviewSummary;
  items: TtsReviewExecutePreviewItem[];
};

export async function fetchTtsReviewBatches(params: {
  reviewSurface?: TtsReviewSurface;
} = {}): Promise<TtsReviewBatchListResponse> {
  const headers = await getAuthHeaders();
  const url = new URL(`${API_URL}/api/v1/admin/content/tts/review-batches`);
  if (params.reviewSurface) {
    url.searchParams.set('review_surface', params.reviewSurface);
  }
  const res = await fetch(url.toString(), { headers });
  await throwIfNotOk(res);
  return res.json() as Promise<TtsReviewBatchListResponse>;
}

export async function fetchTtsReviewBatchTargets(
  batchId: string,
): Promise<TtsReviewBatchTargetsResponse> {
  const headers = await getAuthHeaders();
  const res = await fetch(
    `${API_URL}/api/v1/admin/content/tts/review-batches/${encodeURIComponent(batchId)}/targets`,
    { headers },
  );
  await throwIfNotOk(res);
  return res.json() as Promise<TtsReviewBatchTargetsResponse>;
}

export async function fetchTtsReviewGenerationPlan(
  batchId: string,
): Promise<TtsReviewGenerationPlanResponse> {
  const headers = await getAuthHeaders();
  const res = await fetch(
    `${API_URL}/api/v1/admin/content/tts/review-batches/${encodeURIComponent(batchId)}/generation-plan`,
    { headers },
  );
  await throwIfNotOk(res);
  return res.json() as Promise<TtsReviewGenerationPlanResponse>;
}

export async function fetchTtsReviewExecutePreview(
  batchId: string,
): Promise<TtsReviewExecutePreviewResponse> {
  const headers = await getAuthHeaders();
  const res = await fetch(
    `${API_URL}/api/v1/admin/content/tts/review-batches/${encodeURIComponent(batchId)}/execute-preview`,
    { headers },
  );
  await throwIfNotOk(res);
  return res.json() as Promise<TtsReviewExecutePreviewResponse>;
}

// ---- Review Queue API functions ----

export type ReviewQueueItem = {
  id: string;
  quizType?: string; // "cloze" or "sentence_arrange" — only present for quiz content type
};

export type ReviewQueueResponse = {
  ids: ReviewQueueItem[];
  total: number;
  capped: boolean;
};

export async function fetchReviewQueue(
  contentType: string,
  params: { jlptLevel?: string; category?: string },
): Promise<ReviewQueueResponse> {
  const headers = await getAuthHeaders();
  const url = new URL(
    `${API_URL}/api/v1/admin/content/review-queue/${contentType}`,
  );
  if (params.jlptLevel) url.searchParams.set('jlpt_level', params.jlptLevel);
  if (params.category) url.searchParams.set('category', params.category);
  const res = await fetch(url.toString(), { headers });
  await throwIfNotOk(res);
  return res.json() as Promise<ReviewQueueResponse>;
}
