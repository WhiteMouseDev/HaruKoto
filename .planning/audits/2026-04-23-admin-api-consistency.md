---
date: 2026-04-23
scope: apps/admin ↔ apps/api consistency
status: findings-draft
next: user triage → assign fixes to web-agent/backend-agent
---

# Admin ↔ API Consistency Audit

## TL;DR

**전수 감사 결과: Production-impacting 드리프트 2건, 데이터/UX 드리프트 4건, dormant 코드 1건.** 어드민 UI에서 사용하는 모든 엔드포인트는 OpenAPI에 존재하지만, quiz 감사로그와 conversation category 필터는 **조용히 깨져** 있음. 세그먼트 라우팅 설계와 enum 동기화가 드리프트 원천.

---

## 메서드

1. `apps/admin/src/**` 에서 `fetch`, `API_URL`, `/api/v1/` 패턴 grep → 호출 10종 추출
2. `apps/api/openapi/openapi.json` 의 `/admin/**` 경로 21종과 1:1 대조
3. admin TypeScript 타입 ↔ Pydantic CamelModel 필드 비교
4. 쿼리 파라미터 이름/값 도메인 비교 (enums)
5. React Query cache key 일관성 확인
6. 모든 어드민 라우트 페이지(`(admin)/*/page.tsx`, `(admin)/*/[id]/page.tsx`) 수동 워크스루

---

## 1. Orphaned endpoint 리스트

| Admin 호출 | 실제 API 라우트 | 상태 |
|---|---|---|
| GET `/admin/content/quiz/cloze/{id}/audit-logs` | `/{content_type}/{item_id}/audit-logs` 단일 세그먼트만 매칭 | **❌ 404** |
| GET `/admin/content/quiz/sentence-arrange/{id}/audit-logs` | 동일 | **❌ 404** |
| 그 외 10개 호출 (list, detail, patch, review, batch-review, tts/tts-regenerate, review-queue, stats) | 모두 OpenAPI에 존재 | ✅ |

**근거**:
- 호출부: `apps/admin/src/hooks/use-content-detail.ts:71` → `fetchAuditLogs(contentType, id)` 가 `contentType='quiz/cloze'` 또는 `'quiz/sentence-arrange'` (quiz/[id]/page.tsx:264,267)로 전달
- URL 빌더: `apps/admin/src/lib/api/admin-content.ts:183` → `/api/v1/admin/content/${contentType}/${id}/audit-logs`
- 결과 URL: `/api/v1/admin/content/quiz/cloze/{uuid}/audit-logs` — 4 세그먼트
- 라우트 정의: `apps/api/app/routers/admin_content.py:656` → `/{content_type}/{item_id}/audit-logs` — FastAPI 기본 path param 은 `/` 를 매칭하지 않음 (단일 세그먼트만)
- FastAPI 매칭: content_type=`quiz`, item_id=`cloze` 로 파싱 → `/audit-logs` 기대하는데 `/{uuid}/audit-logs` 남음 → **404**
- 심지어 라우팅이 성공했다 해도 `AuditLog.content_type` 컬럼에 저장된 값은 `'cloze'`/`'sentence_arrange'` (router line 387, 437 에서 `content_type="cloze"` 로 저장) 이므로 `'quiz/cloze'` 로 조회 시 빈 결과.

**Unused admin endpoints**: 없음. 모든 `/api/v1/admin/content/**` 라우트는 admin UI 에서 최소 1회 이상 호출됨.

---

## 2. 스키마 드리프트 (필드별)

### 2-1. `AuditLogItem.reviewerEmail` ≠ API `reviewerId` (P1)
- Admin 타입: `apps/admin/src/lib/api/admin-content.ts:116` → `reviewerEmail: string`
- API 스키마: `apps/api/app/schemas/admin_content.py:206` → `reviewer_id: uuid.UUID` (camelCase 직렬화: `reviewerId`)
- OpenAPI 확인: `AuditLogItem.required` 에 `reviewerId` 존재, `reviewerEmail` 없음
- UI 영향: `components/content/audit-timeline.tsx:99` → `{entry.reviewerEmail}` 가 `undefined` → React 에서 공백으로 렌더. 감사 기록에 리뷰어 식별자가 절대 표시되지 않음.
- 근본 문제: admin 은 "누가 이 변경을 했는지"를 사람이 읽을 수 있는 형태로 보고 싶지만, API 는 UUID 만 반환. 이메일 조인이 서버에서 필요하거나, admin 이 Supabase user table 에서 별도 조회 필요.

### 2-2. 리스트 응답 `updatedAt` 누락 (P1)
- Admin 타입: `VocabularyItem`, `GrammarItem`, `QuizItem`, `ConversationItem` 모두 `updatedAt: string` 선언 (admin-content.ts:26,36,46,56)
- API 스키마: `VocabularyAdminItem`, `GrammarAdminItem`, `QuizAdminItem`, `ConversationAdminItem` — `updated_at` 필드 없음 (admin_content.py:14-49)
- UI 영향: 4개 리스트 페이지 모두 `col.updatedAt` 컬럼을 `{new Date(item.updatedAt || item.createdAt)}` 로 렌더 (vocabulary/page.tsx:67 등). `updatedAt` 이 항상 `undefined` 이므로 **모든 행에서 `createdAt` 으로 폴백** → "수정일" 컬럼이 사실 "생성일".
- Detail 응답은 `updated_at` 포함 (`VocabularyDetailResponse` 등) — list/detail 비대칭.

### 2-3. `ScenarioCategory` enum 드리프트 (P0)
- API enum: `apps/api/app/enums.py:49` → `TRAVEL`, `DAILY`, `BUSINESS`, `FREE` (4개)
- Admin 하드코딩: `conversation/page.tsx:24-25` → `TRAVEL, SHOPPING, RESTAURANT, BUSINESS, DAILY_LIFE, EMERGENCY, TRANSPORTATION, HEALTHCARE` (8개)
- Admin i18n 키: `messages/ko.json` `category` — 동일한 8개 (DAILY/FREE 없음)
- 영향:
  - 필터 드롭다운에서 `SHOPPING`, `RESTAURANT`, `DAILY_LIFE`, `EMERGENCY`, `TRANSPORTATION`, `HEALTHCARE` 선택 시 `GET /admin/content/conversation?category=SHOPPING` → **422 Validation Error** (FastAPI 가 `ScenarioCategory` enum 을 검증)
  - API 가 반환하는 `DAILY` 또는 `FREE` 카테고리 아이템은 `tCat(item.category)` 에서 **i18n 키 미스** → next-intl 이 dev 모드에서 key 그대로 표시하거나 에러 던짐
- 근본 원인: admin 이 enum 을 API 에서 fetch 하지 않고 독립적으로 관리. `packages/types/src/generated/api.ts` 에 `ScenarioCategory` 있을 것이므로 거기서 import 해야 함.

### 2-4. snake_case vs camelCase 바디 (non-issue)
- `regenerateTts` 는 `content_type`, `item_id` 를 snake_case 로 보냄 (admin-content.ts:233-237)
- Pydantic `CamelModel` 이 `populate_by_name=True` 로 설정되어 양쪽 모두 수용 (schemas/common.py:19)
- 정상 작동, 드리프트 아님 — 다만 일관성을 위해 camelCase 로 맞추는 편이 좋음 (cosmetic).

---

## 3. 작동 안 하는 기능 / dead code

| 기능 | 증상 | 파일 |
|---|---|---|
| Quiz 상세 페이지 감사 타임라인 | 항상 "empty" 상태로 표시, 실제 audit_logs DB 레코드는 존재함 | quiz/[id]/page.tsx:392-395 + §1 |
| Conversation 카테고리 필터 (6개 값) | 필터 선택 시 리스트 로딩 실패 (422) | conversation/page.tsx:23-26 |
| Conversation 카테고리 렌더 (DAILY/FREE) | i18n 키 미스, 원문 key 노출 | conversation/page.tsx:45 |
| 4개 리스트의 "수정일" 컬럼 | 생성일로 폴백, 실제 수정 시각 반영 안 됨 | §2-2 |
| Dashboard stats 자동 갱신 | approve/reject 후 stats 카드가 refresh 되지 않음 | §4-1 |
| Review queue 의 JLPT 필터 상속 | 필터로 N5 선택 후 "Start review" 눌러도 전체 레벨 큐 생성 | §4-2 |
| `quiz_type` URL 쿼리 파라미터 | `use-content-list.ts:18` 에서 읽지만 UI 에서 설정할 수단 없음 (dormant) | use-content-list.ts:18 |

---

## 4. 에러 처리 / 캐시 불일치

### 4-1. Stats cache key 미스매치 (P1)
- Dashboard: `useQuery({ queryKey: ['admin-content-stats'] })` (use-dashboard-stats.ts:12)
- Review/Bulk 뮤테이션 invalidation: `['admin-content', 'stats']` (use-content-detail.ts:59, use-bulk-review.ts:25)
- React Query 는 배열 prefix 매칭 — `['admin-content-stats']` 와 `['admin-content', 'stats']` 는 별개. 승인/거절 후 대시보드 카운트 **갱신 안 됨**. 사용자가 대시보드 재방문/새로고침해야 반영.

### 4-2. ReviewStartButton 필터 파라미터 이름 불일치 (P1)
- FilterBar 가 URL 에 쓰는 키: `jlpt` (filter-bar.tsx:88-89)
- useContentList 가 읽는 키: `jlpt` → API 로는 `jlpt_level` 매핑 ✓ (use-content-list.ts:15)
- ReviewStartButton 이 읽는 키: `jlpt_level` ❌ (review-start-button.tsx:25) — 결코 URL 에 없는 이름
- 결과: 필터로 JLPT N3 를 선택하고 "큐 시작"을 눌러도 모든 JLPT 레벨이 큐에 포함됨.

### 4-3. 에러 메시지 일반화 (P2)
- `lib/api/admin-content.ts` 의 모든 핸들러가 `throw new Error('API error: ${res.status}')` 만 던짐
- FastAPI 는 `{detail: "..."}` 형식으로 한국어/일본어 에러 메시지 반환 (예: `AdminTtsServiceError` → `"TTS生成に失敗しました"`)
- admin UI 의 toast 는 status code 만 노출 — 사용자가 왜 실패했는지 알 수 없음
- `regenerateTts` 만 예외적으로 429 에서 `data.detail` 추출 (admin-content.ts:240-241)

---

## 5. Admin 전용 엔드포인트 중 사용 안 되는 것

**없음**. OpenAPI 의 21개 `/admin/**` 경로 모두 admin UI 에서 최소 1회 호출됨.

단, 서비스 레이어 상 dormant 가능성:
- `AdminTtsRegenerateRequest.content_type` Literal 에 `"conversation"` 포함되지만 admin UI 가 conversation TTS 를 호출하는 경로는 `contentType="conversation"` 으로 `fetchTtsAudio`/`regenerateTts` 모두 사용 중 ✓
- `review-queue/{content_type}` 의 `content_type` 도 5개 타입 모두 호출됨 (`vocabulary`, `grammar`, `quiz`, `conversation`)

---

## 6. 권장 수정 작업 (P0 / P1 / P2)

### P0 — 프로덕션 기능이 조용히 깨짐, 즉시 수정
| # | 작업 | 담당 에이전트 | 추정 규모 |
|---|---|---|---|
| P0-1 | Quiz 감사로그 경로 수정. 옵션 A: admin 에서 `useContentDetail` 에 전달하는 contentType 을 audit-log용으로만 `cloze`/`sentence_arrange` 로 매핑. 옵션 B: API 에 `/quiz/cloze/{item_id}/audit-logs`, `/quiz/sentence-arrange/{item_id}/audit-logs` 명시 라우트 추가. **권장: 옵션 A** (API 는 이미 단일 content_type 값으로 audit_logs 저장). | web-agent | S |
| P0-2 | `ScenarioCategory` enum 동기화. Admin 하드코딩 제거 → `packages/types/src/generated/api.ts` 의 enum 사용 또는 API 에서 카테고리 옵션을 받아오는 엔드포인트. i18n 키도 `TRAVEL/DAILY/BUSINESS/FREE` 로 정정. **단, API enum 자체가 너무 빈약하면 (SHOPPING 등이 제품 요구면) API 쪽 enum 확장이 올바른 방향** — 제품 의도 확인 필요. | backend-agent 또는 shared-packages-agent | M |

### P1 — 데이터 정확성/UX 영향, 다음 사이클
| # | 작업 | 담당 | 규모 |
|---|---|---|---|
| P1-1 | `AuditLogItem` 에 `reviewer_email` (또는 `reviewer_name`) 추가. `admin_audit_logs.py` 서비스에서 users 테이블 조인. admin TS 타입도 맞춤. | backend-agent → web-agent | M |
| P1-2 | 리스트 응답 스키마에 `updated_at` 추가 (`VocabularyAdminItem` 등 4개). admin 타입은 이미 선언됨 — 서버만 맞추면 됨. 대안: admin 쪽에서 `updatedAt` 제거하고 컬럼 헤더를 "생성일" 로 바꾸기. | backend-agent | S |
| P1-3 | Dashboard stats cache key 통일. `['admin-content', 'stats']` 로 맞추거나 `['admin-content-stats']` 로 invalidation 쪽을 바꿈. | web-agent | XS |
| P1-4 | ReviewStartButton 이 `searchParams.get('jlpt')` 로 읽도록 수정 (현재 `'jlpt_level'`). | web-agent | XS |

### P2 — 선택적
| # | 작업 | 규모 |
|---|---|---|
| P2-1 | `fetchAdminContent` 등의 에러 핸들러가 `detail` 필드를 추출해 toast 에 전달. | S |
| P2-2 | `quiz_type` 필터 UI 추가 (QuizPage 상단 "cloze / sentence-arrange" 토글) — 현재 백엔드 지원은 있으나 UI 없음. 제품이 원하면. | S |
| P2-3 | `regenerateTts` 바디를 camelCase 로 통일 (`contentType`, `itemId`) — 현재 snake_case 로 보내지만 Pydantic alias 덕에 작동. 일관성 유지. | XS |

### 도구적 개선
- **`validate_admin_contracts.py` 추가**: `apps/api/scripts/validate_mobile_contracts.py` 를 포팅하여 admin 엔드포인트 드리프트를 CI 에서 지속 탐지. 이 감사에서 발견된 패턴(경로 세그먼트 카운트, enum 값 비교, 캐시 키 일관성)을 룰로 포함.

---

## 7. 교차 검증 메모

- 이 감사는 static analysis 만 수행. DB/러닝 서버 띄우지 않음.
- 브리프의 "확장 체크" 항목 중 **CORS, RLS, Rate limit** 은 본 라운드 스코프 밖. P0/P1 을 먼저 처리한 후 필요 시 별도 라운드.
- Codex 교차 검증 권장: 특히 §1 (FastAPI path matching 규칙) 과 §2-3 (enum 동기화 설계) 는 근거 기반 반박 받을 가치 있음.

---

## 8. 파일 변경 맵 (수정 예정)

```
P0-1: apps/admin/src/hooks/use-content-detail.ts (audit 부분만 contentType 매핑)
      또는 apps/admin/src/lib/api/admin-content.ts (fetchAuditLogs 내부 변환)
P0-2: apps/api/app/enums.py (확장 방향이면)
      + apps/api/alembic/versions/*.py (새 enum value 마이그레이션)
      + apps/admin/messages/{ko,ja,en}.json
      또는 apps/admin/src/app/(admin)/conversation/page.tsx (API 값에 맞춤)
P1-1: apps/api/app/schemas/admin_content.py (AuditLogItem.reviewer_email 추가)
      + apps/api/app/services/admin_audit_logs.py (join users)
      + apps/api/app/routers/admin_content.py (serialize)
      + apps/admin/src/lib/api/admin-content.ts (타입)
      + apps/admin/src/components/content/audit-timeline.tsx
P1-2: apps/api/app/schemas/admin_content.py (4개 list item 에 updated_at)
      + apps/api/app/services/admin_*_list.py (SELECT 에 updated_at 포함)
P1-3: apps/admin/src/hooks/use-dashboard-stats.ts 또는 use-content-detail.ts
P1-4: apps/admin/src/components/content/review-start-button.tsx:25
```

---

## 9. 완료 게이트

발견 P0 2건, P1 4건에 대해 사용자 승인 필요 — 수정 착수 전 다음 결정:
1. **P0-2**: `ScenarioCategory` 를 API 쪽 확장으로 갈지 (SHOPPING 등이 필요한지), admin 쪽 축소로 갈지 — 제품 의도에 달림
2. **P1-1**: `reviewer_id → reviewer_email` 조인을 API 가 항상 할지, admin 이 Supabase 로 별도 조회할지
3. **P1-2**: `updated_at` 을 list 응답에 포함할지, 컬럼 헤더를 "생성일"로 바꿀지

승인 후 web-agent / backend-agent 로 위임. 수정 후 `pnpm --filter admin lint/typecheck`, `cd apps/api && uv run pytest`, Codex 교차 검증, contract sync (`export_openapi.py` → `gen:api`) 실행.
