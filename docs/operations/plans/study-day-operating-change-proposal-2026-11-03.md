# 학습일 통합 코드: 운영 변경·복구 요청 명세, 미적용

## 현재 결론과 경계

코드의 OFF/ON 검증과 운영 적용 가능성은 구분한다. **운영 전환은 아직 NO-GO다.** 최초 WAF 생성·게시·완전 복원과 구 실행 종료 증거가 미확정이다. 사용자는 이번에 통합 검증과 읽기 전용 조사·변경안 준비를 승인했으며, DB/권한·클라우드 설정·배포·main 병합은 실행하지 않았다.

현재 학습 기록·로그인·복습 기한·오늘 단어 목표·음원/Kenzo·Shizuka 설정·Data API 차단은 보존한다. 다음 요청 명세는 실행 명령이 아니다. 실제 변경 전에 최신 snapshot과 대조하고 구체적인 대상을 다시 승인받는다.

## 읽기 전용 기준선

2026-11-03 KST 조사다. DB는 TLS와 프로젝트를 확인하고 READ ONLY/REPEATABLE READ·statement8초/lock2초로 카탈로그를 조회했다. 사용자 학습 행 전체 스캔은 하지 않았다.

| 대상 | 확인 결과 |
| --- | --- |
| DB | o5p6q7r8s9t0, p6 미적용, activity marker/receipt 없음, 기존 lesson submission 있음 |
| 보안 | Data API는 pgrst_no_exposed_schemas, DDL guard 유지, anon/authenticated 기존 제출영수증 직접접근 없음 |
| 파티션 | review_events_2027_02의 2월1일~3월1일 UTC bound 존재 |
| API | harukoto-api-00252-6jq 100%, source26a81bce, revision252개, tag없음, timeout300초 |
| 자동 배포 | Deploy API workflow244540898 active, 웹 Git createDeployments enabled |
| 웹 | 보관123개·READY22개(기존production9/preview13)·alias57개, WAF active/draft/version 없음 |
| Preview 환경 | DATABASE_URL·DIRECT_URL 각각 동일한 설정 항목이production/preview/development에 함께 적용, branch전용아님. 값은복호화/보관하지않고key/target만조회 |
| 실제 주소 연결 | 현재 사용자 custom alias는 READY 기존운영배포를 가리킴. project.targets.production은 CANCELED 포인터이므로 현재 서비스 판정에 사용하지 않음 |

현재 DB lock waiter/준비 트랜잭션 없음은 실행 종료 증거가 아니다. DB source별 연결 식별도 충분하지 않아 순간 snapshot으로 drain을 증명하지 않는다. 전체 주소·식별자·settings snapshot은 private `ops/` 산출물에만 보존한다.

**현재 Vercel Preview는 격리 QA 환경으로 사용하지 않는다.** 운영과preview가 같은DB 설정 항목을 공유하므로 Preview 성공을 분리된 DB의 기능 검증으로 표현하지 않는다. 이번 기능/재시도/재실행 검증은 모두localhost 일회용PG·합성Auth/API·별도QA앱으로 수행했으며 live Preview에서 학습/제출하지 않았다. READY 숫자는 사용 가능한 안전한QA환경의 숫자가 아니다.

실제 온라인Preview 검증이 필요하면 비운영 DB와 인증/API 구성을 먼저 분리하는 별도 변경안을 승인받아야 한다. 구체안은 (1) production의현재값/역할을보존한채 원래공유항목에서preview target만분리, (2) preview전용DATABASE_URL/DIRECT_URL과분리된Supabase/Auth/API 설정추가, (3) prod Secret/결제/음원생성key가preview로전달되지않도록전체key/target조사, (4) 새preview를검토한소스로빌드한뒤접속대상identity확인이다. 실제자원ID·비용·필요key목록·값을보존한역변경payload가확정되기전에는적용하지않는다. shared항목전체를지워production을바꾸거나기존배포가자동으로새값을쓴다고가정하지않는다.

## 구체 변경 요청 1: 자동 배포 통제

GitHub는 기존 `deploy-api.yml` workflow를 전환 동안 일시 disable하고, 통합/활성화 안정화 뒤 원래 active로 복구하는 안이다. main 병합이 승인과 별개로 latest 배포를 유발하지 않게 해야 한다. 제안 명령은 다음과 같으며 실행하지 않았다.

```sh
gh workflow disable deploy-api.yml --repo WhiteMouseDev/HaruKoto
gh workflow enable deploy-api.yml --repo WhiteMouseDev/HaruKoto
```

웹 프로젝트에 제안하는 PATCH body는 아래 한 항목이다. 나머지 Git 옵션이 생기면 snapshot의 기존 키도 보존한다. API 서버가 이 변경을 받아들이는지는 아직 실행 검증하지 않았다.

```json
{"gitProviderOptions":{"createDeployments":"disabled"}}
```

원복 body는 조사 당시 `enabled`다. 이 설정은 해당 학습웹 프로젝트의 **production과preview Git 자동 배포를 함께 중지**하며, 관리자·랜딩 프로젝트 설정을 변경하지 않는다. 수동 build/promote는 별도 검토한다. 기존 alias·Secret/env·음성정책을 덮어쓰지 않는다. 정확한 project/query·원본값·freeze/restore body는 `operating-change-manifest-proposal-private.json` 및 별도 Git JSON2개에 보관했다.

## 구체 변경 요청 2: 현재 주소는 앱503, 이전 주소만 WAF403

권장안은 **이전 host 전체 deny WAF1규칙 + 현재 승인 host의 실제 legacy STOP ON 앱**이다. 현재 주소의 학습 저장은 검증한 한국어503/Retry-After로 중지하고 로그인·조회·음성·결제는 원래 처리한다. WAF의 global 학습차단2규칙은 현재 주소도403으로 바꾸고 path정규화 의존성을 더하므로 권장하지 않으며 비교 초안으로만 보존한다.

이전 immutable/branch/old-production host는 모든 path/method를 거절하므로 encoded path 우회에 의존하지 않는다. 단, **그 주소의 로그인·조회·정적 자산·음성·콜백도 막힌다.** OAuth/결제 callback·북마크·앱 base URL을 승인 host와 대조해야 하고 이 추가 영향은 별도 승인 대상이다. 현재 custom alias1개만 후보 allow이며 같은 배포의 추가 alias3개를 자동 허용하지 않는다. alias를 추가하려면 승인된 STOP ON 또는 새 writer 배포를 가리키는지 확인한다.

개인 전체 host를 넣은 `waf-recommended-one-rule-proposal-private.json`과 alias→deployment→source 분류를 private로 준비했다. [Hobby의 custom rule3개 한도](https://vercel.com/docs/plans/hobby) 안이다. 비교안의 등록 web writer20개·예약fence9개 대조도 보관하지만 이는 실제 WAF 실행 결과가 아니다.

[공식 CLI](https://github.com/vercel/vercel/tree/main/packages/cli/src/commands/firewall)는 draft 수정과 publish를 나누고 [SDK PUT](https://github.com/vercel/sdk/blob/main/src/funcs/securityPutFirewallConfig.ts)은 생성/덮어쓰기다. **PUT을 무해한 draft 생성으로 간주하지 않는다.** 현재 config가 없는 Hobby에서 최초 생성 상태와 게시 후 active:null/draft:null/versions:[] 완전 복원은 확인하지 못했다. 빈 rules의 active config는 NONE과 다르다. 검증되지 않은 DELETEactive/전체PUT을 원복 명령으로 사용하지 않는다.

WAF 최초 생성·게시·복원이 지원되는 절차를 확정하고 실제403의 기존 웹 pending/로그인/콜백 영향을 검증하기 전에는 게시하지 않는다. 별도 비운영 프로젝트가 필요하면 생성/비용/설정 변경안을 먼저 제시한다. 유료 전환이나 보호 해제는 자동 대안으로 수행하지 않는다.

## 구체 변경 요청 3: legacy STOP·실행 종료·p6·호환 OFF·ON

1. 구 운영 소스 #218의 STOP 두 상수만 ON인 소스를 별도로 검토·빌드하고 OFF/ON image digest와 웹 deployment를 고정한다. **p6를 읽는 #219/#216을 기존 DB용 STOP으로 사용하지 않는다.** 현재 후보는 소스까지이며 아직 배포 가능한 최종 컨테이너 digest·revision은 없다.
2. API는 기존 Secret 참조/env/음성 정책을 보존한 무트래픽 배포 뒤 명시 revision100%로 승격한다. latest 자동 승격에 의존하지 않는다. 웹은 승인된 현재 alias를 검증한 legacy STOP ON으로 이동하고 이전 host fence를 확인한다. 새 tag/alias가 발견되면 재검토한다.
3. 모든 신규 진입 차단이 실제 확인된 가장 늦은 시각을 barrierT로 삼는다. T이전 writer의 마지막 commit/rollback 이후 handler 종료 또는 관련 process 종료 증거를 완전하게 대조한다. DB active/waiting/idle-in-transaction·prepared transaction·관련 lock을 매번 새 read-only snapshot으로 함께 확인한다.
4. 모든 종료 조건이 충족된 경우에만 승인한 `alembic upgrade p6q7r8s9t0u1`을 적용한다. 검토한 lock2초/statement15초·원자적 실패 롤백을 유지한다. 기존 행 false의 activity_recorded와 빈 비공개 study_activity_receipts 및 관련 제약/인덱스/보안만 추가하며 백필·기한/목표/XP 재계산은 없다.
5. #217을 포함한 새 schema 호환 OFF API/web를 검증·승격하고 이전 host fence를 유지하며 새 writer만 재개한다. 실제 기존 로그인/학습/복습/음성/동일 세션·같은 제출 ID 복구를 확인한다.
6. 갱신한 #216의 최종 head와 별도 활성화 승인을 확인하고 두 인정 상수만 ON으로 전환한다. 첫 정답/오답·중복·응답유실·재실행·계정전환·KST경계와 다음 날 연속일/주간 그래프를 확인한다. 안정화 뒤 자동 배포를 snapshot으로 복구하되 구 host의 writer 재진입 차단은 유지한다.

[Cloud Run 공식 문서](https://docs.cloud.google.com/run/docs/configuring/request-timeout)에 따르면504 뒤에도 컨테이너는 처리를 계속할 수 있다. traffic100%·Retired·timeout300초 대기·CPU0·로그 부재·순간 DB무트랜잭션은 종료 증거가 아니다. 현재 구 코드는 모든 writer의 start/end/commit을 완전히 귀속할 계측이 없어 **현재 자료로 drain은 증명되지 않았다.** 관측 누락·보존기간·늦은 metric·공유역할 때문에 출처가 불명확하면 p6로 진행하지 않는다. 추가 계측이나 특정 runtime 종료가 필요하면 별도 변경·복구안을 먼저 보고한다. revision 삭제·DB 세션 강제종료는 이번 승인에 포함되지 않는다.

## 단계별 롤백과 보존

| 시점 | 복구 기준 |
| --- | --- |
| draft 게시 전 | 미게시 draft만 버리는 공식 절차와 기존 snapshot 비교. 설정 NONE 유지 확인 |
| WAF 게시 후 | 우리 규칙ID만 제거/비활성하는 기능적 복구와 원래 NONE 완전복귀를 구분. 지원 절차 확정 전 게시 NO-GO |
| p6 전 | 신규 진입을 통제한 채 같은 구 schema/잠금의 OFF artifact·원래 alias/traffic로 복구 |
| p6/새writer 후 | 새schema와 #217을 이해하는 호환 OFF artifact 사용. 구 writer로 복귀하지 않음 |
| 모바일 | 같은 저장 형식의 호환 앱으로 유지. 삭제·로그아웃·공유키/pending 삭제 없음 |

marker·receipt·학습 기록을 삭제하거나 Data API를 여는 동작은 없다. p6 downgrade는 사용한 marker/receipt가 있으면 거부되며 기본 롤백이 아니다. 설정 변경은 snapshot 전체 덮어쓰기 대신 승인된 우리 변경만 차등 복구한다.

## 다음 승인 전에 남은 항목

권장 one-rule의 첫 생성/게시/완전 복구 절차, 이전 host 전체차단의 callback/로그인 영향, legacy ON 최종 artifact digest, 구 runtime 실제 실행 종료 증거와 필요 계측안, 온라인Preview를사용하려면전용DB/Auth/API분리안을 확정해야 한다. 코드·CI가 성공했다는 이유로 이 조건을 완료로 표시하지 않는다. 현재 단계를 승인하면 즉시 운영을 바꾸는 것으로 해석하지 않는다.
