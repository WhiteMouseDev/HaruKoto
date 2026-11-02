# 한 문항 학습일: 폰트 빌드 복구와 운영 전환 구체안

## 승인 경계

2026-11-02 사용자는 활성화 draft의 폰트 빌드 수정과 PR #215·#216의 운영 적용안 구체화를 요청했다. 이번에는 소스·정적 폰트 자산·검증·문서를 수정하며 **DB·운영 설정·배포/병합은 변경하지 않는다.** 기존 로그인·기록·기한·오늘 목표·음원·Data API 차단을 유지한다. 새 production dependency나 환경 변수 계약을 추가하지 않는다.

## 수정 전 선택

현재 Next 16.1.6의 Google font loader는 Google의 확장자 없는 `/l/font?kit=...&skey=...` 응답을 안전하게 처리하지 못한다. 공식 이슈 [#99114](https://github.com/vercel/next.js/issues/99114)와 수정 [#100158](https://github.com/vercel/next.js/pull/100158)의 실패 형태가 실제 활성화 draft 로그와 일치한다. webpack 전환이나 성공할 때까지 재빌드는 결함 제거가 아니다.

같은 원인이 웹·관리자·랜딩에 있으므로 기존 Noto Sans KR/JP를 공식 소스의 동일 WOFF2 바이트로 고정해 세 앱에서 공용 정적 CSS를 사용한다. `assets/fonts/`에 한 번만 저장하고 npm 패키지를 신설하지 않는다. 원래 Unicode 분할·400–700 굵기·swap·Arial 보정·CSS 변수는 보존한다. 큰 단일 폰트를 강제 다운로드하거나 모든 CJK 분할을 preload하지 않는다. 라이선스·출처·SHA-256을 함께 기록한다.

## 작업과 완료 기준

1. 공식 Google CSS/WOFF2와 OFL을 내려받아 성공 빌드의 248개 원본 바이트와 비교한다.
2. root가 공용 자산·무결성 검사를 소유하고 web-agent가 세 앱의 font 소비자만 수정한다.
3. 외부 Google 폰트 호스트를 차단한 clean 기본 Turbopack 빌드, 영향 앱의 정적/회귀 검사, 실제 브라우저의 한·일 문자/굵기·요청 크기를 확인한다.
4. 운영 구성은 읽기 전용으로 조사하고 실제 쓰기 통제·구 writer 종료·마이그레이션·OFF/ON·보존 롤백안을 아래에 갱신한다. 제안한 설정 변경은 별도 승인을 받는다.

## 폰트 수정 검증 결과

- 공식 원본 248/248개가 이전 성공 빌드의 WOFF2와 바이트 단위로 같다. KR 124개 3,506,124B, JP 124개 5,470,704B다. 전체 저장소 자산은 약 8.56MiB이며 모든 파일을 매 방문마다 내려받는 구성이 아니다.
- 원본 Unicode 범위와 변수 폰트 축을 유지했다. 기존 한글/가나/한자와 `𠮷`·`髙`·`﨑` 표본을 검사했다. 기존 폰트에 없는 분해형 한글 자모까지 새로 지원했다고 주장하지 않는다.
- Google 호스트 두 곳의 차단을 먼저 403으로 확인한 deny proxy를 빌드 프로세스에만 적용하고, 비어 있는 `.next`에서 **기본 Turbopack 웹·관리자·랜딩 빌드 모두 통과**했다. font mock·webpack 전환·새 의존성·새 환경 변수 계약은 사용하지 않았다.
- 세 앱의 lint/typecheck가 통과했다. 웹 전체 270개 통과/기준 HEAD의 동일한 기존 실패 7개, 관리자 45개 통과/기존 todo 10개를 구분했다. 원래 코드의 보상/통계 실패를 폰트 수정 결과로 숨기지 않는다.
- 세 앱의 실제 빌드 HTTP에서 웹 248/관리자 124/랜딩 248개 폰트를 읽어 모든 SHA와 immutable cache를 확인했다. CSS에는 외부 폰트 URL이 없다. 이는 자산 전수 조회이며 실제 방문자가 전부 다운로드했다는 측정이 아니다.
- CI에는 248개 자산·원본 글자 범위·출처/라이선스·로컬 import를 확인하는 무결성 검사와 누락·변조·Google loader 재도입을 거부하는 회귀 4개를 추가했다. `assets/fonts/**` 변경도 관련 앱 검사를 실행한다.
- 로컬 프로덕션 웹/관리자 로그인·랜딩과 실제 빌드 CSS를 쓰는 별도 문자 표본을 브라우저로 확인했다. 네 굵기·한글·가나·희귀 한자가 렌더되고 로드 상태가 loaded이며 웹/관리자/표본의 console error는 없었다. [실제 문자 표본](../../blog/assets/2026-11-02-answer-day/pinned-font-specimen.png)을 남겼다. 이전 Latin-only preload는 제거했으며 CLS/LCP 개선률이나 모든 네트워크 조건의 성능 동일성을 측정했다고 주장하지 않는다. ON draft는 동일 폰트 수정 기반으로 다시 준비하고 그 head의 Preview를 별도로 확인한다. OFF 성공을 ON 빌드 성공으로 대신하지 않는다.

## 운영 읽기 전용 조사 결과

2026-11-02 약 17:57 KST 기준이다. 비밀 값은 메모리에서만 기존 연결 인증에 사용했다. DB 인증서·호스트를 검증하고 `READ ONLY / REPEATABLE READ`, 문장 8초·잠금 2초 제한으로 메타데이터만 읽었다. 학습 행·설정·권한·데이터는 변경하지 않았다.

| 대상              | 확인한 현재 상태                                                                                                          | 적용안의 의미                                                                                                  |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| 운영 API          | 프로젝트 `harukoto`, `asia-northeast3`, `harukoto-api`, 활성 revision `00252-6jq`, 소스 `26a81bce`, latest 100%, tag 없음 | 새 코드를 올리기 전에 현재 writer의 신규 진입과 남은 실행을 통제해야 함                                        |
| API 실행          | HTTP timeout 300초, 동시성 80, min1/max10, 공개 invocation                                                                | 300초/504는 컨테이너 종료 증거가 아님. IAM 전체 차단으로 로그인·조회까지 막는 안은 채택하지 않음               |
| API 보관 revision | 252개 중 하나 Active, 251개 Retired                                                                                       | Retired만으로 이미 실행 중인 handler 종료를 단정하지 않음                                                      |
| 웹                | 같은 `26a81bce` 운영 코드. 전체 페이지를 조회한 보관 deployment 114개 중 READY 16개(운영 9/preview 7), alias 55개         | 운영 custom domain만 이동하면 immutable/branch/authorized team 접근이 남음                                     |
| 웹 실행/보호      | READY 16개 함수의 max duration 모두 300초. `all_except_custom_domains` 보호, 활성 WAF 구성 없음                           | 기존 보호만으로 구 writer 퇴역을 보장하지 않음. 아래 쓰기 규칙은 새 제안이지 기존 설정이 아님                  |
| DB                | head `o5p6q7r8s9t0`; 새 `activity_recorded`·`study_activity_receipts` 없음; 기존 제출 영수증 있음                         | p6 미적용. 새 ORM은 OFF여도 p6 전 배포 금지                                                                    |
| DB 역할           | API의 실제 연결은 owner/BYPASSRLS인 `postgres`; 별도 앱 전용 writer login 없음                                            | postgres NOLOGIN/REVOKE/비밀번호 변경을 선택적 쓰기 중지로 쓰지 않음. 웹 연결 역할은 별도 복호화 확인하지 않음 |
| 기존 보안         | RLS·기존 service-role 권한 구분·비공개 제출 영수증 권한·빈 PostgREST schema·DDL guard 유지                                | Data API를 열거나 기존 권한을 재정규화하지 않음. 이번에는 Data API HTTP 응답을 별도 호출하지 않음              |
| 예약 작업         | 매일 09:00 KST 카탈로그 검사 1개, 학습일 writer 예약 없음. 웹 cron은 알림/구독 갱신                                       | 읽기 전용 파티션 검사는 계속 유지. 결제 callback을 학습 쓰기 차단에 섞지 않음                                  |

그 순간 다른 postgres 트랜잭션·충돌 잠금·prepared transaction이 없었다. **이 스냅샷은 drain 증거가 아니다.** 외부 AI를 기다리는 handler가 나중에 쓸 수 있고, 기존 DB 연결에는 revision/deployment 식별자가 없어 API와 웹의 소유자를 정확히 귀속할 수 없다. 전체 deployment ID/URL, 비공개 연결/원본 로그는 저장소에 넣지 않고 로컬 조사 산출물로 보존한다.

## 별도 승인이 필요한 구체 운영안

### 0. 자동 전환부터 통제한다

현재 `Deploy API`는 API 소스가 바뀐 main push를 CI/마이그레이션 승인과 독립적으로 자동 배포한다. 서비스는 latest에 100%를 보내므로 **#215부터 병합하면 STOP 통제가 풀리거나 미적용 컬럼을 읽을 수 있다.** 승인 전에 어느 PR도 병합하지 않는다.

향후 승인 범위에는 `deploy-api.yml` 자동 실행의 일시 비활성화와 복구, Vercel production 자동 배포/승격의 보류, 검토한 이미지 digest·commit별 수동 무트래픽 배포/승격을 포함한다. 제안 명령은 `gh workflow disable deploy-api.yml --repo WhiteMouseDev/HaruKoto`이며 이번에는 실행하지 않았다. Vercel은 정확한 현재 프로젝트 Git 설정을 다시 확인해 main 자동 배포 중지와 수동 Preview는 구분한다. 검증 없이 기존 설정 전체를 덮어쓰지 않는다.

### 1. 구 코드와 호환되는 학습 저장 STOP bridge를 먼저 준비한다

새 bridge는 **현재 운영 코드/스키마/잠금 순서** 기반의 별도 작은 PR로 제안한다. p6 모델이나 새 사용자→세션 잠금 코드를 섞지 않는다. 임시 소스 플래그로 학습 저장 진입을 DB/외부 AI 호출 전에 거절하고 `503`, `Retry-After`, `private, no-store`를 반환하는 안이다. 새 runtime 환경 변수를 신설한 구현은 아직 없다. 이 HTTP 동작·라우트 범위와 회귀 검증도 별도 승인 후 구현한다.

구체 대상은 퀴즈 시작/smart-start/이번 오답 복습 시작/이어하기/답안/완료, 가나 progress·퀴즈 시작/답안/완료·단계 완료, 레슨 시작/제출·신규 활동 POST, 회화 시작/메시지/종료·live-token/live-feedback이다. **시작도 기존 세션 자동 완료와 XP를 실행하므로 막아야 한다.** 최종 bridge 검토에서는 mission claim·목표/계정 수정 등 사용자 보상/행 잠금 writer를 함께 분류해 테스트 목록을 확정한다.

인증/로그인, 콘텐츠·통계·달력·제출/활동 영수증 GET, 일반 음원 재생, 결제 callback은 허용한다. 모든 POST를 일괄 차단하는 방식은 사용하지 않는다. 중단 중 사용자는 학습 저장/시작에 일시 중지 안내를 보며 기존 로컬 답안·pending·세션을 지우지 않는다. 로그인과 저장 조회는 계속 사용할 수 있어야 한다.

### 2. 구 배포 URL 전체의 새 쓰기 진입을 막는다

Cloud Run은 검토한 legacy STOP bridge로 명시적으로 라우팅하고 현재 및 다시 조사한 tag/이전 revision 진입을 막는다. 웹은 production alias를 gated compatible deployment로 이동시키는 것 외에 **16개 READY 보관 deployment/모든 alias/팀 사용자 접근**까지 막을 project-wide method/path 규칙을 제안한다. 재조사 때 새 deployment가 있으면 목록에 추가한다.

Vercel WAF 거부는 보통 403이므로 기존 앱의 저장 재시도/안내가 유지되는지 별도 검증이 필요하다. 실제 production 앱 gate의 503과 같다고 설명하지 않는다. 차단 해제 후에도 구 immutable/branch hostname의 학습 쓰기는 계속 거부하거나, 명시적 승인으로 구 배포를 퇴역시켜야 한다. 팀 인증이나 alias 이동만으로 완료했다고 하지 않는다. 정확한 rule JSON·대상 host 목록·복구 스냅샷은 변경 전에 검토한다. 현재 활성 WAF rule은 없으며 이번에 생성하지 않았다.

### 3. 실제 실행 종료와 DB 상태를 함께 확인한다

- Cloud Run: 현재 `00252-6jq` 및 실제 쓰기를 시작할 수 있는 이전 runtime이 더 실행되지 않음을 확인한다. 필요한 revision 삭제/종료는 **별도 명시적 승인 대상**이다. 작업 완료·실제 종료/instance 증거·이후 DB 상태를 묶어 남긴다. 없는 metric series를 0으로 간주하거나 단순 Retired/100%/504/고정 sleep을 증거로 쓰지 않는다. 기존 관측으로 증명할 수 없으면 중단하고 연결 식별/실행 중 쓰기 계측 또는 별도 자격증명 fence 설계안을 먼저 제시한다.
- Vercel: 새 진입 차단, 마지막 수락된 invocation 시각과 종료 기록, 전수 확인한 각 함수 300초 실행 한도, 이후 DB 트랜잭션/잠금 검사를 함께 사용한다. 실제 최대 실행 한도에 근거한 종료 상한과 관측이지 ‘5분 잤으니 안전’은 아니다. 이 증거를 얻지 못하면 진행하지 않는다.
- DB: 이전 writer의 active/waiting/idle-in-transaction·충돌 잠금·prepared transaction이 없어야 한다. 공유 postgres 역할 때문에 DB만으로 출처를 확정할 수 없으므로 앞의 runtime 증거를 대체하지 않는다.

Cloud Monitoring의 instance 표본은 60초 주기와 최대 120초 노출 지연이 있어 최신성을 확인해야 한다. 학습 저장 중지는 종료 확인과 검증 시간에 따라 달라지며 무중단이나 고정 분 수를 약속하지 않는다. 초기 admission fence를 통과하지 않은 구 writer에 advisory lock만 추가해도 이 전제는 해결되지 않는다.

### 4. p6 → 호환 OFF → 검증 → ON 순서로 적용한다

모든 조건을 만족한 뒤 검토한 p6를 lock 2초/statement 15초 제한으로 적용한다. 새 일별 불리언 1개와 비공개 영수증 테이블 1개를 추가하고 이전 행은 false, 영수증은 비어 있어야 한다. 기존 학습·목표·XP·기한·음원·ACL/RLS·service-role 구분·Data API/DDL guard의 보존 fingerprint를 전후 비교한다. 데이터 백필·기한 재계산·권한 변경은 없다.

쓰기 통제를 유지한 채 검토한 OFF API·웹 artifact를 무트래픽 배포하고, 준비/검증을 거쳐 명시적으로 승격한다. 이전 writer가 새로 시작하지 못하는 조건을 유지한 상태에서 **새 OFF writer만** 통제 해제를 검토한다. OFF는 p6를 이해하고 기록을 읽되 새 한 문항 인정은 켜지 않는다.

이후 별도 승인한 #216으로 API·웹 플래그를 함께 활성화한다. 시험 계정의 첫 오답·정답·재시도·응답 유실·완전 재실행, 오늘 목표 1/20·주간 단어 1개·레슨 위치/퀴즈 동일 세션, 로그인/음성/기존 기록·복습 기한을 확인한다. 과거 날짜를 소급 인정하지 않는다. 차단 규칙·자동 배포 복구는 **구 host 재진입 차단을 남긴 채** 확인 후 수행한다.

## 실패·복구 기준

p6 전 bridge/종료 증거 단계에서 실패하면 새 잠금 코드를 배포하지 않고 원래 schema/잠금 순서의 서비스로 복귀하는 통제 해제안을 사용한다. p6/새 writer 도입 뒤에는 새 schema와 영수증을 이해하는 **OFF API·웹 artifact**로 새 인정만 중지한다. 이미 기록된 마커·영수증·연속일·학습 기록은 남긴다. 스키마를 강제로 삭제하거나 구 writer를 섞거나 Data API를 다시 열지 않는다.

STOP bridge, 자동 배포 freeze, 정확한 WAF/host 규칙, runtime 종료/삭제, p6, OFF 승격, ON, 통제/배포 복구는 이번 미적용 제안이다. 소스상 폰트 수정과 운영 DB/설정 변경 승인을 구분한다. 운영 직전에는 DB head·현재 배포·대상 목록을 다시 읽어 이 스냅샷과 비교한다.

## 근거

- [Cloud Run request timeout](https://docs.cloud.google.com/run/docs/configuring/request-timeout): 요청 시간 초과와 container 종료는 다르다.
- [Cloud Run container contract](https://docs.cloud.google.com/run/docs/container-contract), [revision 관리](https://docs.cloud.google.com/run/docs/managing/revisions): 종료와 revision 제약을 따로 확인한다.
- [Vercel function duration](https://vercel.com/docs/functions/configuring-functions/duration), [custom WAF rules](https://vercel.com/docs/vercel-firewall/vercel-waf/custom-rules), [deployment protection](https://vercel.com/docs/deployment-protection): 실행 한도·진입 차단·인증 보호의 서로 다른 의미를 따른다.

운영 적용 완료 문서가 아니다. 실제 private 메타데이터 산출물은 `/private/tmp/harukoto-*metadata-20261102.json`에 보존하고 토큰·DSN·전체 학습 행·비공개 배포 URL은 이 문서나 블로그에 넣지 않는다.
