---
paths:
  - "apps/web/src/app/api/**"
  - "apps/api/**"
---

# API Plane 정책 (DDL/DML 거버넌스)

## Schema Authority
- **DDL 권한**: Alembic ONLY (`apps/api/alembic/`)
- **Prisma DDL 금지**: `db:push`, `db:migrate` 차단됨. 스키마 변경은 Alembic → `pnpm db:sync`
- **DML**: Prisma(웹 시딩+런타임) + SQLAlchemy(API 시딩+런타임) 공존

## Web API Route 규칙 (핵심)
- **도메인 로직 신규 개발**: FastAPI 우선. Next API Route에 비즈니스 로직 신규 추가 금지
- **중복 엔드포인트 신규 추가 금지**: FastAPI에 이미 있는 엔드포인트를 Web에 새로 만들지 않음
- **BFF만 허용**: Next API Route는 아래 용도로만 사용
  - 브라우저 쿠키/세션 브릿지 (`/api/auth/*`)
  - Web 전용 플랫폼 기능 (`/api/cron/*`, `/api/v1/push/*`)
  - Vercel 환경 특화 서버측 처리
- **기존 중복 라우트**: 현재는 유지. Web 기능 확장 시 FastAPI 프록시로 점진 전환

## 테이블 Ownership 요약
- 정적 콘텐츠 시딩 (Vocabulary, Grammar, Kana 등): **Prisma** (`seed.ts`)
- 레슨/스테이지 시딩 (Chapter, Lesson, StudyStage): **SQLAlchemy** (Python seeds)
- 웹 런타임 쓰기 (Quiz, Conversation, Wordbook 등): **Prisma**
- 모바일 런타임 쓰기 (Quiz, Lesson progress 등): **SQLAlchemy**
- 상세 매핑: `docs/architecture/data/table-ownership.md`
