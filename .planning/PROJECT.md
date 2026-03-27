# HaruKoto Admin — 학습 데이터 관리 도구

## What This Is

하루코토(HaruKoto) 일본어 학습 앱의 학습 데이터를 원어민이 검증·수정·TTS 재생성할 수 있는 어드민 웹 앱.
1-3명의 일본인 원어민 친구들이 단어, 문법, 퀴즈, 회화 시나리오 데이터의 품질을 관리한다.
apps/admin으로 메인 앱과 분리된 독립 Next.js 앱, Vercel 배포.

## Core Value

원어민이 학습 데이터를 쉽고 빠르게 검증·수정할 수 있어야 한다. 비개발자도 직관적으로 사용 가능해야 한다.

## Requirements

### Validated

<!-- 기존 하루코토 앱에서 이미 검증된 것들 -->

- ✓ Supabase Auth 기반 인증 시스템 — 메인 앱에서 운용 중
- ✓ ElevenLabs + Gemini TTS 생성 파이프라인 — FastAPI에서 운용 중
- ✓ GCS 기반 TTS 오디오 저장 — harukoto-tts 버킷 운용 중
- ✓ Vocabulary, Grammar, KanaCharacter, Quiz 데이터 모델 — Prisma + SQLAlchemy 운용 중
- ✓ Chapter/Lesson/StudyStage 계층 구조 — Alembic 마이그레이션 운용 중

### Active

- [ ] 원어민이 TTS 오디오를 재생하고 재생성을 요청할 수 있다

### Validated in Phase 3

- ✓ 원어민이 단어/어휘 데이터를 조회·수정할 수 있다 — Phase 3 완료
- ✓ 원어민이 문법/문장 데이터를 조회·수정할 수 있다 — Phase 3 완료
- ✓ 원어민이 퀴즈/문제 데이터를 조회·수정할 수 있다 — Phase 3 완료
- ✓ 원어민이 회화 시나리오 데이터를 조회·수정할 수 있다 — Phase 3 완료
- ✓ reviewer 역할 기반 접근 제어 (Supabase Auth + role) — Phase 1 완료
- ✓ 다국어 UI 지원 (한/일/영) — Phase 1 완료

### Out of Scope

- 사용자 관리/계정 관리 — 메인 앱 관할
- 결제/구독 관리 — 메인 앱 관할
- AI 대화 실시간 테스트 — 복잡도 높음, 추후 별도 마일스톤
- 학습 진도/통계 대시보드 — 메인 앱의 기능
- 데이터 대량 일괄 가져오기(CSV/Excel) — 초기에는 개별 편집으로 충분

## Context

- **기존 앱**: Turborepo 모노레포 (apps/web, apps/mobile, apps/api, packages/*)
- **DB 이중 관리**: Prisma(seed) + SQLAlchemy/Alembic(DDL) 하이브리드 구조
- **학습 데이터 현황**: Vocabulary, Grammar, KanaCharacter는 Prisma seed로 투입, chapters/lessons/study_stages는 Alembic 마이그레이션
- **TTS 파이프라인**: FastAPI → ElevenLabs(primary)/Gemini(fallback) → GCS 저장, TtsAudio 테이블에 캐시
- **인증**: Supabase Auth (JWT, JWKS 검증), 현재 role 시스템 없음 — reviewer role 추가 필요
- **사용자**: 1-3명 비개발자 일본인 원어민, 직관적이고 심플한 UI 필수

## Constraints

- **Tech Stack**: Next.js + Tailwind + shadcn/ui — 모노레포 내 기존 스택 통일
- **배포**: Vercel — 기존 인프라 활용
- **DB**: 기존 PostgreSQL(Supabase) 공유, DDL 변경은 Alembic만
- **인증**: Supabase Auth 활용, reviewer role 추가
- **TTS**: 기존 FastAPI TTS 엔드포인트 재사용
- **사용자 수**: 1-3명 소규모, 과도한 확장성 설계 불필요

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| apps/admin 별도 앱으로 분리 | 메인 앱 배포에 영향 없음, 독립 개발/배포 | — Pending |
| Supabase Auth + reviewer role | 별도 인증 시스템 불필요, 기존 인프라 활용 | — Pending |
| 기존 FastAPI TTS 엔드포인트 재사용 | TTS 로직 중복 방지, 일관된 파이프라인 | — Pending |
| 다국어 UI (한/일/영) | 일본인 원어민 + 한국인 개발자 모두 사용 | — Pending |

---
*Last updated: 2026-03-27 after Phase 3 (Content Editing & Review Workflow) completion*
