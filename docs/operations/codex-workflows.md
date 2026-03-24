# Codex Workflows

> HaruKoto 프로젝트에서 Codex를 시니어 개발자처럼 쓰기 위한 실전 운영 가이드.

## 목적

이 문서는 Codex를 단순 코드 생성기가 아니라 다음 역할로 쓰기 위한 기준을 정리한다.

- 구현 담당자
- 복잡한 변경의 사전 플래너
- 교차 앱 영향 검토자
- 리뷰어

전역 규칙은 `~/.codex/AGENTS.md`, 프로젝트 규칙은 루트 `AGENTS.md`와 경로별 `AGENTS.md`에서 자동 로드된다. 이 문서는 실제 작업을 어떻게 요청할지와 어떤 검증을 요구할지를 정의한다.

## 기본 원칙

- 작업 요청은 항상 `Goal / Context / Constraints / Done when` 구조로 준다.
- 모노레포에서는 한 파일만 바꿔도 끝이 아닐 수 있다. 패키지, API 계약, auth, DB 변경은 반드시 소비 앱까지 본다.
- Codex가 코드를 쓰게 할 때는 검증 커맨드까지 같이 요구한다.
- 애매한 작업은 바로 구현시키지 말고 먼저 계획을 세우게 한다.
- 리뷰 요청은 스타일보다 버그, 회귀, 타입/계약 불일치, 런타임 위험을 우선 보게 한다.

## 프로필 선택

기본값은 균형형이다. 작업 성격이 분명하면 프로필을 바꿔 쓴다.

- `codex --profile fast`
  - 작은 수정, 빠른 탐색, 단순 리팩터링
- `codex --profile deep`
  - 설계, 복잡한 디버깅, 큰 범위 변경, API/DB 영향 분석
- `codex --profile review`
  - 코드리뷰, diff 점검, 회귀 위험 탐지

## 작업 시작 템플릿

가장 기본이 되는 프롬프트 형식이다.

```md
Goal
- 무엇을 바꾸고 싶은지 한 문장으로 설명

Context
- 관련 파일/폴더
- 관련 문서
- 재현 방법 또는 현재 문제

Constraints
- 지켜야 할 아키텍처/스타일/호환성
- 건드리면 안 되는 영역
- 필요한 검증 범위

Done when
- 완료 기준
- 통과해야 하는 명령
- 사용자에게 보고해야 하는 내용
```

예시:

```md
Goal
- 홈 화면의 학습 진행 카드 레이아웃을 개선하고 데이터 로딩 상태를 안정화해.

Context
- apps/web/src/app/(main)/home/**
- apps/web/src/components/**
- docs/product/screens/home.md

Constraints
- Server Components 기본 구조 유지
- 기존 API 계약은 바꾸지 말 것
- 모바일 레이아웃 우선

Done when
- 빈 상태, 로딩 상태, 데이터 있음 상태가 모두 자연스럽게 동작
- pnpm --filter web lint
- pnpm --filter web test
```

## 작업 유형별 프롬프트 템플릿

### 1. 기능 구현

```md
이 기능을 구현해.

Goal
- [기능 설명]

Context
- 관련 경로: [파일/폴더]
- 참고 문서: [docs 경로]

Constraints
- 기존 패턴 우선
- 새 의존성 추가 금지
- 불필요한 리팩터링 금지

Done when
- 코드 변경 완료
- 영향받는 테스트/검증 명령 실행
- 변경 이유와 리스크를 짧게 정리
```

### 2. 버그 수정

```md
이 버그를 원인부터 찾아서 최소 수정으로 해결해.

Context
- 재현 증상: [증상]
- 관련 경로: [파일/폴더]
- 에러 로그: [있으면 첨부]

Constraints
- 원인 분석 없이 추측 패치하지 말 것
- 관련 없는 구조 변경 금지
- 회귀 가능성이 있으면 테스트 추가

Done when
- 재현 경로 기준으로 버그가 사라짐
- 왜 발생했는지 설명 가능
- 필요한 검증 명령 통과
```

### 3. 코드 리뷰

```md
이 변경을 리뷰해. 스타일 말고 버그, 회귀, 타입/계약 불일치, 런타임 위험 위주로 봐.
발견 사항이 있으면 심각도 순으로 정리하고 파일/라인을 붙여.
없으면 없다고 명확히 말해.
```

### 4. 리팩터링

```md
이 영역을 리팩터링해. 단, 동작 변경 없이 구조만 개선해.

Constraints
- public API 유지
- 테스트가 있는 경우 모두 유지
- diff를 작게 유지

Done when
- 읽기 쉬워지고 중복이 줄어듦
- 동작 변경 없음
- 영향 범위 검증 완료
```

### 5. API 계약 변경

```md
API 계약 변경 작업이야. 구현 전에 영향 범위를 먼저 분석하고 계획을 제시해.

Context
- apps/api/**
- apps/web/**
- apps/mobile/**
- docs/architecture/api/**

Constraints
- 모바일 파서 호환성 확인
- 응답 키, enum, auth semantics 변경 시 소비자 수정 포함
- 가능하면 단계적 변경으로 설계

Done when
- 영향 분석
- 변경 계획
- 구현
- web/mobile 소비자 검증 항목 정리
```

### 6. 공유 패키지 변경

```md
shared package 변경이야. 패키지 수정만 하지 말고 소비자 영향까지 같이 봐.

Context
- packages/types 또는 packages/ai 또는 packages/database
- 관련 소비자 앱 경로

Constraints
- deep import 유도 금지
- API surface 최소화
- breaking change면 명시

Done when
- 패키지 수정
- 직접 소비자 검증
- 영향 범위 요약
```

## 모노레포 검증 체크리스트

### 공통

- `pnpm lint`
- `pnpm test`
- 변경이 큰 경우 `pnpm build`

### Web

- `pnpm --filter web lint`
- `pnpm --filter web test`
- 라우트, env, 서버/클라이언트 경계, 공유 패키지 변경 시 `pnpm --filter web build`

### Landing

- `pnpm --filter landing lint`
- `pnpm --filter landing build`

### API

- `cd apps/api && uv run ruff check app/ tests/`
- `cd apps/api && uv run ruff format --check app/ tests/`
- `cd apps/api && uv run mypy app/`
- `cd apps/api && uv run pytest`

### Mobile

- `cd apps/mobile && make format`
- `cd apps/mobile && make analyze`
- `cd apps/mobile && make test`

### Shared Packages

- `pnpm --filter @harukoto/types lint`
- `pnpm --filter @harukoto/ai lint`
- `pnpm --filter @harukoto/database lint`
- 패키지 변경 후 직접 소비 앱 최소 1곳 이상 검증

## 교차 영향이 큰 변경

아래는 로컬 수정으로 취급하지 않는다.

- `packages/types` 변경
- `packages/database` 변경
- `packages/ai` 변경
- `apps/api` 응답 스키마 변경
- auth/session/role 로직 변경
- 결제, 푸시 알림, AI provider 전환

이 경우 Codex에게 다음을 같이 요구한다.

```md
구현만 하지 말고 영향받는 consumer와 추가 검증이 필요한 앱을 같이 적어.
```

## 추천 운영 루틴

### 작은 작업

1. `fast` 프로필로 시작
2. 바로 구현
3. 영향 범위에 맞는 최소 검증 실행
4. 마지막에 diff 리뷰

### 큰 작업

1. `deep` 프로필로 시작
2. 먼저 계획 요청
3. 영향 범위 확인 후 구현
4. 검증
5. 필요하면 `review` 프로필로 별도 리뷰

### 리뷰 전용

1. `review` 프로필로 실행
2. diff 또는 변경 경로 지정
3. 버그/회귀/계약 위험만 우선 보고 받기

## 좋은 요청과 나쁜 요청

좋은 요청:

```md
apps/api의 사용자 구독 응답을 수정해야 해.
먼저 web/mobile consumer 영향 범위를 분석하고,
호환성을 깨지 않는 변경 순서로 계획을 세운 뒤 구현해.
완료 전에 ruff, mypy, pytest와 관련 consumer 검증까지 해.
```

나쁜 요청:

```md
구독 쪽 좀 고쳐줘
```

좋은 요청:

```md
packages/types의 결제 타입을 정리해.
breaking change는 피하고, apps/web 소비 코드도 같이 확인해.
완료 기준은 package lint와 web lint 통과야.
```

나쁜 요청:

```md
type만 정리해줘
```

## 마무리 요청 템플릿

작업이 끝날 때 이런 식으로 보고하게 하면 품질이 안정적이다.

```md
마무리할 때 아래 형식으로 보고해.
- 무엇을 바꿨는지
- 왜 그렇게 바꿨는지
- 어떤 검증을 돌렸는지
- 못 돌린 검증이 있으면 무엇인지
- 남은 리스크가 있으면 무엇인지
```

## 문서와 규칙의 우선순위

이 프로젝트에서 Codex는 아래 순서로 지침을 읽는다고 가정한다.

1. `~/.codex/AGENTS.md`
2. 레포 루트 `AGENTS.md`
3. 경로별 `AGENTS.md`
4. `CLAUDE.md`
5. 관련 `docs/` 문서

작업 규칙이 바뀌면 `AGENTS.md`를 먼저 고치고, 도메인/기획 지식이 바뀌면 `docs/`를 갱신한다.
