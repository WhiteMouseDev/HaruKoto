---
title: "AI 하네스 엔지니어링 — 솔로 프로젝트에서 실전 구축한 이야기"
date: 2026-04-23
tags: [ai, claude-code, codex, harness, engineering, agentic-coding]
summary: "Claude Code와 Codex 두 에이전트를 혼자 운영하면서 겪은 4가지 문제, 그리고 그걸 해결하려고 만든 하네스의 실제 구조와 작동 증거."
---

# AI 하네스 엔지니어링 — 솔로 프로젝트에서 실전 구축한 이야기

## 런타임 404가 될 뻔한 버그 한 줄

어제 아침, 내가 만든 드리프트 감지기가 `validate_mobile_contracts.py`라는 파이썬 스크립트를 처음으로 CI에서 돌렸습니다. 결과는 한 줄:

```
❌ 1 orphaned call(s):
   POST /api/v1/subscription/subscribe
   (apps/mobile/lib/features/subscription/data/subscription_repository.dart:16)
```

Flutter 앱이 백엔드에 `POST /subscription/subscribe`를 호출하는데, 백엔드엔 그 엔드포인트가 **없습니다**. `/subscription/checkout`, `/subscription/activate`, `/subscription/store/verify`는 있지만 `/subscribe`는 그 어디에도. 유저가 결제 화면까지 가서 구독 버튼을 누르면 404. 다행히 코드를 추적해보니 그 화면은 아직 "결제 기능은 준비 중입니다. 곧 만나요!"라는 placeholder였고, `subscribe()` 메서드는 어디서도 호출되지 않는 dead code였습니다. **실 유저가 만나기 전에 잡힌 버그.**

이 글은 그 감지기를 포함한, 제가 지난 며칠 동안 구축한 **AI 코딩 하네스(harness)** 이야기입니다. 개인 사이드 프로젝트(한국어권 일본어 학습 앱 "하루코토")에 Claude Code와 Codex를 동시에 운영하면서 마주친 실제 문제들과, 그걸 뚫기 위해 만든 4개 기둥 시스템의 구조를 기록합니다.

---

## 왜 "하네스"가 필요한가

2024년까지 AI는 **자동완성 강화판**이었습니다. 한 줄씩 제안받고, 한 줄씩 승인하면 됐어요.

2026년은 다릅니다. Claude Code, Codex, Cursor Composer는 **한 번의 요청으로 수십 개 파일을 수정**합니다. 백그라운드 에이전트가 사람 개입 없이 PR을 만듭니다. 여러 에이전트가 서로 작업을 위임합니다.

> **사람의 검토 대역폭 < AI의 생산 대역폭**

이 불균형이 모든 문제의 근원입니다. 그리고 솔로 개발자(저 같은)에게는 이 격차가 더 치명적입니다. 팀원이 하나도 없으니까요.

제가 실제로 부딪힌 네 가지 pain point입니다.

### 1. 컨텍스트 오염
하나의 긴 세션이 프로젝트의 모든 규칙, 이전 결정, 도메인 패턴을 기억할 수 없습니다. 컨텍스트 창이 커져도 **토큰 대비 정확도는 떨어집니다**. 중요한 규칙이 중간 대화 밑으로 밀려나면서 AI가 잊어버려요.

### 2. 도메인 경계 침범
"mobile 버그 고쳐줘" 했더니 API 서비스 로직까지 손대버립니다. 루트 원인까지 접근한 건 좋지만, 한 PR이 백엔드 + 모바일 + 공유 패키지를 걸치면 **리뷰 복잡도가 기하급수적**으로 커집니다. 팀이었으면 두 개 팀 관할을 동시에 건드리는 것과 같습니다.

### 3. 계약 드리프트
백엔드가 응답 스키마를 조용히 바꿨는데 모바일이 모른 채 몇 주를 갑니다. 위의 `subscription/subscribe`가 그 예. 타입 시스템이 따로 돌면 언어 경계(Python ↔ TypeScript ↔ Dart)를 넘어서 드리프트가 누적됩니다.

### 4. 자동화 연속성 단절
AI가 "사람 결정 필요"한 상황을 만나면 그냥 멈춥니다. 세션이 끝나면 그 맥락은 증발합니다. 다음 세션 시작하면 사람이 "어디서 막혔지?"를 다시 찾아야 합니다. **자동화 투자의 복리 효과가 0**이 됩니다.

---

## 4-pillar 하네스

해결책은 4개 기둥을 쌓는 것입니다. 각각 다른 추상 레이어에서 작동합니다.

### 기둥 1: Orchestrator — GSD 워크플로우

"뭘 만들지"와 "어떻게 만들지"를 분리합니다. 저는 [GSD(Get Shit Done)](https://github.com/peterkim-ai/gsd)이라는 오픈소스 워크플로우를 채택했습니다. 구조:

```
Milestone (v1.1, v1.2 ...)
 └─ Phase (Phase 1, Phase 2 ...)
     └─ Plan (Wave 단위 병렬 실행)
         └─ Task (atomic 커밋)
```

`/gsd:plan-phase 8`을 치면 오케스트레이터가:
1. RESEARCH 서브에이전트를 spawn → 해당 도메인 조사
2. PLANNER가 PLAN.md 생성
3. CHECKER가 goal-backward 검증 (최대 3회 리비전)
4. 최종 승인 받으면 `/gsd:execute-phase 8`로 Wave별 실행

**핵심은 컨텍스트 분리**. 조사하는 에이전트와 구현하는 에이전트의 컨텍스트가 완전히 다릅니다. 메인 세션은 오케스트레이션만 담당해서 가볍게 유지됩니다.

### 기둥 2: Domain-isolated Sub-agents

네 명의 "전문가"를 정의했습니다. `.claude/agents/*.md`에 각자의 **쓰기 경계**가 명시되어 있습니다.

| 에이전트 | 쓸 수 있는 경로 | 절대 못 건드리는 경로 |
|----------|---------------|--------------------|
| `web-agent` (🔵) | `apps/web`, `apps/admin`, `apps/landing` | API, mobile, packages |
| `backend-agent` (🟢) | `apps/api` (Alembic 단독 권한) | frontend, mobile, packages |
| `mobile-agent` (🟠) | `apps/mobile` | 그 외 전부 |
| `shared-packages-agent` (🟣) | `packages/*` | `apps/*`, Alembic |

각 에이전트는 `isolation: worktree` 설정으로 **자기만의 git worktree에서 격리 실행**합니다. 병렬로 돌아도 파일 충돌이 불가능합니다.

도메인 밖 작업이 필요하면? 에이전트는 **자기 손으로 고치지 않고** 오케스트레이터에게 에스컬레이션합니다. "이건 backend-agent 영역" 식으로.

### 기둥 3: Progressive Disclosure Skills

예전에는 `.claude/rules/web.md`, `rules/mobile.md` 같은 파일에 도메인별 규칙을 쌓아뒀습니다. 문제는 **전부 매 세션 로드**된다는 것. 웹 작업만 하는데 모바일 규칙까지 컨텍스트에 들어갑니다. 토큰 낭비 + 정확도 하락.

해결책: **Skills 시스템** (`.claude/skills/<skill-name>/SKILL.md`).

```yaml
# web-next16/SKILL.md 프론트매터
---
name: web-next16
description: Next.js 16 App Router conventions...
---
```

그리고 에이전트 프론트매터에 `skills: [web-next16, api-plane-governance]`라고 선언. **에이전트가 spawn될 때만 해당 skill 본문이 주입**됩니다. 메인 세션은 가볍게 유지, 도메인 지식은 필요한 순간만 무겁게.

### 기둥 4: Deterministic Hooks

LLM 판단에 의존하지 않는 **결정론적 가드**. Claude Code 내장 훅 + git 네이티브 훅 두 레이어입니다.

**Claude Code 훅** (`.claude/hooks/`):
- `security-guard.sh` — PreToolUse로 `.env`, `credentials/`, `*.pem` 등 쓰기 차단. 수 ms 만에 exit 2
- `session-start.sh` — 매 세션 시작 시 브랜치/변경 영역/**열린 에스컬레이션** 자동 노출

**Git 네이티브 훅** (`.githooks/`):
- `pre-commit` — `gitleaks protect --staged` 실행. **Claude Code뿐 아니라 Codex, 수동 git, IDE 통합 전부에 적용**되는 마지막 방어선

왜 두 레이어인가? Claude Code 훅은 Claude Code 세션 안에서만 발화합니다. Codex를 별도 터미널에서 돌리면 안 먹힙니다. 그래서 git 레이어에 한 번 더 걸어둡니다.

---

## 계약 관리 — OpenAPI를 단일 진실의 원천으로

위 4개 기둥 외에 **한 레이어 더** 있습니다. 계약 드리프트가 가장 큰 문제였거든요.

### SSOT 설정

1. FastAPI가 **자동으로** `apps/api/openapi/openapi.json` 스냅샷 생성
2. `openapi-typescript`가 그 스냅샷으로 TypeScript 타입 자동 생성 → `packages/types/src/generated/api.ts`
3. CI가 두 스냅샷 모두 **최신인지 강제** — 커밋된 snapshot과 현재 코드가 다르면 PR 블록
4. `validate_mobile_contracts.py`가 Dart 호출을 OpenAPI 경로와 대조. 없는 엔드포인트 호출은 orphaned로 태그

### Contract Sync 체크리스트

`backend-agent`의 프롬프트에 강제되어 있는 **작업 완료 조건**:

```bash
# 1. OpenAPI snapshot 재생성
cd apps/api && uv run python scripts/export_openapi.py

# 2. TypeScript 타입 재생성
pnpm --filter @harukoto/types gen:api

# 3. 모바일 드리프트 검증
cd apps/api && uv run python scripts/validate_mobile_contracts.py
```

셋 다 통과해야 SUMMARY에 "Downstream: clean" 기록하고 작업 종료. 드리프트 발견되면 에스컬레이션 파일로 기록 → 다음 세션 시작 시 자동 노출.

**TypeScript는 자동 동기화**. 백엔드 스키마 바뀌면 다음 `gen:api` 실행 때 타입이 갱신되고, 사용처에서 타입 에러로 즉시 드러납니다. 수동 유지 0.

**모바일은 감지만**. Dart codegen은 기존 Riverpod/Dio 아키텍처와 충돌 위험이 커서 도입하지 않았습니다. 대신 validator가 orphaned endpoint를 잡아내면 `mobile-agent`가 다음 세션에서 수정하는 구조.

---

## 실전 증거 — subscription drift 엔드투엔드

이 시스템이 처음 실전 가동한 날, `validate_mobile_contracts.py`의 첫 실행 결과:

```
## Endpoint existence — scanned 62 Dio call(s)
❌ 1 orphaned call(s):
   POST /api/v1/subscription/subscribe
   (apps/mobile/lib/features/subscription/data/subscription_repository.dart:16)
```

### 조사

호출 경로 추적:

```bash
grep -rn "subscribe\b" apps/mobile/lib/features/subscription
```

결과: `SubscriptionRepository.subscribe(String planId)` 메서드가 존재하지만 **어디서도 호출되지 않음**. 실제 결제 UI는 다른 파일이고, 그 화면은 아직 "결제 기능은 준비 중입니다"라는 placeholder. `subscribe()`는 몇 주 전 프로토타입의 유물 — 지워지지 못하고 남아있던 **dead code**였습니다.

### 수정

7줄 삭제. 커밋 `f9c5aab`:

```
fix(mobile): remove dead subscribe() method that called nonexistent endpoint
```

### 재검증

```
## Endpoint existence — scanned 62 Dio call(s)
✓ every Dio path matches an OpenAPI route
```

드리프트 0. CI의 `api-contract` 잡에서 `continue-on-error: true` 플래그 제거 → 이제부터 orphaned endpoint는 **PR 하드 블록**.

### 교훈

이 버그의 **실제 가치**가 뭐냐면:
- 유저가 만나기 전에 잡음 (런타임 404 방지)
- "교체해야 할 엔드포인트"가 아니라 "삭제해야 할 dead code"임을 빨리 판단 가능
- 하네스가 첫 실행부터 실제 가치를 내는 **증거 확보**

감지기가 제대로 설계되었는지는 **실제로 뭔가 잡을 때** 알 수 있습니다. 이론상 작동하는 시스템과 실제 작동을 증명한 시스템은 다릅니다.

---

## 한계와 안 한 것들

솔직한 기록이 중요하니 **안 한 것**도 밝힙니다.

### 의도적으로 스킵한 것

- **Mutation testing (Stryker)** — 257개 테스트에 도입하면 CI 10배 느려짐. 솔로 프로젝트 ROI 마이너스
- **Property-based testing (fast-check)** — CRUD 위주 앱에서 가치 제한적. 특정 알고리즘 영역(SRS 계산)에만 고려
- **Devcontainer 격리** — 민감 도메인(금융/의료) 아니라 오버헤드만 큼
- **Feature flag 인프라 (LaunchDarkly 등)** — 유료 도구 과함. 필요 시 자체 간단 flag로
- **전면 E2E (Playwright)** — 단위/integration 테스트로 이미 257개 커버. 포트폴리오용 smoke 1~2개는 차후 고려

### 실제 구멍 (중기 과제)

Codex에게 교차 검증 요청했을 때 찾아준 것들:

1. **CI action SHA pinning 없음** — `@v5` 태그 참조라 악성 action 주입 가능. Dependabot 또는 SHA pinning 필요
2. **deploy-api 수동 승인 없음** — `main` push = Cloud Run 즉시 배포. 롤백 runbook 없음
3. **AI 비용 모니터링 없음** — `packages/ai`가 여러 provider 래핑하지만 token usage log 계층 없음

이 셋은 실제 사고가 나기 전 선제 구축하면 과설계 위험이 있어서 **Tier 2로 보류**. Pain 생기면 대응.

### Claude의 맹점

Codex 교차 검증은 내 맹점을 세 개 더 잡았습니다:

- L2 점수를 내가 5점 준 건데 실제론 6점. 로컬 settings에 이미 있던 deny 룰을 조사 에이전트가 놓침
- L7 점수도 과도하게 박게 줬음. Sentry가 web/mobile/api 3개 앱 모두 연결되어 있는데 web만 보고 판단
- 내가 "피하자"고 한 Playwright가 실제로는 포트폴리오용 smoke 1~2개라면 가치 있음

**구현자 ≠ 리뷰어 원칙**이 여기서 작동합니다. 같은 AI가 짜고 같은 AI가 리뷰하면 맹점이 복제됩니다. Claude + Codex 병행의 진짜 가치는 **속도**가 아니라 **교차 검증**입니다.

---

## 다른 사람이 적용할 수 있는 패턴

이 프로젝트의 코드 대부분은 특수하지만, 하네스의 **원칙은 이식 가능**합니다.

1. **컨텍스트는 파일로** — CLAUDE.md / AGENTS.md. 대화에 남기면 세션 끝나면서 증발. 파일이면 다음 세션도 읽음
2. **경계는 tool-level로 강제** — 프롬프트로 "수정하지 마세요"는 언젠가 뚫림. 서브에이전트 frontmatter, deny 룰, pre-commit 훅으로 물리적 차단
3. **계약은 SSOT + CI freshness** — 언어 경계(백엔드 Python, 프론트 TS, 모바일 Dart)마다 타입이 흩어지면 드리프트는 필연. 한 곳에서 생성해서 나머지에 배포
4. **결정은 파일로 persist** — "AI가 막혔을 때" 디렉토리(`.planning/escalations/`) 하나 만들고, 세션 시작 훅이 자동 노출하게. 자동화 연속성은 이걸로 만들어짐

---

## 마무리

하네스 엔지니어링의 본질을 한 문장으로:

> **AI의 속도를 활용하되, 그 속도에 짓밟히지 않는 시스템을 만드는 것.**

이건 완성된 시스템이 아닙니다. 앞으로 실제 사고가 생길 때마다 보강할 겁니다. 공급망 방어, 배포 게이트, AI 비용 로깅 — 전부 "아직 필요 없어서 안 한" 것들이고, 언젠가 필요해질 겁니다.

중요한 건 **어제 한 번도 작동 안 하던 감지기가 오늘 실제 버그를 잡았다**는 것. 이론으로 있던 시스템이 코드가 되고, 버그 한 건을 잡고, 하드 fail로 전환되는 짧은 사이클. 하네스는 이렇게 진화합니다.

---

**저장소**: [github.com/WhiteMouseDev/HaruKoto](https://github.com/WhiteMouseDev/HaruKoto)
**하네스 기술 문서**: `docs/operations/harness.md`
**이 글의 커밋**: `f9c5aab` (subscription drift fix), `8efd767` (contract pipeline), `8ef9f96` (Phase-2 hardening)

*Feedback welcome. 이 글을 읽고 하네스 도입을 검토 중이시면 연락 주세요.*
