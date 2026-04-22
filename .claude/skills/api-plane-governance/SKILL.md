---
name: api-plane-governance
description: DDL authority (Alembic only), Prisma sync rules, BFF routing policy, table ownership matrix. Use when touching any database schema, migration, Next.js API Route, or cross-plane data boundary.
---

# API Plane Governance Skill

DDL(스키마)과 API 경계 거버넌스. Backend, Web, Shared Packages 에이전트가 모두 공통으로 따르는 규칙.

## Schema Authority (핵심)

- **DDL 권한**: Alembic **ONLY** (`apps/api/alembic/`)
- **Prisma DDL 금지**: `pnpm db:push`, `pnpm db:migrate` 차단됨
- 스키마 변경 흐름:
  1. `backend-agent`가 Alembic 마이그레이션 작성
  2. `backend-agent`가 SQLAlchemy 모델/Pydantic 스키마 업데이트
  3. `shared-packages-agent`에게 `pnpm db:sync` 위임 → Prisma `schema.prisma` 동기화
  4. CI의 `schema-drift` 잡이 Alembic↔Prisma 일치 검증

- **DML(데이터 읽기/쓰기)**: Prisma(웹 시딩+런타임) + SQLAlchemy(API 시딩+런타임) 공존

## Web API Route 규칙 (Next.js `apps/web/src/app/api/**`)

**도메인 로직 신규 개발은 FastAPI 우선.** Next API Route에 비즈니스 로직 신규 추가 금지.

### BFF만 허용

Next API Route는 다음 용도로만:

- **브라우저 쿠키/세션 브릿지** (`/api/auth/*`)
- **Web 전용 플랫폼 기능** (`/api/cron/*`, `/api/v1/push/*`)
- **Vercel 환경 특화 서버측 처리** (웹훅 핸들러, edge 전용 기능)

### 중복 금지

- FastAPI에 이미 있는 엔드포인트를 Web에 **새로 만들지 않음**
- 기존 중복 라우트는 유지하되, Web 기능 확장 시 **FastAPI 프록시로 점진 전환**

## 테이블 Ownership

| 영역 | 담당 ORM | 예시 |
|------|---------|------|
| 정적 콘텐츠 시딩 | **Prisma** (`seed.ts`) | Vocabulary, Grammar, Kana |
| 레슨/스테이지 시딩 | **SQLAlchemy** (Python seeds) | Chapter, Lesson, StudyStage |
| 웹 런타임 쓰기 | **Prisma** | Quiz, Conversation, Wordbook |
| 모바일 런타임 쓰기 | **SQLAlchemy** | Quiz, Lesson progress |

상세 매핑: `docs/architecture/data/table-ownership.md`

## 위반 시 복구

- Prisma DDL을 실수로 추가한 경우: 해당 마이그레이션 롤백, Alembic에 동일 변경 추가, Prisma는 `db:sync`만 실행
- 중복 엔드포인트를 Web에 추가한 경우: 기능 구현을 FastAPI로 이전, Web는 fetch proxy만 남김
