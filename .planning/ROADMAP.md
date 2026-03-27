# Roadmap: HaruKoto Admin

## Overview

HaruKoto Admin는 5단계로 전달됩니다. 먼저 안전하게 배포 가능한 기반(앱 스캐폴딩, 인증, i18n)을 구축하고, 읽기 전용 콘텐츠 목록 뷰를 추가하고, 편집 폼과 검토 워크플로우로 핵심 가치를 전달하고, TTS 오디오 재생·재생성 기능을 추가한 뒤, 마지막으로 리뷰 큐·알림 등 생산성 기능으로 완성합니다. 모든 단계는 이전 단계에 의존하며, 각 단계는 실제로 검증 가능한 기능을 완성합니다.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - apps/admin 스캐폴딩, 인증 게이트, i18n 설정, Vercel 배포 (completed 2026-03-26)
- [x] **Phase 2: Content List Views** - 4개 콘텐츠 타입 목록, 검색·필터·페이지네이션, 대시보드 (completed 2026-03-26)
- [x] **Phase 3: Content Editing & Review Workflow** - 편집 폼, 승인/반려 워크플로우, 감사 로그 (completed 2026-03-27)
- [ ] **Phase 4: TTS Audio** - 오디오 재생, 재생성 요청, FastAPI 엔드포인트 연동
- [x] **Phase 5: Reviewer Productivity** - 리뷰 큐 탐색, 일괄 상태 변경, 알림 (completed 2026-03-27)

## Phase Details

### Phase 1: Foundation
**Goal**: Reviewer가 안전하게 어드민에 접근할 수 있고, 앱이 Vercel에 배포되어 있으며, UI가 일본어로 표시된다
**Depends on**: Nothing (first phase)
**Requirements**: AUTH-01, AUTH-02, AUTH-03, I18N-01, I18N-02, I18N-03
**Success Criteria** (what must be TRUE):
  1. Reviewer가 이메일/비밀번호로 로그인하면 어드민 대시보드로 이동한다
  2. reviewer 역할이 없는 계정으로 로그인 시도하면 접근이 차단되고 오류 메시지가 표시된다
  3. reviewer 역할이 DB에서 제거된 후 페이지를 새로고침하면 즉시 로그아웃된다
  4. UI가 일본어로 표시되며, 언어 전환 컨트롤로 한국어·영어로 전환할 수 있다
  5. Vercel 배포 URL에서 앱이 정상적으로 로드된다
**Plans**: 4 plans

Plans:
- [x] 01-01-PLAN.md — Scaffold apps/admin with configs, Supabase clients, i18n infra, root layout, test scaffolds
- [x] 01-02-PLAN.md — Auth gate: proxy.ts route guard, login page, reviewer provisioning, Codex verification
- [x] 01-03-PLAN.md — Admin shell: header layout, dashboard stub, locale switcher
- [x] 01-04-PLAN.md — Vercel deployment and end-to-end verification

**UI hint**: yes

### Phase 2: Content List Views
**Goal**: Reviewer가 4개 콘텐츠 타입의 데이터를 조회·검색·필터링할 수 있다
**Depends on**: Phase 1
**Requirements**: LIST-01, LIST-02, LIST-03, LIST-04, LIST-05, LIST-06, LIST-07
**Success Criteria** (what must be TRUE):
  1. Reviewer가 단어·문법·퀴즈·회화 시나리오 각각의 목록 페이지에서 페이지네이션으로 데이터를 탐색할 수 있다
  2. 목록에서 JLPT 레벨, 카테고리, 검증 상태(needs_review/approved/rejected)로 필터링하면 결과가 즉시 반영된다
  3. 검색창에 텍스트를 입력하면 해당 텍스트가 포함된 항목만 표시된다
  4. 각 목록 행에 검증 상태 뱃지(needs_review/approved/rejected)가 시각적으로 표시된다
  5. 대시보드에서 콘텐츠 타입별 검증 현황(상태별 건수)을 한눈에 확인할 수 있다
**Plans**: 3 plans

Plans:
- [x] 02-01-PLAN.md — Alembic migration + ReviewStatus enum + FastAPI admin content endpoints
- [x] 02-02-PLAN.md — Sidebar navigation + shadcn Table + shared UI components (StatusBadge, FilterBar, PaginationBar) + i18n
- [x] 02-03-PLAN.md — Content list pages + dashboard stats wired to FastAPI via TanStack Query

**UI hint**: yes

### Phase 3: Content Editing & Review Workflow
**Goal**: Reviewer가 콘텐츠를 수정하고 승인 또는 반려 결정을 내릴 수 있으며, 모든 이력이 기록된다
**Depends on**: Phase 2
**Requirements**: EDIT-01, EDIT-02, EDIT-03, EDIT-04, REVW-01, REVW-02, REVW-03, REVW-04
**Success Criteria** (what must be TRUE):
  1. Reviewer가 단어·문법·퀴즈·회화 시나리오 편집 폼에서 필드를 수정하고 저장하면 DB에 반영된다
  2. 편집 화면에서 승인 버튼을 누르면 항목 상태가 approved로 변경된다
  3. 반려 버튼을 누르면 사유 입력 다이얼로그가 표시되고, 사유를 입력해야 rejected 상태로 변경된다
  4. 목록에서 여러 항목을 체크박스로 선택하고 일괄 승인/반려할 수 있다
  5. 항목 상세 페이지의 감사 로그 섹션에서 최근 수정·승인·반려 이력이 확인된다
**Plans**:
  - Plan 01 (Wave 1): Foundation — Alembic audit_logs migration, AuditLog model, shadcn Dialog/Textarea/Checkbox install, Pydantic schema extensions, test stubs
  - Plan 02 (Wave 1): Backend — GET single, PATCH update, POST review, batch-review, audit-logs endpoints (depends on 03-01)
  - Plan 03 (Wave 2): Frontend — 4 edit pages (RHF+Zod), review header, reject dialog, bulk toolbar, audit timeline, i18n
**UI hint**: yes

### Phase 4: TTS Audio
**Goal**: Reviewer가 편집 화면에서 TTS 오디오를 재생하고, 필요 시 재생성을 요청할 수 있다
**Depends on**: Phase 3
**Requirements**: TTS-01, TTS-02
**Success Criteria** (what must be TRUE):
  1. 편집 화면에서 오디오 플레이어가 표시되고 기존 TTS 오디오를 재생할 수 있다
  2. 재생성 버튼을 누르면 확인 다이얼로그가 표시되고, 확인 후 FastAPI를 통해 재생성이 진행되며, 완료 후 새 오디오가 플레이어에 표시된다
  3. ~~재생성 후 10분 이내에 같은 항목의 재생성을 다시 시도하면 쿨다운 안내 메시지가 표시된다~~ (descoped: 어드민 도구이므로 쿨다운 불필요 — QA 피드백 반영)
**Plans**: 2 plans

Plans:
- [x] 04-01-PLAN.md — FastAPI admin TTS endpoints (GET fetch + POST regenerate with Redis cooldown) + pytest tests
- [x] 04-02-PLAN.md — TtsPlayer component, useTtsPlayer hook, i18n, integration into 4 edit pages + human verification

**UI hint**: yes

### Phase 5: Reviewer Productivity
**Goal**: Reviewer가 리뷰 큐로 needs_review 항목을 순서대로 효율적으로 처리하고, 새 데이터 알림을 받을 수 있다
**Depends on**: Phase 3
**Requirements**: UX-01, UX-02, UX-03
**Success Criteria** (what must be TRUE):
  1. 리뷰 큐 진입 후 다음/이전 버튼으로 needs_review 항목을 순서대로 탐색할 수 있다
  2. 대시보드에서 전체 검증 진행률(%)과 카테고리별 현황이 시각적으로 표시된다
  3. 새로 추가되거나 변경된 데이터가 있을 때 알림 표시가 나타난다
**Plans**: 3 plans

Plans:
- [x] 05-01-PLAN.md — FastAPI review-queue endpoint + Pydantic schemas + pytest + frontend API function
- [x] 05-02-PLAN.md — Sidebar needs_review badges + dashboard quiz stats fix + Phase 5 i18n keys
- [x] 05-03-PLAN.md — Review queue frontend: useReviewQueue hook, QueueNavigationBar, ReviewStartButton, wire into 4 content types + human verification

**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 4/4 | Complete   | 2026-03-26 |
| 2. Content List Views | 0/3 | Not started | - |
| 3. Content Editing & Review Workflow | 3/3 | Complete   | 2026-03-27 |
| 4. TTS Audio | 1/2 | In Progress|  |
| 5. Reviewer Productivity | 3/3 | Complete   | 2026-03-27 |

## Backlog

### Phase 999.1: TTS 필드 UI 개선 — select → 전체 필드 목록 (BACKLOG)

**Goal:** 드롭다운 대신 읽기/단어/예문 등 전체 필드를 리스트로 표시하여, 리뷰어가 각 필드의 TTS 유무를 한눈에 파악하고 빠진 것만 바로 생성할 수 있도록 개선
**Requirements:** BACKLOG-999.1
**Plans:** 2 plans

Plans:
- [ ] 999.1-01-PLAN.md — Refactor useTtsPlayer hook + TtsPlayer component: Select dropdown to vertical field list
- [ ] 999.1-02-PLAN.md — Human verification of TTS field list UI on all 4 content types
