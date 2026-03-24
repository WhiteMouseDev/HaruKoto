# Codex Smoke Test

> HaruKoto 프로젝트에서 Codex 설정이 제대로 먹는지 확인하기 위한 첫 실전 테스트 모음.

## 목적

이 문서는 다음을 빠르게 확인하기 위한 것이다.

- 전역 `~/.codex/AGENTS.md`가 로드되는지
- 프로젝트 `AGENTS.md`와 경로별 `AGENTS.md`가 겹쳐 적용되는지
- Codex가 이 레포를 모노레포로 인식하고 교차 영향까지 보는지
- 프로필별 성향 차이가 실제로 체감되는지

## 권장 순서

1. `review` 프로필로 읽기 전용 리뷰를 먼저 돌린다.
2. `fast` 또는 `deep` 프로필로 작은 구현 작업을 하나 돌린다.
3. `deep` 프로필로 교차 앱 영향이 있는 계획 작업을 하나 돌린다.

## 1. 읽기 전용 리뷰 테스트

가장 안전한 첫 테스트다. 코드 수정 없이 Codex의 리뷰 품질부터 본다.

실행:

```bash
codex --profile review
```

프롬프트:

```md
이 레포의 API 계약 불일치 위험을 리뷰해.

Goal
- web, mobile, api 사이의 계약 drift 가능성이 높은 지점을 찾아줘.

Context
- apps/api/**
- apps/web/**
- docs/architecture/api/fastapi-endpoint-map.md
- docs/operations/audits/mobile-backend-api-connection-audit-2026-03-19.md

Constraints
- 코드 수정 금지
- 스타일 지적 금지
- 버그, 회귀, 타입/계약 불일치, 런타임 위험 위주
- findings가 있으면 심각도 순으로 정리하고 파일/라인을 붙여

Done when
- 가장 위험한 문제부터 정리
- open question이 있으면 따로 분리
- findings가 없으면 없다고 명확히 말해
```

잘 되면 이런 응답이 나와야 한다.

- 단순 요약이 아니라 구체적 위험을 잡아낸다.
- `apps/api`만 보지 않고 `apps/web` 또는 문서 소비자도 같이 본다.
- 스타일보다 계약/런타임 위험을 우선순위로 둔다.

## 2. 작은 구현 테스트

교차 영향이 적은 영역에서 작은 구현을 시켜본다. `landing`이 첫 구현 테스트로 가장 안전하다.

실행:

```bash
codex --profile fast
```

프롬프트:

```md
landing 페이지를 가볍게 개선해.

Goal
- 랜딩 페이지의 접근성과 메타데이터 품질을 한 단계 올려줘.

Context
- apps/landing/**
- docs/product/prd.md

Constraints
- 기존 시각 방향은 유지
- 과한 리디자인 금지
- 새 의존성 추가 금지
- landing을 product app 내부 구조와 결합하지 말 것

Done when
- 개선 포인트를 먼저 짧게 설명
- 필요한 코드만 수정
- pnpm --filter landing lint
- pnpm --filter landing build
```

잘 되면 이런 응답이 나와야 한다.

- `landing`을 독립 표면으로 다룬다.
- 과한 구조 변경 없이 작은 diff로 끝낸다.
- lint/build를 자연스럽게 포함한다.

## 3. 교차 영향 계획 테스트

모노레포 세팅이 제대로 먹는지 보려면 공유 패키지 또는 API 계약 변경 계획을 시켜보는 게 가장 좋다.

실행:

```bash
codex --profile deep
```

프롬프트:

```md
API 계약 변경을 가정하고 구현 전에 계획부터 세워.

Goal
- 사용자 구독/결제 관련 응답 스키마를 바꿔야 할 때 영향 범위와 안전한 변경 순서를 계획해.

Context
- apps/api/**
- apps/web/**
- apps/mobile/**
- docs/architecture/api/**
- docs/domain/billing/payment-system.md

Constraints
- 바로 구현하지 말고 먼저 영향 분석과 단계별 계획만 제시
- mobile parser, web consumer, auth semantics까지 고려
- breaking change 가능성이 있으면 단계적 migration 제안

Done when
- 영향받는 앱/패키지 목록
- 위험도 높은 포인트
- 구현 순서
- 필요한 검증 명령
```

잘 되면 이런 응답이 나와야 한다.

- `api만 바꾸면 끝`으로 답하지 않는다.
- `web`, `mobile`, 문서, 검증 명령까지 같이 본다.
- 단계적 migration이나 호환 전략을 제안한다.

## 평가 기준

첫 테스트 후 아래 네 가지를 본다.

- 범위 인식: 모노레포와 소비자 영향을 제대로 보는가
- 검증 습관: lint, test, build, app별 검증을 자연스럽게 붙이는가
- 리뷰 품질: 스타일보다 위험 탐지를 우선하는가
- 응답 밀도: 장황하지 않고 바로 실행 가능한가

## 테스트 후 조정 규칙

Codex가 아래처럼 실패하면 문서를 조정한다.

- 범위를 너무 좁게 본다
  - 루트 `AGENTS.md`에 consumer map 또는 validation matrix를 더 강화
- 설명이 너무 길다
  - 전역 `~/.codex/AGENTS.md`에 concise reporting 규칙 추가
- 검증을 빼먹는다
  - 경로별 `AGENTS.md`에 필수 명령을 더 직접적으로 추가
- 스타일 리뷰만 한다
  - 전역 `AGENTS.md`와 루트 `AGENTS.md`에 review priority를 더 강하게 명시

## 추천 다음 액션

첫 테스트가 끝나면 바로 아래 중 하나를 한다.

- 실제 backlog 이슈 하나를 `deep` 프로필로 처리
- 기존 diff 하나를 `review` 프로필로 리뷰
- 자주 쓰는 프롬프트를 팀 규칙에 맞게 한두 개 더 고정
