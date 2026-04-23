# Roadmap: HaruKoto Admin

## Milestones

- ✅ **v1.0 MVP** - Phases 1-5 + 999.x backlog (shipped 2026-03-30)
- ✅ **v1.1 Quality & Polish** - Phases 6-8 (completed 2026-04-23, all gaps closed)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-5 + backlog) - SHIPPED 2026-03-30</summary>

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - apps/admin 스캐폴딩, 인증 게이트, i18n 설정, Vercel 배포 (completed 2026-03-26)
- [x] **Phase 2: Content List Views** - 4개 콘텐츠 타입 목록, 검색·필터·페이지네이션, 대시보드 (completed 2026-03-26)
- [x] **Phase 3: Content Editing & Review Workflow** - 편집 폼, 승인/반려 워크플로우, 감사 로그 (completed 2026-03-27)
- [x] **Phase 4: TTS Audio** - 오디오 재생, 재생성 요청, FastAPI 엔드포인트 연동 (completed 2026-03-27)
- [x] **Phase 5: Reviewer Productivity** - 리뷰 큐 탐색, 일괄 상태 변경, 알림 (completed 2026-03-27)

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
**Plans**: 3 plans

Plans:
- [x] 03-01-PLAN.md — Alembic audit_logs migration, AuditLog model, shadcn installs, Pydantic schema extensions, test stubs
- [x] 03-02-PLAN.md — Backend: GET single, PATCH update, POST review, batch-review, audit-logs endpoints
- [x] 03-03-PLAN.md — Frontend: 4 edit pages (RHF+Zod), review header, reject dialog, bulk toolbar, audit timeline, i18n

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

## Backlog (v1.0 era)

### Phase 999.1: TTS 필드 UI 개선 — select → 전체 필드 목록 (BACKLOG)

**Goal:** 드롭다운 대신 읽기/단어/예문 등 전체 필드를 리스트로 표시하여, 리뷰어가 각 필드의 TTS 유무를 한눈에 파악하고 빠진 것만 바로 생성할 수 있도록 개선
**Requirements:** BACKLOG-999.1
**Plans:** 2/2 plans complete

Plans:
- [x] 999.1-01-PLAN.md — Refactor useTtsPlayer hook + TtsPlayer component: Select dropdown to vertical field list
- [ ] 999.1-02-PLAN.md — Human verification of TTS field list UI on all 4 content types

### Phase 999.3: Admin UI 폴리시 (BACKLOG)

**Goal:** 헤더/사이드바 중복 정리, 뱃지 색상 개선, 대시보드 프로덕션 수준 디자인, 레이아웃 일관성 개선
**Requirements:** BACKLOG-999.3
**Plans:** 2/2 plans complete

Plans:
- [x] 999.3-01-PLAN.md — Remove Header, consolidate identity into sidebar, fix badge color to informational pink
- [x] 999.3-02-PLAN.md — Color-code dashboard StatsCard counts with visual hierarchy

### Phase 999.4: 테이블 시스템 개선 (BACKLOG)

**Goal:** 퀴즈 API 계약 수정, 서버사이드 정렬 지원, FilterBar URL 동기화, selection 초기화, conversation JLPT 필터 숨김
**Requirements:** BACKLOG-999.4
**Plans:** 3/3 plans complete

Plans:
- [x] 999.4-01-PLAN.md — Backend: Quiz API contract fix, real SQL pagination, sort_by/sort_order on all list endpoints
- [x] 999.4-02-PLAN.md — Frontend shared: FilterBar URL sync, conversation JLPT hide, selection reset, placeholderData
- [x] 999.4-03-PLAN.md — Frontend quiz + sorting: Fix quiz type/links, sortable column headers on all tables

</details>

---

### v1.1 Quality & Polish (Completed 2026-04-23)

**Milestone Goal:** v1.0의 품질 미비 사항 해결 — 필드별 TTS, 번역 완성, 접근성 개선

- [x] **Phase 6: TTS Per-Field Audio** - TtsAudio DB 스키마 확장, FastAPI API 변경, 프론트엔드 훅·컴포넌트 업데이트 (verified 2026-03-30)
- [x] **Phase 7: i18n Completion & Accessibility** - 하드코딩 일본어 번역 완성, aria-current·skip link·랜드마크·검색 라벨 추가 (verified 2026-04-01)
- [x] **Phase 8: i18n Gap Closure — TTS Hook Toast** - useTtsPlayer 하드코딩 일본어 toast를 i18n으로 교체, 테스트 scope 확장 (completed 2026-04-02; re-audited 2026-04-23 — all gaps closed)

## Phase Details

### Phase 6: TTS Per-Field Audio
**Goal**: Reviewer가 단어 편집 화면에서 읽기/단어/예문 각 필드별로 독립적인 TTS 오디오를 생성·재생할 수 있으며, 기존 데이터가 마이그레이션 후에도 정상 동작한다
**Depends on**: Phase 5 (v1.0 complete)
**Requirements**: TTS-03, TTS-04, TTS-05
**Success Criteria** (what must be TRUE):
  1. 단어 편집 화면에서 읽기(reading), 단어(word), 예문(example) 각각에 별도 오디오 재생 버튼과 재생성 버튼이 표시된다
  2. 한 필드의 오디오를 재생성해도 다른 필드의 오디오에는 영향이 없다
  3. 마이그레이션 후 기존 아이템당 1개 오디오가 field=null 또는 기본 필드로 정상 조회·재생된다
  4. 문법·퀴즈·회화 시나리오 편집 화면에서도 해당 콘텐츠 타입에 맞는 필드별 TTS UI가 동작한다
**Plans**: 2 plans

Plans:
- [x] 06-01-PLAN.md — Backend: Alembic migration (field column + backfill + UniqueConstraint), TtsAudio model, Pydantic schemas, API endpoint changes, tts.py compat, pytest
- [x] 06-02-PLAN.md — Frontend: tts-fields grammar update, API types for map response, useTtsPlayer hook refactor, TtsPlayer per-field state, i18n, Vitest tests

**UI hint**: yes

### Phase 7: i18n Completion & Accessibility
**Goal**: UI의 모든 텍스트가 선택된 언어로 표시되고, 스크린 리더와 키보드 사용자가 어드민을 탐색할 수 있다
**Depends on**: Phase 6
**Requirements**: I18N-04, I18N-05, A11Y-01, A11Y-02, A11Y-03, A11Y-04
**Success Criteria** (what must be TRUE):
  1. 언어를 한국어·영어·일본어로 전환했을 때 화면에 하드코딩 일본어 문자열이 남지 않는다
  2. 사이드바 활성 항목에 시각적 강조와 함께 aria-current="page" 속성이 설정된다
  3. 페이지 상단에 "메인 콘텐츠로 건너뛰기" skip link가 존재하고, 키보드 포커스 시 표시된다
  4. nav, aside, main 영역에 스크린 리더가 읽을 수 있는 aria-label이 부여된다
  5. 검색 입력 필드에 연결된 명시적 label 요소가 존재한다
**Plans**: 3 plans

Plans:
- [x] 07-01-PLAN.md — Locale files: add all new i18n keys (table.col, edit, validation, time, category, a11y) + key parity and hardcoded string detection tests
- [x] 07-02-PLAN.md — i18n string replacements: table headers, toasts, Zod errors, placeholders, aria-labels, cancel, audit timeline, categories
- [x] 07-03-PLAN.md — Accessibility: aria-current on sidebar, skip link, landmark aria-labels, search input label + a11y tests

**UI hint**: yes

### Phase 8: i18n Gap Closure — TTS Hook Toast
**Goal**: TTS 재생성 toast 메시지가 선택된 locale에 맞게 표시되고, hardcoded string 감지 테스트가 .ts 파일도 커버한다
**Depends on**: Phase 7
**Requirements**: I18N-04, I18N-05
**Gap Closure**: Closes gaps from v1.1 milestone audit
**Success Criteria** (what must be TRUE):
  1. TTS 재생성 성공/실패 toast가 선택된 locale(ko/ja/en)에 맞게 표시된다
  2. useTtsPlayer hook에 하드코딩 CJK 문자열이 없다
  3. hardcoded-strings.test.ts가 .tsx + .ts 파일 모두 스캔하고 통과한다
**Plans**: 1 plan

Plans:
- [x] 08-01-PLAN.md — Replace hardcoded Japanese toast in useTtsPlayer with i18n + extend hardcoded-strings test to .ts files

## Progress

**Execution Order:**
Phases execute in numeric order: 6 → 7 → 8

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation | v1.0 | 4/4 | Complete | 2026-03-26 |
| 2. Content List Views | v1.0 | 3/3 | Complete | 2026-03-26 |
| 3. Content Editing & Review Workflow | v1.0 | 3/3 | Complete | 2026-03-27 |
| 4. TTS Audio | v1.0 | 2/2 | Complete | 2026-03-27 |
| 5. Reviewer Productivity | v1.0 | 3/3 | Complete | 2026-03-27 |
| 6. TTS Per-Field Audio | v1.1 | 0/2 | Planning | - |
| 7. i18n Completion & Accessibility | v1.1 | 2/3 | In Progress|  |
| 8. i18n Gap Closure — TTS Hook Toast | v1.1 | 1/1 | Complete   | 2026-04-02 |
