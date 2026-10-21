---
raised_by: Codex wrong-review investigation
raised_at: 2026-10-21T14:01:16+09:00
severity: blocker
status: resolved
resolved_at: 2026-10-21T14:05:41+09:00
---

## Resolution

사용자가 제시한 API 추가안대로 구현하도록 명시적으로 승인했다. DB DDL·권한·Data API 설정 변경 없이 전용 API와 앱 소비자·회귀를 구현한다. API 결정 대기는 해소됐지만 코드 검증·병합·배포가 끝났다는 뜻은 아니다. 배포와 실기기 설치는 이번 작업에서 수행하지 않는다.

## What happened

현재 복습 API는 기한이 된 일반 항목만 조회하며 원본 퀴즈를 지정할 계약이 없다. 기존 시작 경로는 다른 미완료 퀴즈까지 완료 처리하므로, 기존 학습 기록을 유지하는 세션 한정 오답 복습에 그대로 쓸 수 없다. 사용자는 API 또는 DB 변경 전에 구체안을 먼저 요청했다.

## Decision required

[상세안](../../docs/operations/plans/session-wrong-answer-review-2026-10-21.md)의 새 `POST /api/v1/quiz/wrong-answer-review/start`와 모바일 소비자 구현을 승인할지 결정한다. 입력은 `sourceSessionId` 하나, 응답은 기존 resume 스키마를 재사용한다. 1차 지원은 일반·스마트 단어/문법/한자/듣기 선택형이다.

## Options considered

1. 전용 API 추가: 소유권과 최초 오답·원본 스냅샷을 서버에서 확인하고 새 복습만 생성/재사용한다. 권고안이다.
2. 오류 화면만 먼저 개선하고 세션 한정 복습은 보류한다. DB/API 계약 변경은 없지만 핵심 오답 복습 문제는 남는다.
3. 기존 stageId·일반 review를 재활용하거나 완료된 원본 답안을 재제출한다. 범위 오인과 기존 기록 변경 위험 때문에 권고하지 않는다.

## Recommended direction

신규 API와 기존 JSON 메타데이터로 DB DDL 없이 구현한다. 동일 원본의 **진행 중** 복습을 재사용하고 answeredQuestionIds를 돌려줘 재개한다. 완료·기존 자동 종료 정책으로 닫힌 뒤 시작하면 새 시도이며, 완료 이후까지의 영구 멱등성은 범위가 아니다. 기존 오답 GET도 최초 답안 규칙을 공유해 목록과 출제를 맞춘다. 승인 전에는 계약과 서버를 수정하지 않고 모바일 오류 표시·GET/기존 resume 재시도와 회귀만 진행한다.

## Side effects

신규 오답 복습 시작 API 호출 중 원본·다른 미완료 퀴즈·기존 점수/답안/XP를 다시 쓰거나 자동 완료하지 않는다. 새 복습 답안에만 기존 학습·XP 정책이 적용된다. 일반 시작과 미완료 조회의 기존 자동 종료 정책 자체는 바꾸지 않는다. 새 테이블/컬럼·권한/RLS·Data API·환경 계약 변경은 없다. 승인 후 API OpenAPI·생성 TS 타입·모바일 계약 및 web 호환성을 함께 검증한다. 배포와 실기기 설치는 현재 수행하지 않는다.
