# 한 문항 학습일: STOP·완료 보호 통합 검증과 운영 적용 준비

## 범위와 승인 경계

2026-11-03 사용자는 #215·#217·#218 통합 검증, #216 활성화 검증본 갱신, 기존 웹 실패 7개의 원인 분류, 읽기 전용 운영 조사와 구체적인 적용·롤백안 준비를 승인했다. **main/운영 PR 병합, 운영 DB/권한/클라우드 설정 변경, 배포·활성화·기기 업데이트는 하지 않는다.** 기존 로그인·기록·복습 기한·오늘 단어 목표·음원·Data API 차단을 보존한다. 새 API·DDL·runtime env 계약이 필요하면 제안만 하고 먼저 보고한다.

기존 PR과 작업 공간을 보존하고 `codex/study-day-integration-qa`에서 #215+#217 head `b2a1a2b3`에 #218 head `0de610d2`를 통합한다. 구 운영 전용 #218의 o5 증거는 원래 브랜치에 유지하고, 이 브랜치는 새 p6 ORM/등록 경로를 실제로 검증한다. 활성화본은 최종 통합 OFF commit에서 별도로 준비한다.

## 구현·검증 순서

1. 도메인별로 STOP·완료 보호·폰트 및 CI 충돌을 해결한다. API/web 경로 inventory에 실제 새 활동 POST·영수증 GET을 분류하고 기본 STOP OFF를 유지한다.
2. o5 증거를 p6용 버전 assert로 대체하지 않는다. 새 p6 STOP 보존/재시도 테스트와 기존 필수 PostgreSQL·웹 완료31·STOP5suite gate를 함께 검증한다.
3. 웹 기존 gamification2·stats-components5 실패를 현재 구현/계약과 비교해 분류한다. 실제 동작 결함은 범위 내에서 수정·검증하고, 계약 변경이 필요하면 적용하지 않는다.
4. 모바일의 계정별 목표·학습일/주간 통계·재시도·재실행 복구를 폐기형 DB와 격리 API, 필요한 경우 시뮬레이터로 확인한다. 운영 인증/학습 API로 쓰기 검증하지 않는다.
5. 최종 OFF와 별도 ON 소스의 exact head에 lint/typecheck/contracts/build·필수 회귀·ON 동작을 검증한다. CI 결과는 head별로 구분하고 예전 성공을 재사용하지 않는다.
6. 운영 DB head/보안 상태와 배포/revision/alias/보호 설정을 읽기 전용으로 조사한다. 비밀/사용자 데이터·비공개 주소 목록은 저장소에 넣지 않는다. 실제 설정 JSON·대상 목록·복구 snapshot은 private 산출물로 준비하고 안전한 요약만 문서화한다.

## 운영 적용안에서 확정할 사항

- 자동 배포 freeze/복구 대상과 기존 설정 snapshot, legacy STOP ON/OFF 및 새 writer OFF/ON artifact 식별자.
- 구 revision/tag와 웹 immutable/branch/alias/team 접근의 우회 차단 규칙. app503과 WAF403의 클라이언트 차이는 별도 검증한다.
- 신규 진입 차단 후 기존 handler·DB transaction의 실제 종료 증거와 중단 기준. traffic100%·Retired·504·고정 sleep만으로 진행하지 않는다.
- p6 전에는 구 OFF, p6/새 writer 후에는 #217을 포함한 새 schema 호환 OFF로 복구한다. 기록/영수증 삭제·Data API 개방은 하지 않는다.

## 결과

통합 OFF의 로컬 코드·검증을 완료했다. 별도 source ON head, 시뮬레이터, 원격 CI, 운영 차단 JSON/실행 종료 증거안은 계속 준비하며 아래 결과와 구분한다. 실제 운영 적용 결과가 아니다.

| 항목 | 통합 OFF 격리 결과 |
| --- | --- |
| API 전체 | 1,547 passed / 기존 admin fixture13 skipped |
| 필수 PostgreSQL | 기존285 + 신규p6 STOP5 = 290개 모두 무스킵 통과 |
| STOP 집중 API | 정책/inventory201 + 실제p6 PG5 = 206개 통과 |
| 정적·계약 | Ruff325파일·mypy184source·OpenAPI107경로 유지·mobile61호출/5model·admin14호출/1enum 통과 |
| 웹 전체 | 486/486 통과 |
| 웹 완료·STOP 필수 | 완료31/31·STOP5suite173/173·보고서 guard 통과 |
| CI guard | font4·완료8·STOP4·PG10 통과. 전체 웹 회귀도 CI에 추가 |
| 관리자 | 실제 browser23/23·unit45pass/기존10todo·lint/typecheck 통과 |
| 모바일 | 신규실제Dio STOP4 포함1,068개·format603파일0변경·analyze0issue |
| compiled HTTP | recognitionOFF에서 STOP_OFF12개·STOP_ON19개. 차단11요청의 auth호출0 |
| 실제 웹 빌드 | pinned local font를 쓰는 nativeTurbopack OFF·ON·최종OFF 통과,248개참조·font200·Google외부참조0 |

소스의 두 STOP와 두 학습일 인정 플래그는 모두 OFF다. 별도 QA 프로세스에서 명시한 recognitionON을 sourceON head 검증으로 대신하지 않는다. 기존 o5 STOP 모듈은 #218에 유지하고 통합본은 실제 p6 marker/receipt·동시 잠금·동일ID 재시도·ACL/RLS/Data API 보존을 새로 검사한다. DDL/model/schema/OpenAPI/env 계약의 #217 이후 변경은 없다.

compiled 웹의 합성 로그인과 HTTP는 실제 Next/SDK를 사용했지만 운영 인증·DB 연결은 없다. 웹에는 FastAPI 소유 레슨 activity/receipt 라우트가 등록되지 않아 정책 허용 후404이며 이를 성공적인 API 영수증 조회로 표현하지 않는다. 모바일 provider 재생성4회귀와 실제 OS 재실행 검증도 구분한다. 비공개 결과는 `/private/tmp/harukoto-study-integration-20261103/`에 보관한다.

## 기존 웹 실패 7개 분류

제품 컴포넌트·업적 동작을 바꾸어 녹색으로 만들지 않았다. 테스트가 기존 변경을 따라가지 못한 사례로 확인했고 현재 계약의 값·범위·경계 검증으로 갱신했다.

| 기존 실패 | 기존 변경 근거 | 갱신한 검증 |
| --- | --- | --- |
| 모든 비special 업적의 숫자 threshold | `7c47c06f`의 가나Boolean event3개 | 숫자형은 양수, 가나/special event는 threshold없음 |
| 업적 총20개 | 같은 commit의 가나3개 추가 | 원래 비가나20개 + 정확한 가나ID3개 =23 |
| StudyTab 한자 category | `0cf20840`의 실제통계계약 반영 | 단어·문법·회화 존재, 지원하지 않는 한자 출력없음 |
| StudyTab today/옛정답률문구 | 같은 commit의 누적저장답안 요약 | (4+8)/(5+10)=80%, 서로다른 일별분모 (1+1)/(1+9)=20% |
| zero division | 사용하지 않는 today만0으로 바꾼 옛fixture | 실제history0에서0%, NaN/Infinity없음 |
| JLPT5단계 모두표시 | 같은 commit의 가짜완료/잠금카드 제거 | 현재N5/다음N4·무관단계없음, 가중숙련도30%·N1끝경계 추가 |
| 옛학습중 label | 같은 commit의 실제레벨설명/수량 표시 | 기초일본어·75/150개 표시, 미완료를완전마스터로표시하지않음 |

각 근거와 실제 UI를 비교한 상세 QA 기록도 비공개 `web-stale-regression-audit.md`에 보관한다. 제품 범위나 API 계약을 새로 바꾼 작업이 아니다.

## 읽기 전용 운영 조사: 2026-11-03

DB는 프로젝트·TLS hostname을 검증하고 READ ONLY/REPEATABLE READ, statement8초/lock2초 제한으로 카탈로그만 읽었다. 학습 행 전체 스캔이나 데이터 변경은 하지 않았다. 현재 head는 `o5p6q7r8s9t0`, p6 marker/receipt 없음, 기존 lesson submission 있음, Data API는 빈 스키마, DDL guard 유지다. 직접 클라이언트의 기존 제출 영수증 접근은 차단돼 있다. 현재 잠금 대기 없음은 전환 종료 증거가 아니다.

API는 `harukoto-api-00252-6jq` 100%·source26a81bce·revision252개·timeout300초, 자동 배포 workflow는active다. 웹은 페이지네이션을 끝까지 읽어 보관123개/READY22개/alias57개를 확인했다. 실제 사용자 custom alias는 기존26a81bce의 READY배포를 가리킨다. project.targets.production의 포인터와 다를 수 있으므로 이 필드만으로 현재 서비스를 결정하지 않는다. WAF active/draft/version목록은 비어 있고 Git createDeployments는enabled다. 사용자·비밀값·비공개 전체주소는 저장소에 넣지 않는다.

정확한 차단 JSON·호스트 목록·복구 snapshot과 실행 종료 증거안은 비공개 `ops/`에 준비했다. [운영 변경·복구 요청 명세](study-day-operating-change-proposal-2026-11-03.md)는 현재 앱503+구host전체deny1규칙을 권장하고 global WAF2규칙은 대안으로만 보존한다. 새 설정을 서버에 검증하거나 적용하지 않았다. 최초 WAF 생성/게시 후 원래 NONE 완전복원·구host콜백 영향·actual drain은 미확정이므로 운영 전환 NO-GO를 유지한다.

## 별도 ON·시뮬레이터와 첫 원격 CI

기존 #216 이력에 통합 OFF를 포함한 sourceON head `aefc9fef`도 독립 검증했다. API전체1,547pass/기존13skip·필수PG290 skip0, 웹전체486/필수완료31/STOP173·native빌드/실제HTTP16검사가 통과했다. 학습일 인정 소스True/true와 STOP소스False/false이며 전역featureOFF fixture로 바꾸지 않았다. 실제DB 성공은 API/mobile의 일회용PG 결과로만 보고하고 웹dummyDB500/404를 성공ACK로 해석하지 않는다.

별도 QA bundle·새 iOS26.5 시뮬레이터에서 첫 레슨오답 저장전503→동일ID 재시도, 서버commit후응답유실→실제OS재실행·같은activityId GET200/추가POST0, 단어1개오답저장→오늘1/20(5%)·주간단어1/XP0·연속1일, 목표30변경→1/30(3%), 두번째OS재실행후동일퀴즈1/8→이어하기2/8을 확인했다. 레슨출석은 단어목표를 부풀리지 않았고 기한/보호상태hash도 유지됐다. 추가STOP phase는 private QA runtime 주입으로 별도 구분해 최종 PR본문에 기록한다.

호스트 Xcode27.1은 원래iOS13 deployment target을 거부해 **임시QA 복사본/child env에만 target15 override**로 빌드했다. 원본platform·runtime설정/기존앱설치·계정은 바꾸지 않았다. 이 결과를 원래iOS13 지원검증이나 실물아이폰 결과로 표현하지 않는다.

최초 [OFF CI866](https://github.com/WhiteMouseDev/HaruKoto/actions/runs/41566541825)와 [ON CI867](https://github.com/WhiteMouseDev/HaruKoto/actions/runs/41566551801)는 웹/관리자/API/계약/schema가 성공했고 mobile의 신규4개만 실패했다(기존1064pass). 실제 AppHttpClient의 기존 compile-time API_BASE_URL이 없는 CI에서 Dio가 상대URL을 거부한 테스트 초기화 문제였다. 생성자를 새로 바꾸거나 production/env 계약을 추가하지 않고, 테스트 실행에 `https://mobile-fixture.invalid` 합성define을 명시했다. 새4개와 전체1,068개를 **환경파일·define-from-file 없이 해당값 하나로 재실행해 모두 통과**했다. 모든 해당HTTP는 in-memory adapter이며 외부서버로 보내지 않는다. Makefile/README/CI 테스트명령을 맞췄고 앱runtime은 그대로다. 실패를 skip하거나 검사수를 줄이지 않았으며 보완 head의 CI 결과는 PR본문에 별도 기록한다.
