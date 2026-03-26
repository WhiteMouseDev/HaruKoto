# Phase 3: Content Editing & Review Workflow - Context

**Gathered:** 2026-03-26
**Status:** Ready for planning

<domain>
## Phase Boundary

4개 콘텐츠 타입(단어, 문법, 퀴즈, 회화)의 편집 폼, 승인/반려 워크플로우, 일괄 처리, 감사 로그(audit log). FastAPI PATCH 엔드포인트 + audit_logs 테이블(Alembic) + 편집 페이지 UI.

</domain>

<decisions>
## Implementation Decisions

### 편집 폼 레이아웃
- **D-01:** 전용 편집 페이지 — `/vocabulary/[id]`, `/grammar/[id]` 등 상세 페이지에서 직접 편집. 편집 폼 + 승인/반려 + 감사 로그가 한 페이지에
- **D-02:** 편집 후 같은 페이지 유지 + 성공 토스트 표시. 연속 수정에 편리하도록 리다이렉트 없음
- **D-03:** 필드 검증은 submit 시에만 (Phase 1 D-03 유지). 에러는 필드 옆에 인라인 표시

### 승인/반려 워크플로우
- **D-04:** 승인/반려 버튼은 편집 페이지 상단 — 현재 상태 뱃지와 함께 표시. 수정 후 바로 승인 가능
- **D-05:** 반려 시 모달 다이얼로그 — 텍스트 입력 + 확인 버튼. 사유 필수 입력
- **D-06:** 일괄 처리 — 목록 테이블에 체크박스 추가, 선택 시 상단에 "선택 {N}개: 승인 | 반려" 툴바 표시
- **D-07:** 일괄 반려도 사유 모달 표시 (선택된 모든 항목에 동일 사유 적용)

### 감사 로그 & 이력
- **D-08:** 감사 로그는 타임라인 형식 — 시간순으로 이력 표시: 시간 + 작업자 + 액션(수정/승인/반려) + 변경 요약
- **D-09:** 감사 로그 위치는 편집 페이지 하단 — 편집 폼 아래에 감사 로그 섹션
- **D-10:** audit_logs 테이블 신규 생성 (Alembic migration) — content_type, content_id, action, changes(JSON), reason, reviewer_id, created_at

### 데이터 수정 API
- **D-11:** PATCH 방식 — 변경된 필드만 전송. 1-3명 사용이라 동시 충돌 처리 불필요
- **D-12:** FastAPI 어드민 전용 엔드포인트 확장 — 기존 `/api/v1/admin/content/*` 라우터에 PATCH/POST 추가
- **D-13:** 승인/반려 전용 엔드포인트 — `POST /api/v1/admin/content/{type}/{id}/review` (action: approve/reject, reason)

### Claude's Discretion
- 편집 폼 필드 레이아웃 세부 배치 (그리드, 순서)
- React Hook Form + Zod 스키마 설계
- audit_logs 테이블 인덱스 전략
- 타임라인 컴포넌트 디자인 세부
- 일괄 처리 API 설계 (배치 엔드포인트 구조)
- 편집 페이지 로딩 스켈레톤

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 2 산출물 (직접 확장)
- `apps/api/app/routers/admin_content.py` — 기존 GET 엔드포인트에 PATCH/POST 추가
- `apps/api/app/schemas/admin_content.py` — 기존 응답 스키마 확장
- `apps/api/app/models/content.py` — Vocabulary, Grammar, ClozeQuestion, SentenceArrangeQuestion 모델
- `apps/api/app/models/conversation.py` — ConversationScenario 모델
- `apps/api/app/enums.py` — ReviewStatus enum
- `apps/admin/src/lib/api/admin-content.ts` — API 클라이언트 확장
- `apps/admin/src/hooks/use-content-list.ts` — 기존 목록 훅 (일괄 처리 시 invalidation)
- `apps/admin/src/components/ui/status-badge.tsx` — 상태 뱃지 재사용
- `apps/admin/src/components/content/content-table.tsx` — 체크박스 추가 대상
- `apps/admin/src/components/content/filter-bar.tsx` — 필터바 재사용

### Database
- `apps/api/alembic/` — Alembic migration (audit_logs 테이블 신규)
- `apps/api/app/models/enums.py` — enum 정의

### UI Components
- `apps/admin/src/components/ui/` — shadcn components (button, card, input, label, form, dialog, sonner)

### Project
- `.planning/ROADMAP.md` — Phase 3 성공 기준 5개
- `.planning/REQUIREMENTS.md` — EDIT-01~04, REVW-01~04
- `.planning/phases/02-content-list-views/02-CONTEXT.md` — Phase 2 결정사항
- `CLAUDE.md` — 프로젝트 컨벤션
- `.claude/rules/api.md` — API 코드 품질 규칙
- `.claude/rules/api-plane.md` — DDL/DML 거버넌스

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `apps/admin/src/components/ui/status-badge.tsx` — 상태 뱃지 (편집 페이지 상단에서 재사용)
- `apps/admin/src/components/content/content-table.tsx` — ContentTable (체크박스 컬럼 추가)
- `apps/admin/src/lib/api/admin-content.ts` — fetchAdminContent (PATCH/POST 함수 추가)
- `apps/admin/src/hooks/use-content-list.ts` — 목록 훅 (일괄 처리 후 invalidation)
- `apps/admin/src/components/ui/dialog.tsx` — shadcn Dialog (반려 사유 모달에 사용)
- `sonner` — 토스트 (저장 성공/에러 표시)

### Established Patterns
- Phase 2: FastAPI admin router + require_reviewer dependency
- Phase 2: TanStack Query + NEXT_PUBLIC_FASTAPI_URL 직접 호출
- Phase 2: URL searchParams 기반 상태 관리
- Phase 1: React Hook Form + Zod (CLAUDE.md에 명시)
- Phase 1: submit 시에만 검증 (D-03)

### Integration Points
- `/vocabulary/[id]`, `/grammar/[id]`, `/quiz/[id]`, `/conversation/[id]` 페이지 신규
- `content-table.tsx` 체크박스 + 일괄 처리 툴바 추가
- `admin_content.py` 라우터에 PATCH + review 엔드포인트 추가
- `messages/*.json` i18n 키 추가 (편집 폼, 승인/반려, 감사 로그)

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-content-editing-review-workflow*
*Context gathered: 2026-03-26*
