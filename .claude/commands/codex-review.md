# Codex Review

Codex에게 교차 검증을 요청합니다. 인자로 review mode를 전달할 수 있습니다.

## 사용법

- `/codex-review` — 현재 변경분 코드 리뷰
- `/codex-review design` — 설계/계획 검증
- `/codex-review audit` — 저장소 전반의 위험 스캔

## 기본 리뷰

현재 diff를 기준으로 Codex에게 아래 항목을 우선 검증하게 합니다.

1. API 계약 정합성
2. 타입 안전성 및 런타임 에러 가능성
3. web/mobile/admin consumer 영향 범위
4. 테스트 및 검증 공백

## design 모드

설계 문서가 있으면 함께 전달합니다.

- `docs/operations/plans/*.md`
- `.planning/ROADMAP.md`
- 관련 phase/context/research 문서

Codex에게 아래를 검증하게 합니다.

1. 빠진 edge case와 리스크
2. 구현 순서와 검증 순서의 타당성
3. 기존 구조와의 충돌 여부
4. cross-surface 영향 범위

## audit 모드

저장소 전반에서 아래를 찾게 합니다.

1. API contract drift
2. 타입/런타임 취약 패턴
3. 검증 하니스 누락
4. auth, billing, migration, content-review 흐름의 고위험 공백

## 결과 처리

- High severity: 반드시 수용 또는 근거 있는 반박
- Medium/Low severity: 우선순위에 따라 수용/보류
- Codex 결과는 그대로 따르지 말고 로컬 코드와 검증 결과로 재판단합니다.
