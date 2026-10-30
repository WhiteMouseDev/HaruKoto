---
raised_by: Codex local-change restoration audit
raised_at: 2026-10-30
severity: warn
status: resolved
resolved_at: 2026-10-30
---

## Resolution

사용자가 구체안에 **“API 필드 추가까지 복구”**라고 승인했다. backend가 additive `hasStudied`와 최신 OpenAPI를 발행하고, 공유 타입을 생성한 뒤 모바일이 구 응답 fallback을 유지하며 소비한다. API·모바일 검증을 마친 뒤 각각 PR #202·#201에 반영한다. 이는 영속 출석 마커·DB 변경·과거 기록 보정·운영 배포 승인으로 확대하지 않는다.

## What happened

승인된 로컬 개선을 최신 main과 대조하며 학습 달력·일일 활동 새로고침 묶음과 `hasStudied` 응답 필드가 통합되지 않은 것을 확인했다. 노선도·결과·답안 ID 복원 및 순수 KST 날짜 수정은 진행했으나 API 계약이 필요한 부분은 변경하지 않았다.

## Decision required

사용자에게 `GET /api/v1/stats/history`의 `records[]`에 non-null boolean `hasStudied`를 추가하는 구체안을 비동기로 제시했고 위 Resolution으로 승인됐다. 기존 집계의 활동 여부를 계산하는 필드이며, 영속 출석 마커 신설이나 과거 기록 보정 승인을 뜻하지 않는다.

## Options considered

1. 기존 응답을 유지하고 모바일 streak/history/refresh 묶음은 별도 보류한다.
2. 추가 필드만 승인 후 최신 OpenAPI·공유 타입을 다시 생성하고, 구 응답도 지원하는 모바일 소비자를 연결한다.

## Recommended direction

상세 요청·응답·fallback·롤백은 [구체안](../../docs/operations/plans/streak-omission-compatibility-proposal-2026-10-28.md)에 있다. 기존 생성 타입을 통째로 복사하면 최신 wrong-answer-review 계약을 잃으므로 반드시 최신 소스에서 다시 생성한다.

## Side effects

API schema/history service·OpenAPI·공유 TypeScript 타입과 모바일 history model/UI/refresh가 영향을 받는다. DB schema·기록·권한·RLS·Data API·환경·복습 기한은 변경하지 않는다. 웹 history는 독립 BFF이므로 FastAPI 추가만으로 웹 달력이 수정됐다고 주장하지 않는다.
