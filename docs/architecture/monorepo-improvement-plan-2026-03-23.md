# HaruKoto 모노레포 개선 실행 계획

> **작성일**: 2026-03-23
> **기반 문서**: `docs/architecture/monorepo-analysis-2026-03-23.md`
> **검증**: Claude Code + Codex MCP 교차 검증 합의안 (4라운드)

---

## 목차

1. [개선 전략 개요](#1-개선-전략-개요)
2. [현황 진단: 데이터 흐름 + 플랫폼 차이](#2-현황-진단-데이터-흐름--플랫폼-차이)
3. [Phase 1: 지금 당장 (이번 스프린트)](#3-phase-1-지금-당장-이번-스프린트)
4. [Phase 2: 곧 해야 함 (1~2 스프린트)](#4-phase-2-곧-해야-함-12-스프린트)
5. [Phase 3: 트리거 기반 (기능 확장 시)](#5-phase-3-트리거-기반-기능-확장-시)
6. [PR 단위 체크리스트](#6-pr-단위-체크리스트)
7. [기술 레퍼런스](#7-기술-레퍼런스)

---

## 1. 개선 전략 개요

### 핵심 원칙

> **"지금은 통제와 안정화, 나중에 통합"**
>
> 전면 리라이트보다, DDL 거버넌스와 계약 자동화를 먼저 잠그는 게 리스크 대비 효과가 가장 크다.

| 원칙 | 설명 |
|------|------|
| **Single Source of Truth** | 스키마, enum, API 계약 각각에 단일 권위 소스를 지정 |
| **자동화 우선** | 수동 동기화를 자동 생성으로 대체 |
| **안정성 우선** | 현재 잘 동작하는 것을 깨지 않음. 점진적 전환 |
| **CI 게이트** | 드리프트를 코드리뷰가 아닌 CI가 잡음 |

### 권위 소스 지정 (Claude + Codex 합의)

| 영역 | 권위 소스 | 역할 |
|------|----------|------|
| DB 스키마 (DDL) | **Alembic** (`apps/api/alembic/`) | 유일한 DDL 변경 권한자 |
| 데이터 쓰기 (DML) | **Prisma + SQLAlchemy 공존** | 양쪽 모두 DML 참여자 (시딩, 런타임) |
| API 계약 | **FastAPI OpenAPI** | TS/Dart 클라이언트 생성 소스 |
| Enum 정의 | **Python enum** (`apps/api/app/enums.py`) | Prisma/TS/Dart는 자동 동기화 |
| UI 타입 | **각 플랫폼** | 플랫폼별 매핑 함수에서 관리 |

### 이전 계획에서 수정된 핵심 사항

| 이전 계획 | 수정 후 | 이유 |
|----------|--------|------|
| "Prisma = read-only mirror" | **Alembic = DDL 권한자, Prisma = DML 참여자** | Prisma가 전체 정적 콘텐츠 시딩 + 웹 런타임 쓰기를 담당 |
| "API Plane 즉시 단일화 (BFF 전환)" | **신규만 통제, 전면 전환은 Web 기능 확장 시** | Web(MVP)과 Mobile(풀버전)이 제품 구조 자체가 다름 |
| P0로 6개 작업 동시 진행 | **3개만 즉시, 나머지는 트리거 기반** | 안정적으로 동작하는 양쪽을 동시에 건드리면 리스크 증가 |

---

## 2. 현황 진단: 데이터 흐름 + 플랫폼 차이

### 2.1 데이터 삽입 구조 (Dual DML)

```
┌─────────────────────────────────────────────────────────────────┐
│                      PostgreSQL (Supabase)                      │
│                                                                 │
│  ┌──────────────────────┐    ┌───────────────────────────────┐ │
│  │  Prisma DML (쓰기)    │    │  SQLAlchemy DML (쓰기)         │ │
│  │                      │    │                               │ │
│  │  정적 콘텐츠 시딩:     │    │  레슨/스테이지 시딩:           │ │
│  │  - Vocabulary (6000+) │    │  - Chapter/Lesson (N5, 6개)   │ │
│  │  - Grammar (300+)     │    │  - StudyStage (31개)          │ │
│  │  - Kana (150+)        │    │  - SRS Backfill              │ │
│  │  - Cloze (200+)       │    │                               │ │
│  │  - SentenceArrange    │    │  런타임 (모바일):              │ │
│  │  - AI Characters      │    │  - Quiz session/answer        │ │
│  │  - Scenarios          │    │  - Lesson progress            │ │
│  │                      │    │  - Study stage progress        │ │
│  │  런타임 (웹):          │    │  - TTS audio cache            │ │
│  │  - Quiz session/answer│    │                               │ │
│  │  - Conversation       │    │                               │ │
│  │  - Wordbook            │    │                               │ │
│  │  - Daily missions     │    │                               │ │
│  │  - Notifications      │    │                               │ │
│  └──────────────────────┘    └───────────────────────────────┘ │
│                                                                 │
│  DDL Authority: Alembic ONLY                                    │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 테이블 Ownership 매핑

| 테이블 | Prisma 시딩 | Prisma 런타임 | SQLAlchemy 시딩 | SQLAlchemy 런타임 |
|--------|:-----------:|:------------:|:--------------:|:----------------:|
| Vocabulary | **seed.ts** | read | - | read |
| Grammar | **seed.ts** | read | - | read |
| KanaCharacter | **seed.ts** | read | - | read |
| KanaLearningStage | **seed.ts** | read | - | read |
| ClozeQuestion | **seed.ts** | read | - | read |
| SentenceArrangeQuestion | **seed.ts** | read | - | read |
| AiCharacter | **seed.ts** | read | - | read |
| ConversationScenario | **seed.ts** | read | - | read |
| Chapter | - | - | **lessons.py** | read |
| Lesson | - | - | **lessons.py** | read |
| LessonItemLink | - | - | **lessons.py** | read |
| StudyStage | - | - | **study_stages.py** | read |
| User | - | **write** | - | **write** |
| QuizSession | - | **write** | - | **write** |
| QuizAnswer | - | **write** | - | **write** |
| Conversation | - | **write** | - | write |
| WordbookEntry | - | **write** | - | write |
| DailyMission | - | **write** | - | write |
| DailyProgress | - | **write** | - | write |
| UserVocabProgress | - | **write** | - | **write** |
| UserGrammarProgress | - | read | - | **write** |
| UserKanaProgress | - | **write** | - | read |
| UserLessonProgress | - | - | - | **write** |
| UserStudyStageProgress | - | - | - | **write** |
| TtsAudio | - | - | - | **write** |
| Notification | - | **write** | - | write |

### 2.3 Web MVP vs Mobile 풀버전

| 영역 | Web (MVP) | Mobile (풀버전) |
|------|-----------|----------------|
| **네비게이션** | 홈/통계/학습/회화/MY | 홈/학습/퀴즈/실전회화/MY |
| **학습 방식** | 퀴즈 중심 (직접 퀴즈 시작) | 레슨 기반 순차 학습 + 퀴즈 |
| **레슨 기능** | 없음 | Chapter → Lesson 순차 진행 |
| **퀴즈 탭** | 학습 탭에 통합 | 전용 Practice 탭 (Smart Quiz 포함) |
| **통계** | 메인 탭 | 별도 풀스크린 |
| **음성 통화** | 제한적 | 전용 기능 |
| **API 소비** | Next.js API Route (Prisma 직접) | FastAPI (Dio HTTP) |
| **Prisma 누락 7개 모델** | 접근 안 함 (영향 없음) | FastAPI를 통해 접근 |

**핵심 판단**: Web MVP에서 Prisma에 누락된 7개 모델(Chapter, Lesson 등)은 모바일 전용 기능이므로 **현재 웹 런타임 장애는 없다**. Web이 레슨 기능을 추가할 때 비로소 영향을 받음.

---

## 3. Phase 1: 지금 당장 (이번 스프린트)

> 안정적으로 동작하는 기존 기능을 건드리지 않고, **거버넌스와 CI 게이트만 추가**.

### 3.1 Alembic DDL Authority 확정

**목표**: DB 스키마(DDL) 변경은 Alembic에서만 수행. Prisma는 DML(시딩+런타임 쓰기)은 그대로 유지.

#### Step 1: DDL 차단 스크립트 추가

`packages/database/scripts/block-prisma-ddl.mjs` (신규):

```js
#!/usr/bin/env node
const blocked = process.argv[2] ?? "unknown";

console.error(`[BLOCKED] "${blocked}" is disabled.`);
console.error("");
console.error("Schema authority: Alembic (apps/api/alembic).");
console.error("DDL 변경 방법:");
console.error("  cd apps/api");
console.error('  uv run alembic revision --autogenerate -m "your migration"');
console.error("  uv run alembic upgrade head");
console.error("");
console.error("Prisma 동기화:");
console.error("  cd packages/database");
console.error("  pnpm db:sync");
process.exit(1);
```

#### Step 2: package.json 스크립트 변경

`packages/database/package.json` 변경:

```jsonc
{
  "scripts": {
    // 허용: 클라이언트 생성, 동기화, 시딩, 스튜디오
    "db:generate": "prisma generate",
    "db:sync": "prisma db pull --schema=prisma/schema.prisma && prisma format --schema=prisma/schema.prisma && prisma generate",
    "db:seed": "tsx prisma/seed.ts",
    "db:studio": "prisma studio",

    // 차단: DDL 변경 명령어
    "db:push": "node ./scripts/block-prisma-ddl.mjs db:push",
    "db:migrate": "node ./scripts/block-prisma-ddl.mjs db:migrate",

    // 기존 유지
    "build": "prisma generate",
    "lint": "tsc --noEmit"
  }
}
```

**유지되는 것**: `db:seed` (Prisma 시딩), `db:generate` (클라이언트 생성), `db:studio` (데이터 탐색)
**차단되는 것**: `db:push` (스키마 강제 적용), `db:migrate` (마이그레이션 생성)

#### Step 3: Prisma 스키마 재동기화

```bash
cd packages/database
pnpm db:sync  # db pull → format → generate
cd ../../apps/web
pnpm tsc --noEmit  # 타입 체크 확인
```

**주의사항** (`prisma db pull` 시):
- `--force` 사용 금지 — 기존 `@map`, `@@map` 네이밍 매핑이 덮어씌워짐
- diff에서 확인: snake_case 변환 여부, relation name 변경, enum 값 누락/추가
- pull 직후 반드시 `prisma generate` + web 타입 체크를 묶어서 실행

#### Step 4: 문서 업데이트

CLAUDE.md, README.md에 반영:
- "Schema Authority: Alembic (DDL only)"
- "Prisma: DML 참여자 (시딩 + 웹 런타임 쓰기)"
- DDL 변경 절차 안내

---

### 3.2 CI Schema Drift Check 추가

**목표**: Alembic 마이그레이션과 Prisma 스키마 간 드리프트를 CI에서 자동 감지.

`.github/workflows/ci.yml`에 추가할 job:

```yaml
  schema-drift:
    needs: changes
    if: >
      needs.changes.outputs.backend == 'true' ||
      needs.changes.outputs.frontend == 'true'
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: harukoto_ci
        ports:
          - 5432:5432
        options: >-
          --health-cmd="pg_isready -U postgres"
          --health-interval=5s
          --health-timeout=5s
          --health-retries=20

    steps:
      - uses: actions/checkout@v5

      # Alembic으로 DB 스키마 적용
      - uses: astral-sh/setup-uv@v4
      - run: uv python install 3.12
      - run: uv sync --frozen --extra dev
        working-directory: apps/api
      - name: Apply Alembic migrations
        working-directory: apps/api
        env:
          DATABASE_URL: postgresql+asyncpg://postgres:postgres@localhost:5432/harukoto_ci
        run: uv run alembic upgrade head

      # Prisma로 drift 비교
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v5
        with:
          node-version: 22
          cache: pnpm
      - run: pnpm install --frozen-lockfile

      - name: Check Prisma schema drift
        working-directory: packages/database
        env:
          PRISMA_DATABASE_URL: postgresql://postgres:postgres@localhost:5432/harukoto_ci
        run: |
          pnpm exec prisma migrate diff \
            --exit-code \
            --from-url "$PRISMA_DATABASE_URL" \
            --to-schema-datamodel prisma/schema.prisma
```

---

### 3.3 CI Path Filter 보강

**목표**: `packages/**` 변경 시 backend job도 트리거.

`.github/workflows/ci.yml` 변경:

```yaml
# 변경 전
backend:
  - 'apps/api/**'

# 변경 후
backend:
  - 'apps/api/**'
  - 'packages/database/**'
```

---

## 4. Phase 2: 곧 해야 함 (1~2 스프린트)

> 기존 기능을 유지하면서 **문서화, 계약 테스트, 보안 수정** 진행.

### 4.1 테이블/쓰기 경로 Ownership 문서화

**목표**: 어떤 ORM이 어떤 테이블에 쓰기 권한을 가지는지 명시적으로 문서화.

위 [2.2 테이블 Ownership 매핑](#22-테이블-ownership-매핑)을 `docs/architecture/` 또는 CLAUDE.md에 포함.

**규칙 추가**:
- 동일 테이블에 양쪽 ORM이 런타임 쓰기를 하는 경우 → conflict 방지 로직 필요
- 현재 User, QuizSession, QuizAnswer, DailyProgress 등은 Web(Prisma)과 Mobile(SQLAlchemy) 양쪽에서 쓰기 → **동일 유저가 양쪽에서 동시에 쓸 수 없으므로 현재는 안전** (Web은 웹 유저, Mobile은 앱 유저)
- 향후 Web/Mobile 동시 사용 시나리오가 생기면 API 단일화 필요

---

### 4.2 OpenAPI 계약 자동화 착수 (최소 범위)

**목표**: FastAPI OpenAPI spec 추출 + TS 타입 생성 파이프라인만 먼저 구축. 전면 적용은 Phase 3.

#### Step 1: OpenAPI Spec 추출 스크립트

`apps/api/scripts/export_openapi.py` (신규):

```python
import json
from pathlib import Path

from app.main import app

spec = app.openapi()
out = Path("openapi/openapi.json")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(spec, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"Wrote {out}")
```

#### Step 2: TS 타입 생성 (선택적 도입)

```bash
pnpm dlx openapi-typescript apps/api/openapi/openapi.json \
  -o packages/api-contract/src/generated.ts
```

#### Step 3: CI Breaking Change 검사

```yaml
  api-contract:
    runs-on: ubuntu-latest
    if: needs.changes.outputs.backend == 'true'
    steps:
      - uses: actions/checkout@v5
        with:
          fetch-depth: 0
      - uses: astral-sh/setup-uv@v4
      - run: uv python install 3.12
      - run: uv sync --frozen
        working-directory: apps/api
      - name: Export current OpenAPI
        working-directory: apps/api
        run: uv run python scripts/export_openapi.py
      - name: Load base OpenAPI from main
        run: |
          git show origin/main:apps/api/openapi/openapi.json > base-openapi.json || echo '{}' > base-openapi.json
      - name: Breaking change check
        run: |
          docker run --rm -v "$PWD:/work" tufin/oasdiff:latest \
            breaking /work/base-openapi.json /work/apps/api/openapi/openapi.json
```

---

### 4.3 모바일/웹 공통 API Contract Test

**목표**: Web과 Mobile이 공유하는 API 엔드포인트에 대해 계약 테스트 추가.

공통 엔드포인트 (양쪽 모두 사용):
- `POST /api/v1/quiz/start`
- `POST /api/v1/quiz/answer`
- `POST /api/v1/quiz/complete`
- `GET /api/v1/stats/dashboard`
- `GET /api/v1/chat/scenarios`

**방법**: FastAPI pytest에서 response schema 검증 테스트 추가.

---

### 4.4 Android Cleartext Traffic 수정

**목표**: 릴리스 빌드에서 cleartext HTTP 차단.

`apps/mobile/android/app/src/main/res/xml/network_security_config.xml` (신규):

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">10.0.2.2</domain>
        <domain includeSubdomains="true">localhost</domain>
    </domain-config>
</network-security-config>
```

`AndroidManifest.xml` 변경:

```xml
<!-- 변경 전 -->
<application android:usesCleartextTraffic="true" ...>

<!-- 변경 후 -->
<application android:networkSecurityConfig="@xml/network_security_config" ...>
```

---

### 4.5 iOS OAuth 스킴 환경 분리

`xcconfig` 파일로 dev/staging/prod별 URL 스킴 분리:

```
// ios/Flutter/Development.xcconfig
GOOGLE_REVERSED_CLIENT_ID=com.googleusercontent.apps.DEV_ID
KAKAO_NATIVE_KEY=kakao_dev_key
```

`Info.plist`에서 변수 참조: `$(GOOGLE_REVERSED_CLIENT_ID)`

---

## 5. Phase 3: 트리거 기반 (기능 확장 시)

> 특정 조건이 충족될 때 실행. 지금 진행하면 안정적인 시스템을 불필요하게 건드림.

### 5.1 API Plane 단일화 (BFF 전환)

**트리거**: Web이 레슨/스테이지/Smart Quiz 등 모바일 수준 기능을 추가할 때

**지금 해야 할 것 (경계 규칙만 설정)**:
- Next API Route 신규 개발 시: BFF 성격(세션/쿠키/뷰 조합)만 허용
- 도메인 로직 신규 개발: FastAPI 우선
- 중복 엔드포인트 신규 추가: 금지 (기존은 유지, 신규만 통제)

**나중에 할 것**:
- `apps/web/src/lib/backend-fetch.ts` 프록시 유틸 구현
- Read-only endpoints부터 점진 전환
- 최종적으로 Web API Route에서 도메인 로직 제거

#### BFF로 남길 라우트 기준

| 조건 | 예시 | 판단 |
|------|------|------|
| 브라우저 쿠키/세션 브릿지 | `/api/auth/ensure-user` | BFF 유지 |
| Web 전용 플랫폼 기능 | `/api/cron/*`, `/api/v1/push/*` | BFF 유지 |
| Vercel 환경 특화 | 서버측 비밀값 처리 | BFF 유지 |
| 도메인 로직 | `/api/v1/quiz/*`, `/api/v1/chat/*` | → FastAPI 수렴 대상 |

#### 프록시 유틸 (Web 기능 확장 시 구현)

```ts
// apps/web/src/lib/backend-fetch.ts
import { createClient } from "@/lib/supabase/server";

const API_BASE = process.env.API_INTERNAL_BASE_URL!;

export async function backendFetch(
  path: string,
  init: RequestInit = {}
): Promise<Response> {
  const supabase = await createClient();
  const { data: { session } } = await supabase.auth.getSession();

  const headers = new Headers(init.headers);
  headers.set("Content-Type", "application/json");
  if (session?.access_token) {
    headers.set("Authorization", `Bearer ${session.access_token}`);
  }

  return fetch(`${API_BASE}${path}`, { ...init, headers, cache: "no-store" });
}
```

---

### 5.2 시딩 파이프라인 통합

**트리거**: 시딩 데이터가 복잡해지거나, 콘텐츠 관리 도구 도입 시

**현재 상태** (안정적):
- `pnpm db:seed` (Prisma) → 정적 콘텐츠 (어휘, 문법, 가나 등)
- `python -m app.seeds.lessons` (SQLAlchemy) → 레슨/챕터
- `python -m app.seeds.study_stages` (SQLAlchemy) → 학습 스테이지

**결정 필요 시점의 옵션**:

| 옵션 | 설명 | 적합한 경우 |
|------|------|-----------|
| A: 현상 유지 | Prisma seed + Python seed 공존 | 시딩 빈도가 낮고 안정적 |
| B: Python으로 통합 | 모든 시딩을 SQLAlchemy로 이관 | Alembic authority에 맞춤 정렬 |
| C: 관리 도구 도입 | Admin UI에서 콘텐츠 관리 | 비개발자가 콘텐츠 편집 필요 시 |

**현재 권장**: 옵션 A (현상 유지). 시딩은 안정적으로 동작 중이며, 깨뜨릴 이유 없음.

---

### 5.3 Enum 단일 소스 수렴

**트리거**: OpenAPI 계약 자동화가 안정화된 후

#### 수렴 흐름 (목표 상태)

```
Python enum (apps/api/app/enums.py)  ← 단일 소스
    ↓ Alembic migration
PostgreSQL enum                       ← DB 반영
    ↓ prisma db pull
Prisma enum (schema.prisma)           ← 자동 mirror
    ↓ OpenAPI spec export
TS enum (generated.ts)                ← 자동 생성
Dart enum (api_client/)               ← 자동 생성
```

#### `@harukoto/types` 처리 방안

| 현재 파일 | 조치 | 시점 |
|----------|------|------|
| `content.ts` (JlptLevel, PartOfSpeech) | OpenAPI generated로 대체 | Phase 3 |
| `quiz.ts` (QuizType, QuizMode) | OpenAPI generated로 대체 | Phase 3 |
| `user.ts`, `conversation.ts`, `subscription.ts`, `gamification.ts` | OpenAPI generated로 대체 | Phase 3 |
| `api.ts` (ApiError, Pagination) | UI 전용 유틸 타입만 남김 | Phase 3 |

---

### 5.4 중복 Web API Route 제거

**트리거**: BFF 전환이 완료된 후

전환 순서 (리스크 낮은 순):

| 순서 | 대상 | 이유 |
|------|------|------|
| 1 | Read-only endpoints | `stats`, `chat/scenarios`, `missions/today` — 사이드이펙트 없음 |
| 2 | 단순 write endpoints | `wordbook`, `favorites`, `notifications` — 상태 변경 단순 |
| 3 | 고상태 endpoints | `quiz/*`, `subscription/*`, `chat/*` — 트랜잭션/상태 복잡 |
| 4 | 정리 | Prisma 비즈니스 로직 제거, 미사용 route 삭제 |

---

### 5.5 패키지 테스트 추가

| 패키지 | 테스트 대상 | 도구 |
|--------|-----------|------|
| `@harukoto/ai` | provider fallback, TTS/STT 에러 처리, prompt 구조 | Vitest |
| `@harukoto/types` | enum 계약 스냅샷 (OpenAPI 전환 후 불필요) | Vitest |
| `@harukoto/database` | Prisma client 초기화, singleton 동작 | Vitest |

---

### 5.6 문서 현행화

| 문서 | 변경 내용 | 시점 |
|------|----------|------|
| `CLAUDE.md` | `packages/ui` 제거, DDL authority 반영 | Phase 1에서 부분 진행 |
| `README.md` | 프로젝트 구조도에 API 앱 추가, `packages/ui` 제거 | Phase 2 |
| `docs/product/prd.md` | Next.js API 단독 → FastAPI + BFF 구조 반영 | Phase 3 |

---

## 6. PR 단위 체크리스트

### PR-1: Alembic DDL Authority 확정 (Phase 1)

- [ ] `packages/database/scripts/block-prisma-ddl.mjs` 생성
- [ ] `packages/database/package.json` 스크립트 변경 (DDL 차단, `db:seed`/`db:sync` 유지)
- [ ] `pnpm db:sync` 실행 → Prisma 스키마 재동기화 (누락 7개 모델 반영)
- [ ] `pnpm db:seed` 정상 동작 확인 (시딩 파이프라인 무결성)
- [ ] `apps/web`에서 `pnpm tsc --noEmit` 통과 확인
- [ ] CLAUDE.md 업데이트 (DDL authority + DML 참여자 설명)
- **검증**: `pnpm --filter @harukoto/database db:push` → 에러 메시지 출력 확인

### PR-2: CI 보강 (Phase 1)

- [ ] `ci.yml`에 `schema-drift` job 추가
- [ ] backend path filter에 `packages/database/**` 추가
- **검증**: PR에서 CI 통과 확인

### PR-3: Ownership 문서화 + 경계 규칙 (Phase 2)

- [ ] 테이블 Ownership 매핑 문서 작성
- [ ] Web API Route 신규 개발 규칙 추가 (BFF만, 도메인 로직 금지)
- [ ] 중복 엔드포인트 신규 추가 금지 규칙 추가
- **검증**: 팀 리뷰

### PR-4: OpenAPI Spec 추출 파이프라인 (Phase 2)

- [ ] `apps/api/scripts/export_openapi.py` 생성
- [ ] `apps/api/openapi/openapi.json` 생성 및 Git 커밋
- [ ] CI에 breaking change 검사 추가
- **검증**: `uv run python scripts/export_openapi.py` 성공

### PR-5: Android Cleartext 수정 (Phase 2)

- [ ] `network_security_config.xml` 생성
- [ ] `AndroidManifest.xml` 변경
- [ ] `flutter build apk --debug` 성공 확인
- **검증**: 릴리스 빌드에서 HTTP 차단 확인

---

## 7. 기술 레퍼런스

### 도구 선택 근거 (Claude + Codex 합의)

| 용도 | 도구 | 선택 이유 |
|------|------|----------|
| Schema drift check | `prisma migrate diff` | Prisma 내장, 추가 설치 불필요 |
| TS 타입 생성 | `openapi-typescript` | 타입만 생성, 기존 fetch 구조 유지 |
| Dart client 생성 | OpenAPI Generator (`dart-dio`) | Flutter/Dio 호환 |
| API breaking check | `oasdiff` | OpenAPI 전용, Docker로 실행 간편 |
| TS hook 생성 (Phase 3) | `orval` | React Query hook 자동 생성 |

### 환경변수 추가 필요

| 변수 | 용도 | 적용 위치 | 시점 |
|------|------|----------|------|
| `PRISMA_DATABASE_URL` | CI drift check (sync driver) | CI secrets | Phase 1 |
| `API_INTERNAL_BASE_URL` | BFF → FastAPI 내부 통신 | `apps/web/.env.local` | Phase 3 |

---

## Codex 토론 요약 (4라운드)

### 라운드 1: 이슈 평가 및 우선순위 재조정
- `.env` 커밋 이슈: P0→P2 (실제 tracked는 landing의 공개 URL뿐)
- Dual ORM: P2→P0으로 승격
- Enum 불일치: P1→P0으로 승격

### 라운드 2: 수정 방안 합의
- Schema authority: Alembic 확정
- `@harukoto/types`: 분리 전략 (DB types vs API contract types)

### 라운드 3: 아키텍처 종합 평가
- 종합 점수: 5.3/10
- Web API vs FastAPI: 56/60 ops 중복 구현

### 라운드 4: 현실 반영 재평가 (사용자 피드백)
- **Prisma 전략 수정**: "read-only mirror" → "DDL 차단, DML 유지" (시딩 + 웹 런타임)
- **BFF 전환 시점 조정**: 즉시 전환 → Web 기능 확장 시 (트리거 기반)
- **우선순위 축소**: Phase 1은 3개 작업만 (DDL 차단, CI drift check, CI path filter)
