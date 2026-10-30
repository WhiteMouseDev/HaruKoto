---
raised_by: Codex root
raised_at: 2026-10-30T12:23:23+09:00
phase: daily-vocabulary-goal
severity: warn
status: resolved
resolved_at: 2026-10-30T12:39:24+09:00
---

## What happened

홈의 새 단어 목표는 오늘 답안을 저장한 고유 단어 수지만, 기존 `quiz_smart.load_today_completed_count`는 카테고리 구분 없는 답안 행 수를 센다. `GET /api/v1/quiz/smart-preview`의 `todayCompleted`와 추천 배분은 이 값을 사용하므로 홈 목표와 추천 문항 수가 서로 다를 수 있다.

## Decision required

단어 카테고리의 미리보기에도 새 KST 고유 단어 수를 적용할지 결정한다. 이는 기존 `todayCompleted` 값의 의미와 추천 문항 수를 바꾸므로 대시보드 객체 추가와 구분해 확인했다.

## Resolution

2026-10-30 사용자가 구체적인 추가 범위에 **‘추천대로 함께 수정’**을 선택해 1안을 승인했다. 단어 미리보기만 같은 집계와 남은 목표를 사용하고 문법 추천·복습 기한·기록·DB 구조는 유지한다. API 응답 구조는 바꾸지 않는다. 목표를 이미 달성했을 때의 기존 추가 학습 경로는 유지한다.

## Options considered

1. `VOCABULARY` 미리보기만 새 집계와 정합성을 맞춘다. `todayCompleted`는 오늘 고유 단어 수, 남은 목표는 기존 목표에서 이를 뺀 값으로 계산한다. 문법·복습 기한·추천 배분 알고리즘은 유지한다.
2. 이번에는 홈 카드와 대시보드 추가만 반영하고 미리보기의 기존 집계·추천 문항 수는 유지한다. 두 지표의 차이를 알려야 한다.

## Recommended direction

1안을 권장한다. 학습 진입 시 같은 단어 목표를 기준으로 추천해야 홈의 남은 수치와 다음 행동이 연결된다. 실제 원문/응답 필드의 구조 변경이나 DB 변경 없이 단어 미리보기 계산만 바꿀 수 있다.

## Side effects

- `apps/api/app/services/quiz_smart.py`: 단어 미리보기 집계 입력 변경과 회귀 테스트.
- 모바일의 미리보기 재조회: KST 날짜 변경·목표 변경 후 오래된 추천이 남지 않는지 확인.
- 기존 답안·SRS·복습 기한·XP·기록·권한·환경 변경은 없다.
- 응답 shape는 같지만 값의 의미가 바뀌므로 별도 승인을 받은 뒤 이 추가 범위를 구현한다. 승인과 구현 완료·운영 반영은 서로 구분한다.
