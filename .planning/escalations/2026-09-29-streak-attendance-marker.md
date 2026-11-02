---
raised_by: codex-root
raised_at: 2026-09-29
phase: streak-integrity
severity: warn
status: open
previously_resolved_at: 2026-11-02T14:36:57+09:00
reopened_at: 2026-11-02
---

## What happened

9월 29일 로컬 작업에 영속 출석 마커 제안이 open 상태로 남아 있었고, 10월 30일 누락 감사에서 이를 다시 확인했다. 기존 일별 행은 시작만 해도 생성될 수 있고, 레슨 재학습의 마지막 완료일만으로 모든 과거 학습일을 복원할 수 없다.

## Current decision — 2026-11-02 한 문항 기준 채택, 새 API·DB 구체안 확인 대기

사용자가 한 문제라도 답하면 학습일로 인정하는 제품 정책을 채택했다. 앞선 레슨 전체 완료 기준은 구현·격리 검증을 마쳤지만 아직 운영에 적용하지 않았다. 같은 사안의 새 escalation을 만들지 않고 이 항목을 재개한다. 아래 Resolution은 이전 완료 기준 구현 승인 이력이다.

[새 구체안](../../docs/operations/plans/answered-study-day-policy-proposal-2026-11-02.md)은 미적용 마커를 `activity_recorded`로 대체하고 비공개 `study_activity_receipts` 하나, 레슨 활동 POST/GET와 상세 선택 필드·웹 표시 필드, 기존 답안 원자성·가나 재전송·앱 outbox를 포함한다. 과거 백필·기존 기한/목표/XP 재계산·Data API 재개방은 없다. 독립 문구만 수정하고 새 API·DDL/운영 적용은 아직 하지 않았다. 이전의 ‘변경 전 구체안’ 요청에 따라 이 새 계약/스키마의 구현 범위를 확인받는다.

PR #215·#216은 draft 상태로 두고 기존 완료 기준을 활성화하지 않는다. 운영 마이그레이션·클라우드 설정·배포 승인은 계속 별도다.

## Resolution — 2026-11-02 구현 승인, 운영 적용 미승인

사용자가 PR #214 병합과 [구체안 A](../../docs/operations/plans/lesson-study-day-recognition-proposal-2026-11-02.md)의 구현·회귀·시뮬레이터 검증을 승인했다. 신규 멱등 레슨 완료에만 일별 `lesson_completed`를 기록하고 과거 백필·XP·오늘 단어 목표·SRS 정책은 유지한다. 사용자별 동시 writer 보완과 Prisma 미러도 구체안의 구현 범위에 포함한다.

이 항목의 **설계 선택·코드 구현 승인**을 해결로 기록한다. 운영 마이그레이션·새 구현 PR의 병합/서버·웹 배포 승인은 아니며, [구현·검증 기록](../../docs/operations/plans/lesson-study-day-recognition-implementation-2026-11-02.md)의 결과와 운영안을 먼저 보고한다. 아래의 과거 ‘미승인’ 표시는 해당 날짜의 이력이다.

## Decision required

`daily_progress.has_studied` 같은 영속 출석 마커와 qualifying activity, 사용자별 동시 완료 처리, 증거가 있는 과거 날짜의 보정 범위를 별도로 설계·승인할지 판단이 필요하다. **현재 DB 변경·마커 신설·과거 기록 보정 승인은 없다.**

2026-10-30 승인된 API `records[].hasStudied`는 기존 양수 집계에서 계산하는 응답 필드이며, DB 마커 승인과 구분한다. 이 미결 사항은 이번 노선도·날짜 계산·집계 기반 달력 복구를 중단하는 조건이 아니다.

## Options considered

1. 영속 마커를 별도로 설계한 뒤 migration·ORM/Prisma·기존 기록 영향·consumer까지 구체안을 승인받는다.
2. 기존 모든 일별 행을 출석으로 간주한다. 시작만 한 행 때문에 채택하지 않는다.
3. 레슨의 마지막 완료일만으로 과거 날짜를 추정한다. 이전 재학습일이 사라져 보증할 수 없다.
4. XP 등 다른 지표를 조작해 출석을 만든다. 학습 기록을 왜곡하므로 채택하지 않는다.

## Recommended direction

현재는 기존 집계 기반 응답만 복구하고, 영속 출석은 별도 정책과 변경안을 먼저 제시한다. 증거가 없는 과거 날짜를 추정해 채우지 않는다. [이번 승인 범위](../../docs/operations/plans/streak-omission-compatibility-proposal-2026-10-28.md)를 넘는 DB 적용은 하지 않는다.

## Side effects

추후 채택하면 API model/Alembic·Prisma mirror·집계 처리·생성 타입과 모바일에 영향이 있다. 이번 작업에서는 스키마·기존 기록·XP·복습 기한·권한·Data API를 변경하지 않는다.

## 2026-11-02 구체안 갱신 — 설계 승인, 구현 미승인

사용자가 레슨 완료의 학습일 인정 **설계**와 복습 카드 개선을 요청했다. 복습 카드는 기존 API로 구현하고, 학습일 인정은 [구체 제안](../../docs/operations/plans/lesson-study-day-recognition-proposal-2026-11-02.md)으로 남긴다. 동일 사안의 escalation을 새로 만들지 않고 이 미결 항목에 연결한다.

권장안은 `daily_progress.lesson_completed BOOLEAN NOT NULL DEFAULT false` 한 컬럼을 추가하고, 신규 멱등 제출의 최초 `COMPLETED`와 같은 트랜잭션에 KST 학습일·연속일을 기록하는 것이다. FastAPI 필드 추가 없이 기존 `hasStudied`·연속일 응답의 의미를 확장한다. 같은 ID 재전송·다음 날 결과 복구는 추가 인정하지 않는다. 사용자별 퀴즈/가나/회화·웹 writer의 잠금 순서와 최신 값 재조회도 구현 범위에 포함해야 한다.

기존 영수증·구 pending·과거 날짜는 백필하지 않는다. XP·오늘 단어 목표·SRS 기한·Data API·권한을 변경하지 않는다. **현재 DB 마이그레이션·서버/API 동작 변경·운영 적용 승인은 없으며 실행하지 않았다.** 사용자가 구체안을 채택하면 이 항목에 승인 범위와 시각을 기록한다. 운영 적용은 구현·회귀 이후 보존/배포/롤백안을 별도로 확인한다.
