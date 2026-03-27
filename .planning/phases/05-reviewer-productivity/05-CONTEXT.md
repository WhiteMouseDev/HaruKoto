# Phase 5: Reviewer Productivity - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

리뷰 큐(needs_review 항목 순차 탐색 + 승인/반려 후 자동 다음 이동), 대시보드 진행률 프로그레스 바, 사이드바 needs_review 뱃지 알림.

</domain>

<decisions>
## Implementation Decisions

### 리뷰 큐 탐색
- **D-01:** 목록 페이지에서 진입 — 「リビュー開始」 버튼 클릭 시 첫 번째 needs_review 항목 편집 페이지로 이동. 현재 필터 상태(JLPT, 카테고리)를 유지하면서 탐색
- **D-02:** 다음/이전 네비게이션 — 편집 페이지에 다음/이전 버튼 표시. needs_review 항목만 대상으로 순서대로 이동
- **D-03:** 승인/반려 후 자동 이동 — 승인 또는 반려 완료 시 토스트 표시 후 자동으로 다음 needs_review 항목으로 이동. 마지막 항목이면 목록 페이지로 복귀

### 대시보드 진행률
- **D-04:** 프로그레스 바 추가 — 기존 StatsCard에 approved/(total) 비율 프로그레스 바 + 퍼센트 표시 추가. 카테고리별로 각각 표시

### 새 데이터 알림
- **D-05:** 헤더/사이드바 뱃지 — 각 콘텐츠 타입 메뉴 옆에 needs_review 상태 항목 수 뱃지 표시. 클릭하면 해당 목록으로 이동
- **D-06:** 기준은 needs_review 상태 항목 수 — 추가 테이블이나 시간 추적 불필요. 기존 review_status 필드를 카운트

### Claude's Discretion
- 리뷰 큐 정렬 순서 (created_at ASC가 자연스러움)
- 다음/이전 버튼 위치와 디자인
- 뱃지 폴링 주기 (페이지 로드 시 vs 주기적 갱신)
- 프로그레스 바 색상과 스타일
- 리뷰 큐 내 현재 위치 표시 (N/M 형식)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 3 산출물 (직접 확장)
- `apps/admin/src/components/content/review-header.tsx` — 승인/반려 버튼 (자동 이동 로직 추가 대상)
- `apps/admin/src/hooks/use-content-list.ts` — 목록 훅 (리뷰 큐 진입 시 needs_review 필터)
- `apps/admin/src/components/content/content-table.tsx` — 목록 테이블 (리뷰 시작 버튼 추가)
- `apps/api/app/routers/admin_content.py` — 어드민 API (리뷰 큐 ID 목록 조회 엔드포인트 추가)

### Phase 2 산출물 (확장)
- `apps/admin/src/app/(admin)/dashboard/page.tsx` — 대시보드 (프로그레스 바 추가)
- `apps/admin/src/components/features/dashboard/stats-card.tsx` — StatsCard 컴포넌트
- `apps/admin/src/hooks/use-dashboard-stats.ts` — 대시보드 통계 훅

### Layout & Navigation
- `apps/admin/src/app/(admin)/layout.tsx` — 사이드바 레이아웃 (뱃지 추가 대상)
- `apps/admin/src/components/layout/` — 레이아웃 컴포넌트들

### Project
- `.planning/ROADMAP.md` — Phase 5 성공 기준 3개
- `.planning/REQUIREMENTS.md` — UX-01, UX-02, UX-03
- `CLAUDE.md` — 프로젝트 컨벤션

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `apps/admin/src/hooks/use-content-list.ts` — 목록 훅 (status 필터 기능 이미 있음 → needs_review 필터링 활용)
- `apps/admin/src/components/content/review-header.tsx` — ReviewHeader (승인/반려 후 콜백 추가)
- `apps/admin/src/hooks/use-dashboard-stats.ts` — 대시보드 통계 (needs_review 카운트 이미 제공)
- `apps/admin/src/components/features/dashboard/stats-card.tsx` — StatsCard (프로그레스 바 추가)
- `sonner` — 토스트 (승인/반려 결과 + 자동 이동 안내)

### Established Patterns
- Phase 3: TanStack Query + NEXT_PUBLIC_FASTAPI_URL 직접 호출
- Phase 3: URL searchParams 기반 상태 관리 (필터 유지에 활용)
- Phase 4: useMutation onSuccess 콜백 (승인/반려 후 자동 이동 패턴)
- Phase 2: 대시보드 통계 API `/api/v1/admin/content/stats`

### Integration Points
- 4개 편집 페이지에 다음/이전 네비게이션 추가
- ReviewHeader에 승인/반려 후 onNext 콜백 추가
- 사이드바 메뉴에 needs_review 카운트 뱃지 추가
- StatsCard에 프로그레스 바 추가
- 목록 페이지에 「리뷰 시작」 버튼 추가

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

- 999.1: TTS 필드 UI 개선 (select → 전체 필드 목록 표시) — 별도 백로그
- v2 AUX-01: 키보드 단축키 (J/K, A/R) — v2 요구사항
- v2 AUX-02: 수정 전/후 비교(diff) 뷰 — v2 요구사항
- v2 AUX-03: 리뷰어 간 코멘트/토론 — v2 요구사항

</deferred>

---

*Phase: 05-reviewer-productivity*
*Context gathered: 2026-03-27*
