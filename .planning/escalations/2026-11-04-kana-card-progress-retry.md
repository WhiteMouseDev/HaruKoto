---
raised_by: codex/root
raised_at: 2026-11-04T10:35:42+09:00
severity: warn
status: open
---

## What happened

가나 퀴즈 저장·완료 재시도 구현 중 문자카드의 기존 `POST /kana/progress`는 요청마다 횟수와 일별 집계를 늘리는 별도 비멱등 경로임을 확인했다. 승인 없이 카드 재전송을 추가하면 응답 유실 뒤 중복 집계할 수 있어, 해당 추가 기능은 미구현으로 남기고 승인된 퀴즈 개선·회귀·시뮬레이터와 검수 자료/쓰기 설계는 계속 진행했다.

## Decision required

문자카드도 같은 행동을 한 번만 반영하며 재시도하도록 새 접수 API와 기존 비공개 영수증 제약 확장안을 별도 승인할지 결정한다. 구체안은 [API·DB 제안](../../docs/operations/plans/kana-card-progress-retry-contract-proposal-2026-11-04.md)이다. 사용자가 API·DB 변경 전에 구체안을 먼저 확인하도록 요청했으므로 이 기록은 구현·운영 적용 승인이 아니다.

## Options considered

1. 현재 PR은 퀴즈 저장·완료의 기존 계약만 개선하고, 카드는 오류 안내·계정 보호와 기존 이동 정책을 유지한다.
2. 후속 승인 후 `activityId/expectedUserId/kanaId` 전용 API, 기존 영수증 CHECK의 `KANA_CARD_PROGRESS`, 계정별 pending 보존을 구현·검증한다.

## Recommended direction

현재 PR을 옵션1로 검증·보고하고, 문자카드 재시도가 필요하면 옵션2를 별도 작업으로 승인한다. 같은 `kanaId` 재전송이나 집계 GET으로 성공을 추측하는 우회는 사용하지 않는다.

## Side effects

후속안은 API·Alembic 제약·기존 영수증 접근 경로·모바일 pending 저장에 영향을 준다. 새 테이블/컬럼/인덱스·과거 백필은 필요하지 않다는 제안이며 권한·RLS·Data API 차단·기존 기록·SRS·오늘 단어 목표는 유지한다. 운영 적용은 로컬·PostgreSQL·시뮬레이터 검증과 별도 적용/원복안 확인 후 진행한다.
