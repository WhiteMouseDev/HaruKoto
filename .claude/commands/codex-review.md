Codex에게 교차 검증을 요청합니다. 인자로 mode를 전달할 수 있습니다.

## 사용법
- `/codex-review` — 코드 변경 사항 리뷰 (기본)
- `/codex-review design` — 설계/계획 검증
- `/codex-review audit` — 전체 프로덕션 감사

## 코드 리뷰 (기본)
`git diff` 기준 변경 사항을 Codex에게 전달하고 아래 항목을 검증:
1. API 계약 정합성 (endpoint + response_model + 모바일 parser 키)
2. 타입 안전성 (as int/String 캐스팅, List null 체크, float/int 불일치)
3. 런타임 에러 가능성 (모델 필드명, query parameter case, trailing slash)
4. 기존 테스트 호환성

## 설계 검증 (design)
구현 계획을 Codex에게 전달하고 아래 항목을 검증:
1. 빠진 엣지 케이스나 리스크
2. 더 나은 접근법 존재 여부
3. 기존 코드와의 호환성
4. API 계약 변경 시 양쪽(서버/클라이언트) 영향 범위

## 프로덕션 감사 (audit)
전체 코드베이스를 Codex에게 감사 요청:
1. API 계약 불일치
2. 타입 안전성 패턴 스캔
3. 성능/안정성 이슈
4. 테스트 커버리지 공백

## 결과 처리
- P0/P1: 반드시 수용 또는 근거 있는 반박 후 사용자에게 보고
- P2 이하: Claude가 판단하여 수용/보류, 사용자에게 요약 보고
