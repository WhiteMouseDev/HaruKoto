---
raised_by: codex-root
raised_at: 2026-11-02
phase: answered-study-day-operational-readiness
severity: warn
status: resolved
resolved_at: 2026-11-03T13:08:06+09:00
---

## Resolution

사용자가 내부 테스트 범위의 실제 전환과 DB·배포 변경을 승인했고, 다른 내부 테스터 전원 중단도 확인했다. 새 Preview/WAF는 제외했다. 실제 구 API 프로세스 종료와 DB 트랜잭션 정리를 확인한 뒤 기존 p6만 적용하고 #215 호환 OFF → #216 ON을 배포했다. 기존 18테이블·권한 보존과 ON 단일 activity의 중복 방지를 검증했다. Data API 차단과 기존 음원 설정은 유지했다.

웹의 createDeployments=disabled가 main Git 배포 생성을 막지 못한 관측은 한계로 남긴다. 해당 자동 배포는 p6 이후 main에 병합한 호환 OFF였으며 구 writer가 아니었다. 이 설정을 writer 차단 보장으로 재사용하지 않는다. 실제 변경·복구와 검증 범위는 [전환 결과](../../docs/operations/plans/internal-study-release-results-2026-11-03.md)를 따른다. 아래 내용은 해결 전 판단 이력이다.

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

## 2026-11-02 읽기 조사와 구체안 갱신

실제 운영 head o5/p6 미적용·공유 postgres 역할·Cloud Run 공개 최신 라우팅·자동 배포와 보관 웹 배포 114개/READY16개를 확인했다. 기존 유지보수 gate나 active WAF는 없고, 현재 DB에 writer가 없다는 순간 스냅샷은 실행 종료 증거가 아니다. [구체 운영안](../../docs/operations/plans/study-day-font-fix-and-rollout-2026-11-02.md)은 자동 배포 freeze → legacy STOP bridge/모든 구 host 차단 → 실제 종료와 DB 증거 → p6 → OFF → 별도 ON을 제시한다. 새 API 동작·bridge 코드·클라우드/WAF·종료/삭제·마이그레이션은 미구현/미적용 제안이며 별도 승인을 받는다. Data API·권한·기록은 유지했다.

## 2026-11-03 통합 검증과 운영 변경안

legacy STOP #218과 p6 통합 OFF #219·갱신한 #216 ON의 코드 검증을 분리했다. 새 읽기 조사도 o5/p6미적용·Data API차단을 확인했다. 웹은 보관123/READY22/alias57개이며 actual custom alias가 현재 서비스 기준이다. `project.targets.production`의 CANCELED 포인터를 자동 기준으로 쓰지 않는다.

[구체 설정·복구 요청 명세](../../docs/operations/plans/study-day-operating-change-proposal-2026-11-03.md)와 private JSON/host snapshot을 준비했다. 권장안은 현재 승인 host의 앱503 STOP과 이전 host 전체deny WAF1규칙이다. 이전 주소의 로그인/조회/콜백까지 차단하는 추가 영향은 별도 승인 대상이다. 현재 WAF NONE에서 최초 생성/게시 후 완전 NONE 복원은 공식 절차를 확정하지 못했으며 빈 active rules와 같다고 설명하지 않는다. 현재 관측으로 old handler 실제 종료를 증명하지 못했으므로 운영 전환 NO-GO를 유지한다.

첫 WAF 절차·원복과 callback 영향 검증, 최종 legacy ON artifact·digest, 기존 실행 종료 증거/필요 계측안을 먼저 확정해야 한다. 운영 변경·유료전환·revision삭제·DB세션종료·권한/비밀번호 변경은 수행하지 않았다. 이는 코드 작업을 중단한다는 뜻이 아니며 통합/시뮬레이터/CI 검증은 계속한다.

추가 key/target 읽기에서 Vercel DATABASE_URL·DIRECT_URL은 같은항목이production/preview/development에공유된것을확인했다(값복호화없음). 현재Preview는분리QA환경이아니므로 live학습검증에사용하지않는다. 이번검증은전부localhost폐기형DB/합성Auth/API였다. 온라인Preview가필요하면production값을유지한preview전용DB/Auth/API·Secret범위분리와복구payload를별도승인받는다. 새자원/비용/설정변경은적용하지않았다.

## 2026-11-03 내부 테스트 범위로 우선순위 조정

사용자는 정식 출시 전이라고 설명했고 Preview 격리보다 기능의 내부 반영을 우선하도록 요청했다. 다른 내부 테스터도 있다고 확인했다. 새 Preview 인프라/WAF/NONE 복원은 현재 전환의 필수조건에서 제외하며 [간소화 전환안](../../docs/operations/plans/internal-study-release-2026-11-03.md)을 준비한다. 알려진 모든 내부 앱/웹의 일시중지, 실제사용경로·현재실행/트랜잭션 확인, 새/구잠금 writer 혼용방지와 DB/설정 사전승인은 유지한다. 과거 넓은운영안의 NO-GO를 새인프라구축을 강제하는 뜻으로 사용하지 않는다.
