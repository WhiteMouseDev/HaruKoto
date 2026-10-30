---
raised_by: codex-root
raised_at: 2026-10-07
phase: quiz-answer-persistence
severity: warn
status: open
---

## What happened

0점 오류 수정 당시 로컬에 남은 특수 모드 재개 계약의 open 항목을 10월 30일 감사·독립 검토에서도 확인했다. `VOCABULARY`와 `mode: matching/arrange`로 시작한 세션은 mode를 보존하지 않아 재개 때 일반 퀴즈로 열릴 수 있고, matching 표시용 word/meaning도 재개 응답에서 빠진다. 이번 노선도·답안 ID 복구보다 이전부터 있던 제한이다.

## Decision required

특수 모드의 원래 mode·표시 데이터를 저장/반환하고 이전 세션 호환까지 정의하는 별도 API/mobile 수정 범위를 먼저 제안해야 한다. 현재 사용자 승인된 history `hasStudied` 추가는 이 quiz 계약 확장의 승인이 아니다.

## Options considered

1. 완전한 재개 계약과 구 세션 호환을 설계하고 API·mobile·생성 타입을 함께 검증한다.
2. 불완전한 문항 모양만 보고 앱이 원래 mode를 추정한다. 장기 계약으로 신뢰하기 어려워 채택하지 않는다.

## Recommended direction

별도 작업에서 구체안을 승인받은 뒤 1번을 구현한다. 이번 matching start의 canonical 문항 ID와 첫 답안 보존·저장 재시도는 유지한다. start→answer→result 및 전부 저장된 합성 resume 테스트를 실제 부분 matching resume 검증으로 표현하지 않는다.

## Side effects

추후 변경은 quiz start/resume payload·세션 보존 형식·모바일 mode 복원·생성 타입에 영향을 준다. 공유 응답이 달라지면 웹 consumer도 확인한다. 현재 이 범위의 API나 DB 변경은 적용하지 않았다.
