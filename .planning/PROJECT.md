# HaruKoto Admin — 학습 데이터 관리 도구

## What This Is

하루코토(HaruKoto) 일본어 학습 앱의 학습 데이터를 원어민이 검증·수정·TTS 재생성할 수 있는 어드민 웹 앱.
1-3명의 일본인 원어민 친구들이 단어, 문법, 퀴즈, 회화 시나리오 데이터의 품질을 관리한다.
apps/admin으로 메인 앱과 분리된 독립 Next.js 앱, Vercel 배포.

## Core Value

원어민이 학습 데이터를 쉽고 빠르게 검증·수정할 수 있어야 한다. 비개발자도 직관적으로 사용 가능해야 한다.

## Current State

**v1.1 Quality & Polish shipped (2026-04-23)** — admin.harukoto.co.kr 운용 중, 필드별 TTS + i18n + 접근성 보강 완료.

<details>
<summary>v1.0 MVP shipped 2026-03-30 (Phases 1-5 + 999.x backlog)</summary>

Phase 1~5 + backlog 999.1/999.3/999.4 완료:
- 인증 게이트 (Supabase Auth + reviewer role)
- 4개 콘텐츠 타입 목록/검색/필터/정렬/페이지네이션
- 편집 폼 + 승인/반려 워크플로우 + 감사 로그
- TTS 오디오 재생/재생성 (필드 리스트 UI)
- 리뷰 큐 + 대시보드 통계
- 프로덕션 수준 UI (sticky 사이드바, 색상 계층, WCAG 대비)
</details>

**v1.1 shipped contents:**
- Phase 6 (2026-03-31) — 필드별 독립 TTS 오디오 생성·재생·재생성
- Phase 7 (2026-04-02) — i18n 완성 (173 키, CJK 하드코딩 제거) + 접근성 (aria-current, skip link, 랜드마크, 검색 라벨)
- Phase 8 (2026-04-02) — i18n 갭 클로저: TTS 훅 toast i18n 전환 + hardcoded-strings 테스트 .ts 확장

**Post-milestone hardening (2026-04-23):**
- admin↔api consistency audit: 8 drifts closed (commits 35d85ea → 67ba6a6)
- v1.1 milestone re-audit: status `gaps_found` → `passed` (9/9 reqs, 4/4 flows)
- P0-2 silent-fail 분류 + observability 강화 (chat_voice.py)
- `validate_admin_contracts.py` CI guard 추가

## Next Milestone: v1.2 (planning)

Scope TBD. Leading candidate: **Ch.01 파일럿 콘텐츠 제작** (`docs/domain/learning/n5-curriculum-map.md` 참고). Use `/gsd:new-milestone` to define requirements.

## Requirements

### Validated (v1.0)

- ✓ 인증/인가 (AUTH-01~03) — Phase 1
- ✓ 콘텐츠 목록/검색/필터 (LIST-01~07) — Phase 2
- ✓ 콘텐츠 편집 (EDIT-01~04) — Phase 3
- ✓ 승인/반려 워크플로우 (REVW-01~04) — Phase 3
- ✓ TTS 재생/재생성 (TTS-01~02) — Phase 4
- ✓ 리뷰 큐/대시보드/알림 (UX-01~03) — Phase 5
- ✓ 다국어 UI (I18N-01~03) — Phase 1

### Validated (v1.1)

- ✓ 필드별 개별 TTS 오디오 (TTS-03~05) — Phase 6
- ✓ 접근성 개선 (A11Y-01~04) — Phase 7
- ✓ 하드코딩 일본어 번역 완성 (I18N-04~05) — Phase 7+8

### Active (v1.2)

(none yet — define via `/gsd:new-milestone`)

### Deferred

- Admin content API 테스트 작성 — Codex 지적, 인프라 작업으로 별도 처리
- 다크 모드 — 사용자 요청 없음, 작업량 대비 효과 낮음

### Out of Scope

- 사용자 관리/계정 관리 — 메인 앱 관할
- 결제/구독 관리 — 메인 앱 관할
- AI 대화 실시간 테스트 — 복잡도 높음, 별도 마일스톤
- 학습 진도/통계 대시보드 — 메인 앱 기능
- 데이터 대량 일괄 가져오기(CSV/Excel) — 초기에는 개별 편집으로 충분
- 모바일 반응형 — 데스크톱 전용 도구

## Context

- **기존 앱**: Turborepo 모노레포 (apps/web, apps/mobile, apps/api, packages/*)
- **DB 이중 관리**: Prisma(seed) + SQLAlchemy/Alembic(DDL) 하이브리드 구조
- **TTS 파이프라인**: FastAPI → ElevenLabs(primary)/Gemini(fallback) → GCS 저장, TtsAudio 테이블에 캐시
- **인증**: Supabase Auth (JWT), reviewer role은 app_metadata.reviewer claim
- **사용자**: 1-3명 비개발자 일본인 원어민

## Constraints

- **Tech Stack**: Next.js 16 + Tailwind CSS 4 + shadcn/ui — 모노레포 내 기존 스택 통일
- **배포**: Vercel — 기존 인프라 활용
- **DB**: 기존 PostgreSQL(Supabase) 공유, DDL 변경은 Alembic만
- **인증**: Supabase Auth 활용, reviewer role
- **TTS**: 기존 FastAPI TTS 엔드포인트 재사용
- **사용자 수**: 1-3명 소규모

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| apps/admin 별도 앱으로 분리 | 메인 앱 배포에 영향 없음, 독립 개발/배포 | ✓ Good |
| Supabase Auth + reviewer role | 별도 인증 시스템 불필요, 기존 인프라 활용 | ✓ Good |
| 기존 FastAPI TTS 엔드포인트 재사용 | TTS 로직 중복 방지, 일관된 파이프라인 | ✓ Good |
| 다국어 UI (한/일/영) | 일본인 원어민 + 한국인 개발자 모두 사용 | ✓ Good |
| Header 제거, Sidebar만 사용 | 중복 제거, 업계 표준 어드민 레이아웃 | ✓ Good |
| TanStack Table 미도입 | 현재 규모에서 커스텀 테이블 충분 | ✓ Good (Codex 확인) |
| 서버사이드 정렬/페이지네이션 | 클라이언트 정렬은 대량 데이터에 부적합 | ✓ Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-23 after v1.1 milestone archive*
