# Phase 04: TTS Audio - Research

**Researched:** 2026-03-27
**Domain:** Audio playback (HTML5 Audio API), TTS regeneration via FastAPI, item-level cooldown, field-selector dropdown
**Confidence:** HIGH — all findings verified against actual source code in the repository

## Summary

Phase 4 extends existing TTS infrastructure (already handling 'vocabulary' and 'kana' target types) to the admin edit pages. The core FastAPI pattern in `tts.py` (cache-check → generate → GCS-upload → DB-save) is well-established and only needs a new `require_reviewer`-gated endpoint in `admin_content.py`. The frontend work is a self-contained `TtsPlayer` component inserted directly below `ReviewHeader` on all four edit pages.

The key complexity is the 10-minute per-item cooldown. The existing `rate_limit.py` uses a Redis sliding window, but it is designed for per-user rate limiting (counts requests in a time window), not an item-level on/off gate with countdown display. For the cooldown, client-side `localStorage` is the right choice: it stores `{ [itemKey]: regeneratedAt }`, reads it on mount to derive remaining seconds, and drives the countdown UI via `setInterval`. The server must also reject requests within the 10-minute window using a Redis key per `(contentType, itemId)` as a second guard.

The field selector (D-08 / D-09) requires knowing which text fields each content type exposes. Based on the models, the defaults are: Vocabulary → `reading` (pronunciation-first); Grammar → first `example_sentences[0].japanese`; ClozeQuestion → `sentence`; SentenceArrangeQuestion → `japanese_sentence`; ConversationScenario → `situation`. The API endpoint receives `{ contentType, itemId, field }` and resolves the text server-side.

**Primary recommendation:** Add one POST endpoint `POST /api/v1/admin/tts/regenerate` using `require_reviewer` (delete existing TtsAudio row first, then generate fresh). On the frontend, create a single `TtsPlayer` component consuming a `useTtsPlayer` hook; insert it on all four edit pages between `ReviewHeader` and the form.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** 미니 플레이어 — 재생 버튼 + 파형 애니메이션 + 재생성 버튼을 한 줄로 컴팩트하게. 편집 페이지 상단(제목 바로 아래)에 배치
- **D-02:** 오디오 없는 항목 — 플레이어 영역 회색 비활성 상태 + 「오디오 없음 — 생성」 버튼 표시. 재생성 유도
- **D-03:** 간단 확인 다이얼로그 — 「{항목명}의 TTS를 재생성하시겠습니까?」 + 확인/취소 버튼. 추가 정보 없이 간결하게
- **D-04:** 진행 상태 — 버튼이 로딩 스피너로 변하고 「생성 중...」 텍스트 표시. 완료 시 성공 토스트
- **D-05:** 완료 후 자동 재생 — 생성 완료 시 자동으로 새 오디오 재생. reviewer가 바로 확인 가능
- **D-06:** 항목별 10분 쿨다운 — A 단어 재생성 후 10분간 A만 제한. B 단어는 바로 재생성 가능
- **D-07:** 남은 시간 실시간 표시 — 재생성 버튼 비활성 + 「8분 후 재생성 가능」 실시간 카운트다운 표시
- **D-08:** 여러 필드 선택 가능 — 각 콘텐츠 타입에서 TTS 가능한 필드 목록을 드롭다운으로 표시
- **D-09:** 기본 필드 자동 선택 — 드롭다운에 기본값 설정 (단어: reading/word, 문법: example_sentence 등)

### Claude's Discretion

- TTS 가능 필드 목록 (각 콘텐츠 타입별 어떤 필드가 드롭다운에 포함될지)
- 미니 플레이어 컴포넌트 세부 디자인 (파형 vs 단순 재생바)
- 쿨다운 저장 위치 (서버 vs 클라이언트)
- 재생성 API 엔드포인트 설계 (기존 tts.py 패턴 확장 방식)
- 에러 핸들링 (TTS 생성 실패, GCS 업로드 실패 시 UI)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TTS-01 | Reviewer가 편집 화면에서 기존 TTS 오디오를 재생할 수 있다 | `TtsAudio` table has `audio_url` column pointing to GCS CDN. Fetch existing record via new GET endpoint, play with HTML5 `<audio>`. |
| TTS-02 | Reviewer가 개별 항목의 TTS를 재생성 요청할 수 있다 (확인 다이얼로그 포함) | New `POST /api/v1/admin/tts/regenerate` endpoint deletes old TtsAudio row and regenerates; `RejectReasonDialog` pattern used for confirmation; `useMutation` with `require_reviewer` auth. |
</phase_requirements>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| HTML5 Audio API | Browser native | Audio playback | No library needed; `new Audio(url)` with `.play()/.pause()` is sufficient for a mini player |
| TanStack Query | ^5.90.21 | TTS fetch + regeneration mutations | Already established in all admin pages |
| shadcn/ui Dialog | (existing) | Regeneration confirmation dialog | Already used for `RejectReasonDialog`; same pattern |
| sonner | ^2.0.7 | Success/error toasts | Already used across Phase 3 pages |
| localStorage | Browser native | 10-min cooldown persistence across page refreshes | No server round-trip needed for UI gating |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Redis | >=5.2 (existing) | Server-side cooldown guard | Prevent API abuse even if client localStorage is cleared |
| lucide-react | ^0.575.0 | Play/Pause/RotateCcw icons | Already in project |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| localStorage cooldown | Server-only Redis cooldown | Server-only: countdown UI requires polling the server every second — wasteful. Client+server hybrid is better |
| localStorage cooldown | React state only | React state resets on page reload; localStorage persists correctly |
| HTML5 Audio | `<audio>` element with `ref` | Both work; `new Audio(url)` is simpler for programmatic control without a visible `<audio>` DOM element |

**Installation:** No new packages needed — all dependencies are already installed.

---

## Architecture Patterns

### Recommended Project Structure

```
apps/
├── api/
│   └── app/
│       └── routers/
│           └── admin_content.py   # Add: POST /api/v1/admin/tts/regenerate + GET tts endpoint
│
└── admin/
    └── src/
        ├── components/
        │   └── content/
        │       └── tts-player.tsx          # NEW: mini player + field selector + regenerate dialog
        ├── hooks/
        │   └── use-tts-player.ts           # NEW: audio state, cooldown logic, mutation
        ├── lib/
        │   └── api/
        │       └── admin-content.ts        # ADD: fetchTtsAudio(), regenerateTts()
        └── app/(admin)/
            ├── vocabulary/[id]/page.tsx    # ADD: <TtsPlayer> after <ReviewHeader>
            ├── grammar/[id]/page.tsx       # ADD: <TtsPlayer> after <ReviewHeader>
            ├── quiz/[id]/page.tsx          # ADD: <TtsPlayer> after <ReviewHeader>
            └── conversation/[id]/page.tsx  # ADD: <TtsPlayer> after <ReviewHeader>
```

### Pattern 1: New Admin TTS Endpoint in admin_content.py

**What:** Add two endpoints to `admin_content.py` under the existing `require_reviewer` pattern.
- `GET /api/v1/admin/content/{content_type}/{id}/tts` — look up TtsAudio record, return `{ audioUrl, field }` or `{ audioUrl: null }`
- `POST /api/v1/admin/tts/regenerate` — delete existing TtsAudio row, generate new, GCS upload, save

**When to use:** Always. Domain logic must live in FastAPI per `api-plane.md` rule.

**Endpoint contract:**

```python
# Source: apps/api/app/routers/tts.py pattern + apps/api/app/routers/admin_content.py require_reviewer pattern

class AdminTtsRegenerateRequest(BaseModel):
    content_type: Literal["vocabulary", "grammar", "cloze", "sentence_arrange", "conversation"]
    item_id: str
    field: str  # e.g. "reading", "word", "sentence", "japanese_sentence", "situation"

class AdminTtsResponse(BaseModel):
    audio_url: str | None
    field: str | None
    provider: str | None

# GET handler: query TtsAudio WHERE target_type=content_type AND target_id=item_id
# POST handler:
#   1. Check Redis cooldown key f"admin_tts_cooldown:{content_type}:{item_id}" — 429 if exists
#   2. Delete existing TtsAudio row (so UniqueConstraint doesn't block re-insert)
#   3. Resolve text from the content model by field name
#   4. Call generate_tts(text) -> TtsResult
#   5. _upload_to_gcs(path, bytes) -> audio_url
#   6. Insert new TtsAudio row
#   7. Set Redis cooldown key with 600-second TTL
#   8. Return { audioUrl, field, provider }
```

### Pattern 2: TtsPlayer Component + useTtsPlayer Hook

**What:** Self-contained mini player component consuming a hook that wraps TanStack Query + HTML5 Audio + localStorage cooldown.

**When to use:** Insert on all four edit pages directly below `ReviewHeader`.

```typescript
// Source: apps/admin/src/components/content/reject-reason-dialog.tsx pattern

type TtsPlayerProps = {
  contentType: 'vocabulary' | 'grammar' | 'cloze' | 'sentence_arrange' | 'conversation';
  itemId: string;
  itemLabel: string;  // For dialog: "{itemLabel}のTTSを再生成しますか？"
  availableFields: { value: string; label: string }[];
};
```

**Hook responsibilities:**
1. `useQuery` to fetch existing TTS audio URL from `GET .../tts`
2. `useState` for `isPlaying`, `selectedField`, `confirmDialogOpen`
3. `useEffect` on mount — read `localStorage.getItem('tts_cooldown')` (JSON map), compute `remainingSeconds`
4. `setInterval` for countdown decrement when `remainingSeconds > 0`
5. `useMutation` for regeneration — on success: update audioUrl, set localStorage timestamp, auto-play

```typescript
// Cooldown localStorage structure (single JSON key, all items in one object)
const COOLDOWN_KEY = 'harukoto_admin_tts_cooldown';
type CooldownMap = Record<string, number>;  // key: "{contentType}:{itemId}" => epoch ms of regeneration

function getCooldownRemaining(contentType: string, itemId: string): number {
  try {
    const raw = localStorage.getItem(COOLDOWN_KEY);
    if (!raw) return 0;
    const map: CooldownMap = JSON.parse(raw);
    const ts = map[`${contentType}:${itemId}`];
    if (!ts) return 0;
    const elapsed = (Date.now() - ts) / 1000;
    return Math.max(0, 600 - Math.floor(elapsed));
  } catch {
    return 0;
  }
}
```

### Pattern 3: TTS-capable Fields per Content Type

**What:** Static config object defining available fields and defaults.

```typescript
// Derived from: apps/api/app/models/content.py + apps/api/app/models/conversation.py

export const TTS_FIELDS = {
  vocabulary: {
    default: 'reading',
    options: [
      { value: 'reading', label: '読み方' },
      { value: 'word', label: '単語' },
      { value: 'example_sentence', label: '例文' },
    ],
  },
  grammar: {
    default: 'pattern',
    options: [
      { value: 'pattern', label: 'パターン' },
      // example_sentences is a JSON array; server picks [0].japanese
    ],
  },
  cloze: {
    default: 'sentence',
    options: [
      { value: 'sentence', label: '問題文' },
    ],
  },
  sentence_arrange: {
    default: 'japanese_sentence',
    options: [
      { value: 'japanese_sentence', label: '日本語文' },
    ],
  },
  conversation: {
    default: 'situation',
    options: [
      { value: 'situation', label: 'シチュエーション' },
      { value: 'title_ja', label: '日本語タイトル' },
    ],
  },
} as const;
```

**Server-side field resolution** in the regenerate endpoint:

```python
def resolve_tts_text(content_type: str, field: str, obj) -> str:
    """Extract the text value for a given field from a content model instance."""
    if content_type == "grammar" and field == "example_sentences":
        # example_sentences is a JSON list; take first entry's Japanese text
        sentences = obj.example_sentences or []
        if sentences and isinstance(sentences[0], dict):
            return sentences[0].get("japanese", "") or sentences[0].get("sentence", "")
        return obj.pattern  # fallback
    value = getattr(obj, field, None)
    if not value:
        raise HTTPException(status_code=422, detail=f"Field '{field}' is empty or unavailable")
    return str(value)
```

### Anti-Patterns to Avoid

- **Do NOT reuse `tts.py` endpoints for admin TTS.** The existing `/api/v1/vocab/tts` endpoint uses `get_current_user` (for app users), not `require_reviewer`. Admin TTS needs reviewer auth and forced regeneration (bypass cache).
- **Do NOT use React state alone for cooldown.** State resets on navigation. Use localStorage.
- **Do NOT add a Next.js API route for TTS.** `api-plane.md` forbids new domain logic in Next API routes.
- **Do NOT skip deleting the old TtsAudio row before regeneration.** The `UniqueConstraint("target_type", "target_id", "speed")` will cause an IntegrityError on re-insert.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Audio playback | Custom audio engine | `new Audio(url)` / HTML5 Audio API | Browsers handle buffering, MIME detection, error states |
| Confirmation dialog | Custom modal | shadcn `Dialog` (already in `components/ui/dialog.tsx`) | Already imported and styled in `RejectReasonDialog` |
| Toast feedback | Custom notification | `sonner` (already used on all edit pages) | Consistent UX, already wired |
| Query cache invalidation | Manual state update | TanStack Query `invalidateQueries` | Ensures fresh data after regeneration without extra fetches |
| GCS upload | Custom HTTP client | `_upload_to_gcs()` in `tts.py` (move to shared util) | Already handles error logging, content-type headers |

**Key insight:** The entire backend pattern is already implemented in `tts.py`. The admin endpoint is essentially a stripped-down version that bypasses the cache check and forces regeneration.

---

## Common Pitfalls

### Pitfall 1: UniqueConstraint Violation on Regeneration
**What goes wrong:** `TtsAudio` has `UniqueConstraint("target_type", "target_id", "speed")`. If the row already exists and you attempt a new insert without deleting it first, SQLAlchemy raises `IntegrityError`.
**Why it happens:** The old `vocab_tts()` endpoint only inserts when no row exists (it returns early if cached). The regeneration endpoint must always produce a new row.
**How to avoid:** In the regenerate endpoint, `DELETE FROM tts_audio WHERE target_type=? AND target_id=? AND speed=1.0` before inserting the new row. Use `db.execute(delete(...).where(...))` then `db.add(new_row)`.
**Warning signs:** 500 error on second regeneration attempt for the same item.

### Pitfall 2: GCS CORS Blocking Audio Playback
**What goes wrong:** Browser `<audio>` element or `new Audio(url)` fetches the GCS URL. If the `harukoto-tts` bucket lacks a CORS policy allowing the admin Vercel domain, the browser will block playback.
**Why it happens:** `GCS_CDN_BASE_URL` is `https://storage.googleapis.com/harukoto-tts`. Public GCS buckets serve content but may not include CORS headers for non-Google origins.
**How to avoid:** Verify the GCS bucket CORS config includes `{"origin": ["https://admin.harukoto.app", "http://localhost:3000"], "method": ["GET"], "responseHeader": ["Content-Type"]}`. This is a deployment concern flagged in STATE.md as `[Phase 4 risk]`.
**Warning signs:** Audio loads and URL is valid but browser console shows `CORS error` on the GCS URL.

### Pitfall 3: Cooldown State Mismatch After Page Reload
**What goes wrong:** If the cooldown timestamp is stored only in React state, navigating away from the page and back resets the countdown to 0, allowing re-generation within the 10-minute window.
**Why it happens:** React state is ephemeral; it does not survive navigation.
**How to avoid:** Persist cooldown timestamps in `localStorage` using the `harukoto_admin_tts_cooldown` key. Read on `useEffect` mount; write immediately after a successful regeneration mutation.
**Warning signs:** Cooldown appears to reset after navigating away and back.

### Pitfall 4: Autoplay Policy Blocking D-05
**What goes wrong:** D-05 requires auto-play after regeneration. Browsers (Chrome, Safari) block `Audio.play()` unless the user has recently interacted with the page.
**Why it happens:** Browser autoplay policy requires a user gesture within the current browsing context. The regeneration button click qualifies as a gesture, so calling `audio.play()` synchronously inside the mutation `onSuccess` should work.
**How to avoid:** Call `audio.play()` inside `onSuccess` of the mutation (not in a `useEffect` or setTimeout), since it runs synchronously in the microtask queue following the user's button click. Keep the Audio object in a `useRef` so it persists across renders.
**Warning signs:** Console warning `play() failed because the user didn't interact with the document first`.

### Pitfall 5: Grammar `example_sentences` Field is JSON
**What goes wrong:** `Grammar.example_sentences` is a `JSON` column (list of objects). Passing the raw JSON to TTS would result in `[{...}]` being synthesized as text.
**Why it happens:** The field is a complex structure, not a plain string.
**How to avoid:** Server-side `resolve_tts_text()` for `grammar` + `example_sentences` must extract `.japanese` or `.sentence` from the first array element, with fallback to `pattern`.
**Warning signs:** ElevenLabs/Gemini returns audio that literally says `[object Object]` or the JSON string.

---

## Code Examples

### Admin TTS Fetch Endpoint (GET)

```python
# Source: apps/api/app/routers/admin_content.py pattern
@router.get("/{content_type}/{item_id}/tts", response_model=AdminTtsResponse)
async def get_admin_tts(
    content_type: str,
    item_id: str,
    reviewer: User = Depends(require_reviewer),
    db: AsyncSession = Depends(get_db),
) -> AdminTtsResponse:
    result = await db.execute(
        select(TtsAudio).where(
            TtsAudio.target_type == content_type,
            TtsAudio.target_id == item_id,
            TtsAudio.speed == 1.0,
        )
    )
    record = result.scalar_one_or_none()
    if record:
        return AdminTtsResponse(audio_url=record.audio_url, field=record.text, provider=record.provider)
    return AdminTtsResponse(audio_url=None, field=None, provider=None)
```

### Admin TTS Regenerate Endpoint (POST)

```python
# Source: apps/api/app/routers/tts.py + apps/api/app/middleware/rate_limit.py
from sqlalchemy import delete as sa_delete

@router.post("/tts/regenerate", response_model=AdminTtsResponse)
async def regenerate_admin_tts(
    body: AdminTtsRegenerateRequest,
    reviewer: User = Depends(require_reviewer),
    db: AsyncSession = Depends(get_db),
) -> AdminTtsResponse:
    # 1. Cooldown check via Redis (10 min = 600 seconds)
    cooldown_key = f"admin_tts_cooldown:{body.content_type}:{body.item_id}"
    rl = await rate_limit(cooldown_key, max_requests=1, window_seconds=600)
    if not rl.success:
        reset_in = int(rl.reset - time.time())
        raise HTTPException(
            status_code=429,
            detail=f"再生成は{reset_in // 60}分後に可能です",
        )

    # 2. Fetch the content item and resolve text
    obj = await _fetch_content_item(db, body.content_type, body.item_id)
    text = resolve_tts_text(body.content_type, body.field, obj)

    # 3. Delete existing TtsAudio row to avoid UniqueConstraint violation
    await db.execute(
        sa_delete(TtsAudio).where(
            TtsAudio.target_type == body.content_type,
            TtsAudio.target_id == body.item_id,
            TtsAudio.speed == 1.0,
        )
    )

    # 4. Generate + upload
    tts_result = await generate_tts(text)
    gcs_path = f"tts/admin/{body.content_type}/{body.item_id}.mp3"
    audio_url = await _upload_to_gcs(gcs_path, tts_result.audio)

    # 5. Save new row
    db.add(TtsAudio(
        target_type=body.content_type,
        target_id=body.item_id,
        text=text,
        speed=1.0,
        provider=tts_result.provider,
        model=tts_result.model,
        audio_url=audio_url,
    ))
    await db.commit()

    return AdminTtsResponse(audio_url=audio_url, field=text, provider=tts_result.provider)
```

### useTtsPlayer Hook Skeleton

```typescript
// Source: apps/admin/src/hooks/use-content-detail.ts pattern
'use client';

import { useEffect, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { fetchTtsAudio, regenerateTts } from '@/lib/api/admin-content';
import { TTS_FIELDS } from '@/lib/tts-fields';

const COOLDOWN_KEY = 'harukoto_admin_tts_cooldown';
const COOLDOWN_SECONDS = 600;

export function useTtsPlayer(
  contentType: string,
  itemId: string,
) {
  const queryClient = useQueryClient();
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [remainingSeconds, setRemainingSeconds] = useState(0);
  const [selectedField, setSelectedField] = useState(
    TTS_FIELDS[contentType as keyof typeof TTS_FIELDS]?.default ?? ''
  );
  const [confirmOpen, setConfirmOpen] = useState(false);

  // Load initial cooldown from localStorage
  useEffect(() => {
    setRemainingSeconds(getCooldownRemaining(contentType, itemId));
  }, [contentType, itemId]);

  // Countdown ticker
  useEffect(() => {
    if (remainingSeconds <= 0) return;
    const id = setInterval(() => {
      setRemainingSeconds((s) => {
        if (s <= 1) { clearInterval(id); return 0; }
        return s - 1;
      });
    }, 1000);
    return () => clearInterval(id);
  }, [remainingSeconds]);

  const ttsQuery = useQuery({
    queryKey: ['admin-tts', contentType, itemId],
    queryFn: () => fetchTtsAudio(contentType, itemId),
    staleTime: 60_000,
  });

  const regenerateMutation = useMutation({
    mutationFn: () => regenerateTts(contentType, itemId, selectedField),
    onSuccess: (data) => {
      void queryClient.invalidateQueries({ queryKey: ['admin-tts', contentType, itemId] });
      // Set cooldown
      try {
        const raw = localStorage.getItem(COOLDOWN_KEY);
        const map = raw ? JSON.parse(raw) as Record<string, number> : {};
        map[`${contentType}:${itemId}`] = Date.now();
        localStorage.setItem(COOLDOWN_KEY, JSON.stringify(map));
        setRemainingSeconds(COOLDOWN_SECONDS);
      } catch { /* ignore */ }
      // Auto-play (D-05) — runs in the microtask from button click gesture
      if (data.audioUrl) {
        const audio = new Audio(data.audioUrl);
        audioRef.current = audio;
        void audio.play();
        setIsPlaying(true);
        audio.onended = () => setIsPlaying(false);
      }
      toast.success('TTS再生成完了');
      setConfirmOpen(false);
    },
    onError: (err: Error) => {
      toast.error(err.message || 'TTS再生成に失敗しました');
    },
  });

  function handlePlayPause() {
    const url = ttsQuery.data?.audioUrl;
    if (!url) return;
    if (!audioRef.current || audioRef.current.src !== url) {
      audioRef.current = new Audio(url);
      audioRef.current.onended = () => setIsPlaying(false);
    }
    if (isPlaying) {
      audioRef.current.pause();
      setIsPlaying(false);
    } else {
      void audioRef.current.play();
      setIsPlaying(true);
    }
  }

  return {
    audioUrl: ttsQuery.data?.audioUrl ?? null,
    isLoading: ttsQuery.isLoading,
    isPlaying,
    remainingSeconds,
    selectedField,
    setSelectedField,
    confirmOpen,
    setConfirmOpen,
    handlePlayPause,
    regenerateMutation,
  };
}
```

### TtsPlayer Component Insertion Point

```tsx
// Source: apps/admin/src/app/(admin)/vocabulary/[id]/page.tsx pattern
// Insert between <ReviewHeader> and <form>:

<ReviewHeader ... />

<TtsPlayer
  contentType="vocabulary"
  itemId={id}
  itemLabel={data.word}
  availableFields={TTS_FIELDS.vocabulary.options}
/>

<form ...>
```

### i18n Keys to Add (ja.json, ko.json, en.json)

```json
"tts": {
  "playAudio": "音声を再生",
  "noAudio": "音声なし — 生成",
  "regenerate": "再生成",
  "regenerating": "生成中...",
  "regenerateSuccess": "TTS再生成完了",
  "regenerateError": "TTS再生成に失敗しました",
  "confirmTitle": "{name}のTTSを再生成しますか？",
  "confirmButton": "再生成",
  "cancelButton": "キャンセル",
  "cooldownMessage": "{minutes}分後に再生成可能",
  "fieldLabel": "テキストフィールド"
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single `/api/v1/vocab/tts` cached endpoint | New admin endpoint bypassing cache for forced regeneration | Phase 4 | Admin can force fresh audio; user app retains cache |
| TtsAudio target_type: 'vocabulary' \| 'kana' | Add 'grammar', 'cloze', 'sentence_arrange', 'conversation' | Phase 4 | No schema migration needed — target_type is a plain Text column, no enum constraint |

**Deprecated/outdated:**
- The `_generating` in-memory set in `tts.py`: adequate for the user-facing endpoint but not needed for the admin endpoint (only 1-3 reviewers; Redis cooldown provides sufficient protection).

---

## Open Questions

1. **GCS CORS configuration**
   - What we know: STATE.md flags this as a Phase 4 risk. `GCS_CDN_BASE_URL` = `https://storage.googleapis.com/harukoto-tts`. Browser audio playback requires CORS headers.
   - What's unclear: Whether the bucket already has a CORS policy set for the admin Vercel domain.
   - Recommendation: Wave 0 task — verify GCS CORS config via `gsutil cors get gs://harukoto-tts` before building the player. If missing, add CORS JSON and apply with `gsutil cors set`.

2. **Grammar `example_sentences` field structure**
   - What we know: It is a `JSON` column (`dict | list`). The schema marks it as `list | None`.
   - What's unclear: Whether seeded data uses `{"japanese": "...", "english": "..."}` or a different shape.
   - Recommendation: The server-side resolver should try `.get("japanese")` then `.get("sentence")` as fallback, then fall back to `pattern` if the array is empty. This is safe to implement without seeing the actual data.

3. **`updated_at` column on TtsAudio**
   - What we know: The current `TtsAudio` model has no `updated_at` column — only `created_at`.
   - What's unclear: Whether the planner should add `updated_at` for audit purposes.
   - Recommendation: Skip it. The `created_at` of the freshly inserted row is effectively the regeneration timestamp. No schema change needed.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| ElevenLabs API | TTS generation (primary) | Config-dependent | `eleven_flash_v2_5` | Gemini TTS (auto-fallback in `generate_tts()`) |
| Google Gemini API | TTS generation (fallback) | Config-dependent | `gemini-2.5-flash-preview-tts` | ElevenLabs failure triggers this |
| GCS bucket `harukoto-tts` | Audio URL storage | Likely available | — | None — blocking if unavailable |
| Redis | Server-side cooldown guard | Available (existing `rate_limit.py` uses it) | >=5.2 | `rate_limit()` returns `success=True` if Redis unavailable — client-side localStorage becomes sole guard |

**Missing dependencies with no fallback:**
- GCS bucket `harukoto-tts` must exist and be accessible. Verify CORS config before building audio player.

**Missing dependencies with fallback:**
- Redis: `rate_limit.py` already handles Redis unavailability gracefully (returns `success=True`). localStorage cooldown still works on the client.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Vitest ^4.0.18 + Testing Library |
| Config file | `apps/admin/vitest.config.ts` |
| Quick run command | `cd apps/admin && pnpm test` |
| Full suite command | `cd apps/admin && pnpm test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TTS-01 | `TtsPlayer` renders play button when `audioUrl` is present | unit | `pnpm test -- --reporter=verbose src/__tests__/tts-player.test.tsx` | ❌ Wave 0 |
| TTS-01 | `TtsPlayer` renders disabled state when `audioUrl` is null | unit | same | ❌ Wave 0 |
| TTS-02 | `TtsPlayer` opens confirm dialog on regenerate click | unit | same | ❌ Wave 0 |
| TTS-02 | Cooldown: regenerate button disabled when `remainingSeconds > 0` | unit | same | ❌ Wave 0 |
| TTS-02 | `useTtsPlayer` reads localStorage cooldown on mount | unit | `pnpm test -- src/__tests__/use-tts-player.test.ts` | ❌ Wave 0 |
| TTS-02 | FastAPI `POST /api/v1/admin/tts/regenerate` returns 200 on valid request | integration (manual) | manual | — |
| TTS-02 | FastAPI returns 429 within 10-min cooldown window | unit (pytest) | `cd apps/api && uv run pytest tests/test_admin_tts.py -x` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `cd apps/admin && pnpm test`
- **Per wave merge:** `cd apps/admin && pnpm test && cd ../api && uv run pytest tests/test_admin_tts.py -x`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `apps/admin/src/__tests__/tts-player.test.tsx` — covers TTS-01 render states
- [ ] `apps/admin/src/__tests__/use-tts-player.test.ts` — covers TTS-02 cooldown logic
- [ ] `apps/api/tests/test_admin_tts.py` — covers TTS-02 server cooldown (pytest)

---

## Project Constraints (from CLAUDE.md)

| Constraint | Impact on Phase 4 |
|------------|-------------------|
| DDL via Alembic ONLY | No schema changes needed (TtsAudio.target_type is plain Text, no enum migration required). If `updated_at` is added, it needs an Alembic migration. |
| FastAPI for domain logic | Admin TTS endpoints go in `admin_content.py`, NOT in Next.js API routes |
| TypeScript strict mode + no `any` | `TTS_FIELDS` config and API response types must be fully typed |
| kebab-case file names | `tts-player.tsx`, `use-tts-player.ts`, `tts-fields.ts` |
| Codex cross-verification required | Before committing TTS endpoint + component, run Codex review — especially for API contract (request/response types between FastAPI CamelModel and TS types) |
| ruff before commit | `cd apps/api && uv run ruff check app/ tests/ && uv run ruff format --check app/ tests/` |
| pnpm lint before commit | `pnpm lint` from monorepo root |
| `use client` directive | `TtsPlayer` and `useTtsPlayer` use browser APIs (Audio, localStorage) — both must be client components/hooks |

---

## Sources

### Primary (HIGH confidence)
- `apps/api/app/routers/tts.py` — exact TTS generation + GCS upload pattern
- `apps/api/app/models/tts.py` — TtsAudio schema, UniqueConstraint
- `apps/api/app/services/ai.py` — `generate_tts()` function signature
- `apps/api/app/routers/admin_content.py` — `require_reviewer` dependency pattern
- `apps/api/app/middleware/rate_limit.py` — Redis rate_limit() function signature
- `apps/api/app/models/content.py` — field names for Vocabulary, Grammar, ClozeQuestion, SentenceArrangeQuestion
- `apps/api/app/models/conversation.py` — ConversationScenario field names
- `apps/admin/src/hooks/use-content-detail.ts` — TanStack Query mutation + invalidation pattern
- `apps/admin/src/components/content/reject-reason-dialog.tsx` — Dialog confirmation pattern
- `apps/admin/src/app/(admin)/vocabulary/[id]/page.tsx` — edit page structure
- `apps/admin/messages/ja.json` — existing i18n key structure
- `apps/api/app/config.py` — GCS_BUCKET_NAME = `harukoto-tts`, GCS_CDN_BASE_URL

### Secondary (MEDIUM confidence)
- HTML5 Audio autoplay policy (MDN): user gesture in the call stack allows `.play()` synchronously in mutation `onSuccess`
- Browser CORS for `<audio>` / `new Audio()`: requires `Access-Control-Allow-Origin` header from GCS

### Tertiary (LOW confidence)
- GCS bucket CORS current state: unknown — flagged as Phase 4 risk in STATE.md, must be verified

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in the project
- Architecture: HIGH — endpoints and component structure derived directly from existing patterns
- Pitfalls: HIGH — UniqueConstraint and CORS derived from actual code; autoplay policy is well-documented browser behavior
- TTS field mapping: MEDIUM — Grammar `example_sentences` JSON structure not verified against seed data

**Research date:** 2026-03-27
**Valid until:** 2026-04-27 (stable tech stack, fast-moving only: ElevenLabs model ID may change)
