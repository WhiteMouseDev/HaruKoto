---
raised_by: codex-root
raised_at: 2026-10-30T14:35:00+09:00
phase: partition-read-only-audit
severity: warn
status: resolved
resolved_at: 2026-10-30T14:49:20+09:00
deadline: 2026-10-31
---

## What happened

운영 카탈로그 읽기 전용 검사에서 2026년 3월~2027년 1월 11개 파티션의 정상 연속 커버리지와 2027년 2월 파티션 부재를 확인했다. 10월 22~30일 일일 점검은 모두 성공했다. 11월 1일 00:00 UTC(09:00 KST)부터 다음 3개월 정책에 2월이 포함되므로 현재 카탈로그 그대로라면 ADVISORY가 발생한다.

## Resolution

사용자가 PR #206 병합과 제안한 2월 파티션 마이그레이션·회귀 테스트·운영 적용을 승인했다. 기존 학습 기록·권한·Data API 차단을 유지하고, 적용 후 점검 결과와 로그인·학습·이어하기를 시뮬레이터로만 검증한다. 이 resolved 상태는 승인 결정이 해소됐다는 뜻이며 적용 완료를 뜻하지 않는다. 구현·운영 결과는 [별도 적용 기록](../../docs/operations/plans/review-event-february-partition-rollout-2026-10-30.md)에 남긴다. 특수 퀴즈 이어하기 API의 구현 승인은 이번 요청에 포함되지 않는다.

## Decision required

이전 단계에서는 새 Alembic 마이그레이션으로 `public.review_events_2027_02` 하나를 UTC `[2027-02-01, 2027-03-01)`에 추가하는 구현·운영 적용 범위 승인이 필요했다. 이후 위 Resolution의 범위로 승인됐다. 승인된 새 자식의 RLS/권한 검증 외에 기존 권한이나 클라우드 설정 변경은 포함하지 않는다.

## Options considered

1. 새 자식 파티션 하나만 기존 인덱스·RLS·클라이언트 접근 차단을 검증하며 추가한다. 기존 행과 부모·기존 자식 권한은 유지한다.
2. 점검 계정에 DDL 권한을 주고 자동 생성시킨다. 최소 권한 경계를 깨므로 권장하지 않는다.
3. 보완하지 않고 11월 1일 경고를 받은 뒤 대응한다. 현재 서비스 장애는 아니지만 사전 준비 목적에는 맞지 않는다.

## Recommended direction

1번을 10월 31일까지 준비·검토·적용하는 안을 권장한다. 실제 운영 Alembic head 사전 확인, 격리 PostgreSQL 회귀, 제한된 DDL 잠금, 적용 후 검사와 시뮬레이터 검증을 포함한다. 구체안과 증거는 [감사 기록](../../docs/operations/plans/partition-monitor-audit-2026-10-30.md)에 있다.

## Side effects

새 테이블/상속 인덱스/새 자식의 RLS·클라이언트 권한 검증 및 Alembic head 갱신이 필요하다. 기존 학습 행·기한·로그인·캐시·Data API·점검 역할·스케줄은 변경하지 않는다. 앱 롤백 때 파티션은 유지하고 자동 DROP/DETACH를 금지한다. 이전 읽기 전용 감사에서는 변경하지 않았으며, 승인 후 적용 결과는 별도 기록으로 구분한다.
