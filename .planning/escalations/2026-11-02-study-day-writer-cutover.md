---
raised_by: codex-root
raised_at: 2026-11-02
phase: answered-study-day-operational-readiness
severity: warn
status: open
---

## What happened

한 문항 학습일 인정 구현·격리 검증은 완료했지만 운영에는 적용하지 않았다. 호환 OFF 코드도 사용자 → 세션 잠금을 사용한다. 기존 세션 → 사용자 writer와 혼용하면 교착 위험이 있으므로 활성화만 늦추는 것으로 충분하지 않다.

## Decision required

운영 승인 전에 API·웹의 학습 쓰기 일시 중지 대상·영향·해제 기준과 실제 진행 중인 writer/트랜잭션 종료 확인 방식을 정한다. 운영 DB에 연결 가능한 구 Vercel 배포 URL의 새 쓰기 재진입 방지/퇴역도 구체안을 승인받는다. 이번에는 새 유지보수 기능·환경 변수·클라우드 접근 제어를 적용하지 않았다.

## Options considered

1. 별도 승인된 쓰기 통제하에 기존 실행 종료 → p6 → 호환 OFF API·웹 → 구 writer 재진입 차단 확인 → ON으로 전환한다. 기존 기록을 보존하지만 일시적 학습 저장 중단 영향이 있다.
2. OFF만 먼저 배포하고 새 코드에 트래픽 100%를 주거나 고정 시간 기다린다. 구 요청·이전 배포 URL·504 이후 컨테이너 실행을 배제하지 못하므로 권하지 않는다.
3. 별도 호환 잠금 프로토콜을 새로 설계한다. 작업/검증 범위가 늘어나므로 필요하다면 추가 구체안으로 다룬다.

## Recommended direction

운영 적용을 요청받으면 먼저 읽기 전용으로 revision/배포 경로·DB head/권한을 확인한 뒤 1번의 구체 대상과 운영 영향안을 제시한다. 실제 종료를 확인할 수 없으면 전환하지 않는다. 로컬 검증만으로 무중단을 약속하지 않는다.

## Side effects

영향은 운영 학습 저장의 전환 창과 API/웹 배포 경로다. 로그인·기존 기록·SRS 기한·음원·Data API 차단은 보존한다. 롤백은 새 컬럼/영수증을 이해하는 OFF 버전이며 기존 writer로 단순 되돌리거나 인정 기록을 삭제하지 않는다. [상세 적용·롤백안](../../docs/operations/plans/answered-study-day-policy-implementation-2026-11-02.md)을 따른다.
