# AI Coding Harness

> 하루코토(HaruKoto)에서 Claude Code와 Codex를 동시에 운영하기 위한 하네스 설계와 사용법.
> **Audience**: 이 레포에서 AI 에이전트를 돌리는 사람 (나 + 미래의 팀원).

## 왜 하네스인가

솔로/AI-자동화 중심 개발에서 실제로 마주친 4개 문제:

1. **컨텍스트 오염** — 하나의 긴 세션이 모든 것을 기억할 수 없음
2. **경계 침범** — 에이전트가 자기 도메인 밖 코드를 자유롭게 수정 → 리뷰 복잡도 폭증
3. **계약 드리프트** — 백엔드가 스키마 바꾸면 모바일/웹이 조용히 깨짐
4. **자동화 연속성 단절** — 결정 필요한 상황을 만나면 세션 끝나면서 증발

각 문제에 하나씩 대응하는 컴포넌트를 쌓아 만든 것이 이 하네스입니다.

---

## 4개 기둥

### 1. Orchestrator — GSD 워크플로우

`.planning/` 디렉토리 기반. Phase → Plan → Wave → Task 구조로 작업을 쪼갬.

- `/gsd:plan-phase <N>` — Phase 계획 생성 (RESEARCH → PLAN → VERIFY 루프)
- `/gsd:execute-phase <N>` — Wave 단위 병렬 실행. 도메인별 서브에이전트에게 위임
- `/gsd:verify-work` — 완성도 UAT

### 2. Domain-Isolated Sub-agents — `.claude/agents/`

4개 에이전트가 각자 쓰기 경계를 선언. 각자 고유 worktree에서 실행 (`isolation: worktree`).

| 에이전트 | 쓰기 가능 | 금지 | 자동 로드 skill |
|----------|----------|------|---------------|
| `web-agent` (🔵) | `apps/{web,admin,landing}` | API, mobile, packages | `web-next16`, `api-plane-governance` |
| `backend-agent` (🟢) | `apps/api` (Alembic 단독 권한) | frontend, mobile, packages | `fastapi-patterns`, `api-plane-governance` |
| `mobile-agent` (🟠) | `apps/mobile` | 그 외 전부 | `flutter-riverpod` |
| `shared-packages-agent` (🟣) | `packages/*` | `apps/*`, `apps/api/alembic` | `api-plane-governance` |

**에스컬레이션 룰:**
- API 계약 변경: `backend-agent`가 발행 → `web-agent` / `mobile-agent`가 소비
- DDL 변경: `backend-agent`가 Alembic 작성 → `shared-packages-agent`가 `pnpm db:sync` 미러링
- Breaking type 변경: `shared-packages-agent`가 발견 → 오케스트레이터가 같은 wave에서 컨슈머 dispatch

### 3. Skills — `.claude/skills/`

Progressive disclosure 방식으로 관련 에이전트가 spawn될 때만 로드되는 도메인 지식.

| Skill | 내용 | 로드 주체 |
|-------|------|----------|
| `web-next16` | Next.js 16 App Router, Server Components, admin UX 차이 | web-agent |
| `fastapi-patterns` | FastAPI/SQLAlchemy/Alembic/Pydantic 관례 | backend-agent |
| `flutter-riverpod` | Riverpod 3.x, 시트 안정화, iOS device IDs | mobile-agent |
| `api-plane-governance` | DDL 권한, BFF 라우팅, 테이블 ownership | 3개 에이전트 공유 |

cross-cutting 규칙 3개는 여전히 `.claude/rules/`에 있고 `CLAUDE.md`가 `@import`로 항상 로드:
- `workflow.md` — Claude+Codex 협업 절차
- `quality.md` — 테스트/린트 규약
- `security.md` — 시크릿 관리

### 4. Hooks — `.claude/hooks/`

결정론적 가드. LLM 판단 없이 수 ms에 차단/허용.

| 훅 | 이벤트 | 역할 |
|-----|-------|------|
| `security-guard.sh` | PreToolUse (Write/Edit/MultiEdit) | `.env`, `credentials/`, `*.pem`, SSH 키 등 쓰기 차단 |
| `pre-commit-lint.sh` | PreToolUse (Bash) | `git commit` 감지 시 변경 도메인에 맞는 lint 자동 실행 |
| `session-start.sh` | SessionStart | 브랜치/변경 영역/**열린 에스컬레이션** 자동 surfacing |

---

## 계약 관리 (Contract Management)

계약 드리프트는 별도 레이어로 처리.

### OpenAPI가 SSOT

- `apps/api/openapi/openapi.json` — FastAPI에서 자동 추출된 스냅샷 (git 체크인)
- 재생성: `cd apps/api && uv run python scripts/export_openapi.py`
- CI가 freshness 강제 (`api-contract` 잡 — 커밋된 스냅샷과 현재 코드 diff)

### TypeScript 자동 생성

- `packages/types/src/generated/api.ts` — `openapi-typescript`가 OpenAPI에서 생성
- 재생성: `pnpm --filter @harukoto/types gen:api`
- CI freshness 강제
- 사용:
  ```typescript
  import type { components, paths } from '@harukoto/types';
  type Quiz = components['schemas']['QuizResponse'];
  type GetQuizOp = paths['/api/v1/quiz/{id}']['get'];
  ```

### 모바일 드리프트 감지 (코드젠 없이)

Flutter codegen은 기존 Riverpod/Dio 패턴과 충돌 위험이 커서 **감지 전략**만 채택:

- `apps/api/scripts/validate_mobile_contracts.py`
  - **체크 1 (자동)**: Dart `_dio.<method>('/path')` 호출 전체 스캔 → OpenAPI 경로 존재 여부 확인. 없으면 orphaned로 보고
  - **체크 2 (opt-in)**: Dart 클래스에 `// OPENAPI_SCHEMA: <SchemaName>` 주석이 있으면 `fromJson`의 `json['field']` 접근을 OpenAPI properties와 비교
  - `--json` 플래그: 기계 판독 가능 리포트 → 에이전트가 에스컬레이션 파일 생성 가능
- CI의 `api-contract` 잡에서 하드 fail (backend 변경 시)

### Backend 변경 시 Contract Sync 체크리스트

`backend-agent` 프롬프트에 강제되어 있음. 수동 실행 시에도 반드시:

```bash
# 1. OpenAPI snapshot 재생성
cd apps/api && uv run python scripts/export_openapi.py

# 2. TypeScript 타입 재생성 (web/admin 자동 반영)
pnpm --filter @harukoto/types gen:api

# 3. 모바일 드리프트 검증
cd apps/api && uv run python scripts/validate_mobile_contracts.py
```

드리프트 발견 시:
- Orphaned endpoint → **직접 모바일 수정 금지**. `.planning/escalations/` 에 기록하고 mobile-agent 위임
- Field drift → 동일 에스컬레이션 플로우
- 통과 → SUMMARY에 "mobile: verified clean" 명시

---

## 에스컬레이션 인박스 — `.planning/escalations/`

AI가 자체 판단을 벗어난 결정을 만났을 때 **세션을 끝내지 않고** 기록하는 곳.

### 언제 쓰는가
- 도메인 경계 위반이 필요한 작업
- Breaking change 정당성 판단
- 보안 모델 변경
- PRD에 없는 요구사항 발견
- 드리프트 감지기 리포트

### 파일 포맷

```markdown
---
raised_by: <agent-name>
raised_at: 2026-04-22T15:30:00+09:00
phase: <phase or slug>
severity: blocker | warn | info
status: open
---

## What happened
<1-2 문장>

## Decision required
<구체적 결정>

## Options considered
1. ...
2. ...

## Recommended direction
<에이전트 우선안 + 근거>

## Side effects
<결정 파급 효과>
```

### 라이프사이클

1. 에이전트가 파일 생성 (`status: open`)
2. **다음 세션 SessionStart 훅이 자동 노출** → 사용자가 즉시 인지
3. 사용자 결정 후 `## Resolution` 섹션 추가, `status: resolved`
4. 3~5건 쌓이면 `resolved/YYYY-MM/`으로 아카이브

### 자동 공급 소스

다음이 드리프트를 감지하면 에이전트가 에스컬레이션을 자동 생성:
- `validate_mobile_contracts.py`
- CI `api-contract` 잡 (OpenAPI freshness, oasdiff, TS freshness)

---

## 실전 플로우 (새 기능 추가 시)

### 예: "admin에 콘텐츠 일괄 승인 기능"

```
1. /gsd:discuss-phase <N>      → 요구사항 수집 (Plan Mode)
2. /gsd:plan-phase <N>         → PLAN.md 생성, 체커가 3회 리비전 루프로 검증
3. /gsd:execute-phase <N>
   Wave 1:
     - backend-agent: POST /api/v1/admin/bulk-approve 엔드포인트 추가
       → Contract Sync 체크리스트 실행 (export_openapi.py, gen:api, validate_mobile)
       → SUMMARY에 "Downstream: web-agent needs admin UI; mobile: no impact"
   Wave 2:
     - web-agent: 관리자 UI 추가 (자동 생성된 @harukoto/types 사용)
4. /gsd:verify-work <N>        → UAT 체크
```

병렬성: Wave 내부는 worktree 격리 덕에 충돌 없이 동시 실행 가능.

### 예: "모바일 홈 화면 리팩터링"

```
1. /gsd:quick "..." 또는 /gsd:plan-phase (규모 따라)
2. 실행 중 mobile-agent가 API 변경이 필요함을 발견 → 에스컬레이션 생성 →
   다음 세션 시작 시 사용자가 결정 → backend-agent 먼저 돌린 후 재시도
```

### 예: "버그 수정"

```
/gsd:debug → 체계적 재현 + 가설 + 수정
해당 도메인 에이전트가 직접 수정
(이 레포에서는 실제로 f9c5aab 커밋에 예시 있음 — 드리프트 감지기가 잡아낸 dead code)
```

---

## CI 가드 전체 지도

| 잡 | 트리거 | 검증 |
|-----|-------|------|
| `frontend` | web/admin/landing/packages 변경 | pnpm lint + typecheck + build |
| `backend` | api 변경 | ruff check/format + pytest |
| `api-contract` | api 변경 | OpenAPI freshness / TS types freshness / oasdiff (warn) / mobile drift validator |
| `schema-drift` | api 또는 frontend 변경 | Alembic migrations apply → Prisma schema diff (Alembic 단독 DDL 확인) |
| `mobile` | mobile 변경 | dart format + flutter analyze + flutter test + Android debug build |

---

## 알려진 한계

- `.claude/hooks/*` 는 **Claude Code 내부에서만** 발화. Codex를 별도 터미널에서 돌리면 hooks는 작동 안 함. 크로스 툴 방어가 필요하면 `gitleaks` 같은 pre-commit 훅을 git 레이어에 설치할 것.
- 모바일 field drift 감지는 **opt-in 주석 기반**. 전수 감지를 원하면 `openapi_generator` 같은 Dart codegen 도입 필요 (기존 코드와 충돌 가능성 큼).
- oasdiff breaking change 체크는 현재 `continue-on-error: true` (warn 모드). 실제 breaking 패턴 데이터 쌓이면 hard-fail 전환 + override 메커니즘(PR label 또는 `[breaking-ok]` commit marker) 설계.

---

## 참고

- 도메인 에이전트 정의: `.claude/agents/*.md`
- Skill 정의: `.claude/skills/*/SKILL.md`
- 훅 스크립트: `.claude/hooks/*.sh`
- 에스컬레이션 가이드: `.planning/escalations/README.md`
- Contract 스크립트: `apps/api/scripts/{export_openapi,validate_mobile_contracts}.py`
- 코드젠 스크립트: `packages/types/package.json` → `gen:api`
