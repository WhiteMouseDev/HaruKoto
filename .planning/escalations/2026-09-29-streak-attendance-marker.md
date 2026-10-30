---
raised_by: codex-root
raised_at: 2026-09-29
phase: streak-integrity
severity: warn
status: open
---

## What happened

9월 29일 로컬 작업에 영속 출석 마커 제안이 open 상태로 남아 있었고, 10월 30일 누락 감사에서 이를 다시 확인했다. 기존 일별 행은 시작만 해도 생성될 수 있고, 레슨 재학습의 마지막 완료일만으로 모든 과거 학습일을 복원할 수 없다.

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
