# 운영 코드 호환 학습 저장 STOP: 구현·격리 검증·적용안

2026-11-03 사용자는 웹 완료 회귀 CI 보완과 별도 STOP PR 구현·격리 검증을 승인했다. 운영 적용 전 결과와 변경안을 먼저 보고하며, 운영 DB·설정·배포·병합은 이번 범위에 포함하지 않는다.

## 기준 코드와 호환 범위

읽기 전용 메타데이터로 운영 API `harukoto-api-00252-6jq` 100%의 소스와 운영 웹의 immutable production deployment 소스가 모두 `26a81bceda1c9c6df7240abbb63aff830a4da4e6`임을 확인했다. 별도 STOP 브랜치는 main `363b1661a4d61d483956c84a2ab2f98f8ceef918`에서 만들었다. 두 커밋 사이 `apps/api`, `apps/web`, `packages`의 diff가 비어 있어 실제 운영 서버·웹 코드와 같은 기준이다.

운영 DB는 이번에 연결하지 않았다. 운영 메타데이터 확인은 API revision·배포 커밋 읽기에 한정했다. schema 호환성은 **폐기형 로컬 DB에 o5까지 적용한 실제 구 스키마**로 검증한다. #215의 p6 모델/마이그레이션·새 사용자→세션 잠금·#217 완료 보완·운영 공용 폰트 자산은 이 PR에 포함하지 않는다. 관리자 E2E의 외부 의존성을 없애는 테스트 전용 폰트 fixture는 별도로 둔다. Prisma도 별도 로컬 의존성에서 구 스키마로 생성하고, 새 `activity_recorded`/`study_activity_receipts`가 없는 client인지 확인한다.

## STOP 동작과 소스 스위치

| 항목      | 구현                                                                                                                             |
| --------- | -------------------------------------------------------------------------------------------------------------------------------- |
| API       | `app/middleware/study_write_stop.py`의 순수 ASGI middleware, CORS 안쪽·라우터/인증/DB/AI 앞에서 판정                             |
| 웹        | `src/proxy.ts`의 첫 진입 판정, Supabase 세션 갱신·Prisma·라우트 앞에서 판정                                                      |
| 기본값    | API·웹 `STUDY_WRITES_PAUSED = False/false`. 요청 header/cookie/query/env로 바꾸지 못함                                           |
| 중지 응답 | HTTP503. API는 기존 `detail`, 웹은 기존 `error` 형식의 한국어 안내                                                               |
| 헤더      | `Retry-After: 60`, `Cache-Control: private, no-store`                                                                            |
| 활성화    | 별도 승인 뒤 두 소스 상수를 True/true로 바꾼 검토 커밋을 빌드·배포. 새 환경 변수/비밀 키/DB 변경 없음                            |
| 해제      | p6/새 writer 도입 전에는 같은 구 schema/잠금의 검증된 OFF artifact로 복귀 가능. 새 writer 도입 뒤에는 아래 단계별 롤백 기준 적용 |

중지 안내는 ‘학습 저장을 잠시 점검하고 있어요. 잠시 후 같은 기록으로 다시 시도해주세요.’다. 인증을 우회하는 기능은 추가하지 않는다. 중지된 경로는 요청 body도 처리하기 전에 거절하고, 허용 경로의 기존 인증은 그대로 실행한다. OPTIONS 사전 요청과 CORS 정책을 유지한다.

## 경로 분류

- 차단: 퀴즈 시작/smart-start/이번 오답 복습 시작/이어하기/답안/완료, 가나 progress/퀴즈 시작·답안·완료/스테이지 완료, 레슨 시작/두 제출 경로/향후 활동 POST, 회화 시작·메시지·종료·live-token/live-feedback·대화 삭제, 미션 보상, 목표/프로필/아바타/계정 변경·탈퇴.
- **조회처럼 보이는 writer:** 양쪽 `GET/HEAD /api/v1/missions/today`는 미션 생성과 자동 XP 지급 때문에 차단한다. API `GET/HEAD /api/v1/quiz/incomplete`는 오래된 세션을 완료 처리하므로 차단한다. 웹 counterpart는 조회 전용이어서 허용한다.
- 허용: 로그인/auth bootstrap·온보딩, 콘텐츠·통계·달력·프로필·제출 영수증 조회, 일반 음원/TTS/전사, 결제 callback·구독 작업, 독립적인 알림·단어장·푸시·캐릭터 즐겨찾기 metadata.
- 명시적 bootstrap 예외: 웹 가나 목록은 초기 스테이지 행을 만들 수 있고, auth는 사용자 생성, 음성은 캐시 저장, 결제는 구독/사용자 상태를 변경할 수 있다. STOP은 모든 DB 쓰기를 0으로 만드는 기능이 아니다. 학습·보상 writer의 신규 진입 차단이다.

전체 실제 route/method를 inventory 테스트로 분류한다. 신규 경로가 추가되면 검토 없이 통과하지 못하게 한다. HEAD의 GET 실행, trailing/double slash·인코딩·점 경로와 이미지 확장자 동적 ID도 검사한다. OFF인 경우 기존 요청 method/path/body를 바꾸지 않는다.

## 기존 클라이언트와 보존 경계

미션 조회만 중지돼도 웹·모바일 홈은 대시보드·프로필을 계속 표시한다. 미션 오류가 로그아웃·목표 초기화를 일으키지 않는다. 기존 모바일은 503에 기존 한국어 서버 오류 안내를 사용하며, 전용 점검 배너나 Retry-After를 따르는 모든 GET 재시도가 추가된 것은 아니다. 홈의 시작 버튼이 눌릴 수 있어도 실제 시작 요청은 서버에서 거절한다.

기존 모바일 레슨은 같은 제출 ID·답안·pending을 보존하고 저장 실패 뒤 재시도한다. 별도 provider 재생성에서도 같은 ID를 조회/재전송하는지 검사했다. 실제 OS 재실행·실기기 검증으로 표현하지 않는다.

새 STOP 웹 번들은 일반 퀴즈·가나의 점검 응답에서 다음 문제 이동/완료 후 강제 이동을 막고 같은 답안을 재시도하는 보완을 포함한다. 이미 열려 있는 **예전 JS 탭**은 새 처리가 소급 적용되지 않는다. 서버에 저장된 답안은 보존되지만, 아직 ACK가 없는 새 선택지가 브라우저 종료 뒤 복원된다고 보장하지 않는다. 운영 전 사용자 안내·기존 학습 세션 정리/새 번들 확인과 실제 클라이언트 재시도 검수가 필요하다. 기존 웹의 모든 특수 모드에 durable outbox를 추가하는 작업은 이번 범위가 아니다.

## CI 분리

#217에는 [완료 회귀 CI 보완](https://github.com/WhiteMouseDev/HaruKoto/pull/217)을 별도로 올렸다. 필수 31개와 관련 3파일 93개, 누락/skip/중복을 거부하는 검사기 8개를 실행한다. stacked 대상 브랜치도 CI가 실행되게 하되 API Deploy workflow는 바꾸지 않았다.

STOP PR의 CI는 이 구 운영 기반에서 자체 검사한다. API의 기존 필수 PostgreSQL 173개에 STOP 보존 회귀 2개를 더한 **175개**를 skip 없이 요구한다. 웹은 정책·실제 proxy 진입·일반 퀴즈·가나 응답·가나 완료 재시도의 5파일을 필수 실행하고, 각 suite의 누락·skip·실패를 보고서 검사로 거부한다. 이 PR은 #217의 새 완료 동작이나 p6를 검사하는 PR이 아니다.

## 검증 결과

| 검사                    | 결과와 한계                                                                                                                                                             |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| #217 원격 CI            | head `b2a1a2b3`, [CI 863 전체 성공](https://github.com/WhiteMouseDev/HaruKoto/actions/runs/41559448414). frontend 로그에서 93 passed·필수31개 skip0·검사기8개 통과 확인 |
| STOP API 전체           | 1,412 통과 / 기존 admin fixture skip13. 구 운영 기반에 STOP 단위/inventory199개·실제PG2개 추가                                                                          |
| 필수 PostgreSQL CI gate | 175개 모두 통과·skip0, gate 자체10개 통과                                                                                                                               |
| STOP 웹 필수 CI 5파일   | 172개 통과: 정책/inventory83·proxy/matcher83·실제UI6. 보고서 검사기4개 통과                                                                                             |
| STOP 웹 전체            | 385 통과 / 기존 실패7개: gamification2·stats-components5                                                                                                                |
| 정적·계약               | API Ruff315파일·mypy179source·기존OpenAPI105경로 동일, 모바일/관리자 계약 통과. 웹 lint·typecheck 통과                                                                  |
| 실제 compiled ON HTTP   | 로컬 production Next + 실제 Supabase SDK + 합성 저장 쿠키, 16개 확인. 로그인된 `/home`200, 저장10요청 모두 추가 인증 호출0·503, 허용 조회/TTS는 원래401·OPTIONS204      |
| 실제 ON/OFF 빌드        | 기존 Next16.1.6 기본Turbopack·Node24·각83페이지 통과. 구 Google loader에는 QA CSS/localhost WOFF2 fixture 사용, 운영 폰트 코드는 변경하지 않음                          |
| 기존 모바일 소비자      | baseline4파일31개 + 임시STOP3개 통과. 실제Dio/인증인터셉터, 같은 제출ID·답안의 provider 재시작/재시도, 목표503의 기존값/캐시 복원                                       |

실제 구 o5 DB에서 중지 대상 전체는 DB dependency를 열지 않았다. auth/user·세션/답안·일일 집계·미션·SRS·제출 영수증·음원 및 보안 메타데이터가 같았다. 허용된 기존 ensure-user·통계/프로필/달력·영수증 GET·기존 TTS 캐시 URL도 실제 DB로 확인했고, 같은 제출의 STOP503 뒤 OFF 재시도는 원래 영수증을 반환해 추가 기록이 없었다. 이 로그인 검증은 로컬 합성 claims이며 운영 인증·실제 음원 청취 검증은 아니다.

일반 API 도메인 검사는 test-only fixture에서 명시적으로 OFF로 고정하고, STOP 전용 사례가 ON/OFF를 직접 검증한다. 미래 승인된 ON artifact도 이 테스트를 재사용할 수 있도록 런타임 상수의 False를 테스트에 하드코딩하지 않았다. 커밋할 API·웹 소스의 **False/false 기본값**은 pytest/Vitest 밖에서 별도로 확인한다.

웹 UI는 반복 STOP 응답과 동일 답안 재전송, 다음 문항/가나 타이머 진행 중지, 같은 세션 완료 재시도, 화면 이탈 후 늦은 ACK·타이머 취소도 검사했다. compiled ON HTTP는 mocked proxy 함수만 호출한 결과가 아니다. 합성 인증 서버와 실제 SDK를 사용했고 STOP 요청에서 인증 호출이 늘지 않음을 확인했다. production DB·인증·결제에는 연결하지 않았다.

검증에서 production token/URL이나 `.env`를 테스트로 복사하지 않았다. QA 폰트 fixture 빌드 결과를 실제 Google 연결 안정성·운영 폰트 수정·성능 개선 증거로 표현하지 않는다. 소스 재검토에서 추가 P1/P2 finding은 없었으며, 예전 웹 탭·특수 모드·메모리 한계는 앞 절의 운영 전제로 남는다.

비공개 실행 자료는 `/private/tmp/harukoto-legacy-stop-20261103/`의 API 최종 로그/JUnit, `stop-web-results.json`, `web-full.log`, `web-qa/on-http-proof.json`과 ON/OFF 빌드 로그, `consumer/`에 보관한다. 실행한 폐기형 PostgreSQL·Next·합성 auth·폰트 서버는 모두 종료했다. 새 운영 DB/설정 변경이나 배포·기기 설치는 하지 않았다. STOP PR의 원격 CI 결과는 PR 생성 뒤 별도로 확인하며 로컬 결과로 대신하지 않는다.

## 최초 원격 CI와 테스트 환경 보완

#218의 [최초 CI 864](https://github.com/WhiteMouseDev/HaruKoto/actions/runs/41561416008)에서 frontend의 STOP172개·검사기4개·기본 전체 앱 빌드, backend·schema-drift·api-contract는 통과했다. 관리자 E2E dev 서버는 변경하지 않은 `next/font/google`의 일본어 loader 오류(`next/font/google queries have exactly one entry`, 내부 font 모듈 해석 실패)로 준비되지 못하고 timeout됐다. STOP 라우트나 관리자 테스트 assertion 실패로 분류하지 않는다.

관리자 브라우저 smoke는 앱 기능 검증에 집중하도록 Playwright의 **테스트 전용 launcher**에 기존 Next test mock hook과 localhost WOFF2 fixture를 넣는다. 제품 layout·폰트 로더·Next 버전·runtime env 계약은 유지한다. fixture는 OFL이 있는 공식 Latin font 원본이며 CJK typography 검증으로 설명하지 않는다. 일반 frontend 빌드는 여전히 실제 Google loader로 수행하므로 이를 font build 검증의 대체물로 사용하지 않는다. 무조건 재실행해 녹색 결과만 남기는 방식은 사용하지 않는다. 후속 head의 E2E·전체 CI는 따로 확인한다.

보완 뒤 실제 관리자 Playwright 전체 **23/23 통과(20.0초)**, 기존 캐시를 유지한 `CI=1` 서버 재시작 로그인 smoke **1/1 통과(4.1초)**를 확인했다. 관리자 단위 검사는 **45 passed / 기존 10 todo**, lint·typecheck·diff 검사는 통과했다. 테스트 실행으로 생성된 `next-env.d.ts` 변경은 복원했고 테스트 서버도 종료했다. 고정 응답 모듈·loopback URL로 재시작 시 임시 font endpoint가 캐시에 남는 문제도 제거했다. 로그는 `admin-e2e-local.log`, `admin-e2e-warm.log`에 보관한다.

## 적용 전 구체안: 아직 실행하지 않음

1. 현재 운영 소스·DB head·보안/기록 fingerprint·API revision/tag/웹 host 목록을 읽기 전용으로 다시 확인하고 복구 가능한 원래 artifact·설정 snapshot을 보존한다. 이번 소스 확인만으로 운영 DB의 현재 head를 단정하지 않는다.
2. STOP의 OFF/ON source artifact를 각각 빌드해 hash/digest를 고정한다. 새 요청을 막는 artifact와 원래 구 스키마 서비스로 돌아갈 OFF artifact를 구분한다. 로그인·조회·음성·callback과 거절 응답을 확인한다.
3. 별도 승인 뒤 API 자동 배포와 웹 production 자동 승격을 통제한다. API·웹의 검토된 **ON artifact만** 준비·승격한다. 기존 Cloud Run 환경/Secret/음성 정책은 보존하고, 별도 runtime env 키를 만들지 않는다.
4. 운영 도메인뿐 아니라 구 revision/tag·웹 immutable/branch/alias/팀 접근의 신규 학습 쓰기를 별도 차단한다. 정확한 대상 목록·WAF 설정 JSON·복구 snapshot은 설정 변경 전에 제시한다. 이 PR은 현재 서비스나 모든 과거 배포에 자동 적용되지 않는다.
5. API·웹 ON과 구 경로 차단을 모두 확인한 시점부터 기존 요청/DB 트랜잭션 종료 증거를 수집한다. 이미 실행 중인 handler를 STOP이 취소한다고 가정하지 않는다. traffic100%·Retired·504·고정 sleep만으로 판정하지 않는다. 실제 종료를 확인하지 못하면 p6로 넘어가지 않는다.
6. 그 뒤 승인된 p6·#217 포함 OFF writer 전환안을 적용한다. [통합 적용 순서](https://github.com/WhiteMouseDev/HaruKoto/blob/b2a1a2b3682fa60242a6190f5bb3a3f85f9b755f/docs/operations/plans/study-day-pr215-217-rollout-order-2026-11-03.md)를 따르며 이번에는 어느 단계도 실행하지 않는다.

### 이후 #215와 통합할 때 필요한 소스 작업

현재 STOP은 구 o5 모델/105경로를 검증한다. 이후 #215를 갱신할 때 middleware/proxy와 클라이언트 재시도 처리를 보존하고, 새 활동 POST 차단·GET 영수증 허용을 실제 등록 경로에 맞춰 재검토한다. 새 ORM으로 구 o5 검증을 그대로 실행하거나 버전 assert를 바꿔 통과시키지 않는다. 구 artifact의 o5 검증은 보존하고 새 p6 artifact의 보존/STOP 통합 회귀를 별도로 갱신한다. CI gate의 175개와 #217의 285개도 누락 없이 합치는 작업이 필요하다. 이 검토/새 CI가 끝나기 전에 main 새 writer를 배포하지 않는다.

## 롤백

- **p6/새 writer 도입 전:** 신규 진입을 다시 통제한 뒤, 같은 구 스키마·잠금 순서의 OFF artifact로 되돌린다. 기존 데이터·로컬 pending·로그인은 삭제하지 않는다. 보존한 원래 라우팅/배포 설정으로 복구한다.
- **p6/새 writer 도입 후:** STOP을 해제한 구 writer로 돌아가지 않는다. #217 수정과 새 schema를 이해하는 OFF API·웹 artifact를 사용한다. 새 한 문항 인정만 중지하고 마커·영수증·학습 기록을 유지한다.
- 차단 설정을 되돌릴 때 새/구 writer가 동시에 진입하지 않게 한다. Data API를 다시 열거나 owner 계정의 비밀번호/권한 변경으로 선택적 차단을 대신하지 않는다.
- STOP UI 문제는 기존 저장 형식을 이해하는 수정 번들/호환 앱으로 보완한다. 앱 삭제·로그아웃·SharedPreferences 삭제·미완료 세션 삭제를 복구 수단으로 사용하지 않는다.

이번 PR은 운영 적용 완료 기록이 아니다. 코드의 기본값은 OFF이며 ON artifact와 운영 DB/설정 변경은 결과 보고 후 별도 승인 대상이다.
