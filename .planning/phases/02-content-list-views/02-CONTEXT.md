# Phase 2: Content List Views - Context

**Gathered:** 2026-03-26
**Status:** Ready for planning

<domain>
## Phase Boundary

4개 콘텐츠 타입(단어, 문법, 퀴즈, 회화 시나리오)의 목록 조회/검색/필터링 기능. 사이드바 네비게이션, 대시보드 통계, 검증 상태 뱃지 포함. DB에 review_status 컬럼 추가(Alembic migration), FastAPI 어드민 전용 엔드포인트 구축.

</domain>

<decisions>
## Implementation Decisions

### 데이터 소스 & API
- **D-01:** 검증 상태(review_status)는 기존 콘텐츠 테이블(vocabularies, grammars, cloze_questions, sentence_arrange_questions, conversation_scenarios)에 컬럼 추가. Alembic migration으로 DDL 변경
- **D-02:** review_status 값: needs_review (기본값), approved, rejected — enum 타입
- **D-03:** 콘텐츠 조회는 FastAPI 어드민 전용 엔드포인트 (`/api/v1/admin/content/*`) 신규 작성. SQLAlchemy 쿼리
- **D-04:** 기존 모바일/웹 API에는 영향 없음 — 어드민 전용 라우터 분리

### 목록 레이아웃 & 네비게이션
- **D-05:** 목록은 테이블 형식 — 컬럼: 단어/패턴, 읽기/설명, 뜻, JLPT 레벨, 검증 상태. 콘텐츠 타입별 적절한 컬럼 조정
- **D-06:** 좌측 사이드바 네비게이션 — 대시보드, 단어, 문법, 퀴즈, 회화 5개 메뉴. Phase 1의 D-04 결정대로 사이드바 추가
- **D-07:** 페이지 번호 방식 페이지네이션 — 페이지당 20건, 1/2/3... 페이지 번호 표시

### 검증 상태 표시 & 대시보드
- **D-08:** 검증 상태 뱃지 — 색상 기반: needs_review=노란색, approved=초록색, rejected=빨간색. 테이블 행에서 즉시 식별 가능
- **D-09:** 대시보드 — 콘텐츠 타입별 4개 카드, 각 카드에 needs_review/approved/rejected 건수 + 진행률 바. Phase 1의 placeholder 카드를 실제 통계로 교체

### 검색 & 필터링 UX
- **D-10:** 검색창은 300ms debounce 실시간 검색. 타이핑 중 자동 필터링
- **D-11:** 필터 UI는 테이블 상단 인라인 배치 — 검색창 + JLPT 레벨 드롭다운 + 카테고리 드롭다운 + 상태 드롭다운이 한 줄에. 선택 즉시 적용
- **D-12:** URL 쿼리 파라미터로 필터 상태 유지 — 페이지 새로고침/공유 시 필터 보존

### Claude's Discretion
- FastAPI 어드민 엔드포인트 상세 설계 (페이지네이션 파라미터, 응답 스키마)
- Alembic migration 스크립트 세부 구현
- 테이블 컴포넌트 구조 (shadcn Table 활용 방식)
- TanStack Query 캐싱 전략
- 사이드바 컴포넌트 반응형 동작 (collapse 등)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Database Models (SQLAlchemy)
- `apps/api/app/models/content.py` — Vocabulary, Grammar, ClozeQuestion, SentenceArrangeQuestion 모델 정의
- `apps/api/app/models/conversation.py` — ConversationScenario 모델 정의
- `apps/api/app/models/enums.py` — JlptLevel, PartOfSpeech, ScenarioCategory 등 enum 정의
- `apps/api/alembic/` — Alembic migration 디렉토리 (DDL 변경은 여기서만)

### API Patterns
- `apps/api/app/routers/` — 기존 FastAPI 라우터 패턴 참조
- `apps/api/app/dependencies.py` — get_current_user 인증 패턴

### Admin App (Phase 1 산출물)
- `apps/admin/src/app/(admin)/layout.tsx` — 어드민 레이아웃 (사이드바 추가 대상)
- `apps/admin/src/app/(admin)/dashboard/page.tsx` — 대시보드 페이지 (통계 교체 대상)
- `apps/admin/src/lib/supabase/auth.ts` — requireReviewer() 인증 가드
- `apps/admin/src/components/ui/` — shadcn/ui 컴포넌트 (button, card, input, dropdown-menu 등)

### Project
- `.planning/ROADMAP.md` — Phase 2 성공 기준 5개
- `.planning/REQUIREMENTS.md` — LIST-01~07 요구사항
- `.planning/phases/01-foundation/01-CONTEXT.md` — Phase 1 결정사항 (D-04 사이드바, D-06 톤앤매너)
- `CLAUDE.md` — 프로젝트 컨벤션, 기술 스택
- `.claude/rules/api.md` — API 코드 품질 규칙
- `.claude/rules/api-plane.md` — DDL/DML 거버넌스 (Alembic only, Prisma DDL 금지)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `apps/admin/src/components/ui/card.tsx` — 대시보드 카드에 재사용
- `apps/admin/src/components/ui/dropdown-menu.tsx` — 필터 드롭다운에 재사용
- `apps/admin/src/components/ui/button.tsx`, `input.tsx` — 검색/필터 UI
- `apps/admin/src/components/layout/header.tsx` — 헤더 (사이드바 추가 시 조정 필요)
- `apps/admin/src/components/providers/query-provider.tsx` — TanStack Query 이미 설정됨

### Established Patterns
- Phase 1: proxy.ts 미들웨어 + requireReviewer() 이중 인증
- Phase 1: next-intl without-routing mode (cookie-based locale)
- CLAUDE.md: kebab-case 파일명, PascalCase 컴포넌트, camelCase 함수
- api-plane.md: DDL은 Alembic만, 도메인 로직은 FastAPI 우선

### Integration Points
- `apps/admin/src/app/(admin)/layout.tsx` — 사이드바 삽입 위치
- `apps/admin/src/app/(admin)/dashboard/page.tsx` — 통계 카드 교체
- `apps/admin/messages/ja.json`, `ko.json`, `en.json` — 새 UI 텍스트 추가

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

*Phase: 02-content-list-views*
*Context gathered: 2026-03-26*
