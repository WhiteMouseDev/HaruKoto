# HaruKoto Admin — 학습 데이터 관리 도구

## What This Is

하루코토(HaruKoto) 일본어 학습 앱의 학습 데이터를 원어민이 검증·수정·TTS 재생성할 수 있는 어드민 웹 앱.
1-3명의 일본인 원어민 친구들이 단어, 문법, 퀴즈, 회화 시나리오 데이터의 품질을 관리한다.
apps/admin으로 메인 앱과 분리된 독립 Next.js 앱, Vercel 배포.

## Core Value

원어민이 학습 데이터를 쉽고 빠르게 검증·수정할 수 있어야 한다. 비개발자도 직관적으로 사용 가능해야 한다.

## Current State

**v1.0 MVP shipped (2026-03-30)** — admin.harukoto.co.kr 운용 중

Phase 1~5 + backlog 999.1/999.3/999.4 완료:
- 인증 게이트 (Supabase Auth + reviewer role)
- 4개 콘텐츠 타입 목록/검색/필터/정렬/페이지네이션
- 편집 폼 + 승인/반려 워크플로우 + 감사 로그
- TTS 오디오 재생/재생성 (필드 리스트 UI)
- 리뷰 큐 + 대시보드 통계
- 프로덕션 수준 UI (sticky 사이드바, 색상 계층, WCAG 대비)

## Requirements

### Validated (v1.0)

- ✓ 인증/인가 (AUTH-01~03) — Phase 1
- ✓ 콘텐츠 목록/검색/필터 (LIST-01~07) — Phase 2
- ✓ 콘텐츠 편집 (EDIT-01~04) — Phase 3
- ✓ 승인/반려 워크플로우 (REVW-01~04) — Phase 3
- ✓ TTS 재생/재생성 (TTS-01~02) — Phase 4
- ✓ 리뷰 큐/대시보드/알림 (UX-01~03) — Phase 5
- ✓ 다국어 UI (I18N-01~03) — Phase 1

### Active (v1.1 후보)

- [ ] 필드별 개별 TTS 오디오 (읽기/단어/예문 각각 생성) — 999.2 백로그
- [ ] Admin content API 테스트 작성 — Codex 지적 사항
- [ ] 접근성 개선 (aria-current, skip link, nav 랜드마크)
- [ ] 하드코딩 일본어 번역 누락 수정
- [ ] 실사용자 피드백 기반 개선

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

---
*Last updated: 2026-03-30 after v1.0 milestone completion*
