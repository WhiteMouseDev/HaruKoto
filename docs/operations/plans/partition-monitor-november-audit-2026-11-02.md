# 11월 월 전환 후 파티션·오류 읽기 전용 점검

## 범위와 실행 상태

2026년 11월 2일 사용자가 PR #210 병합, 11월 월 전환 후 파티션 자동 점검·Sentry 재발 여부의 읽기 전용 확인, 레슨 제출 중복 반영 방지의 설계안 준비를 승인했다. 실제 API·DB·권한·운영 설정 변경은 승인 범위가 아니다.

PR #210은 `2026-11-02T00:59:22Z`(09:59:22 KST)에 squash `ccb9e8e6610b0d3c7f9e2dfa94dccea41ead9e3e`로 병합했다. [병합 CI](https://github.com/WhiteMouseDev/HaruKoto/actions/runs/41370069479)는 성공했다. 문서 세 개만 바뀌어 앱/서버 검사는 경로 조건으로 생략됐으며 API 배포는 발생하지 않았다. 이 문서 병합을 새 앱·서버 테스트 실행이나 재배포로 표현하지 않는다.

운영 파티션 검사는 09:58~10:00 KST에 완료했다. Sentry 원본 UI 재발 확인도 10:35~10:37 KST에 완료했다. 자동 점검의 전송 수락과 실제 오류 목록·이메일 수신은 구분한다.

## 자연 실행 연결 확인

각 날짜의 Scheduler dispatch·전용 실행 주체·Cloud Run Job 결과·실제 검사 결과·Sentry 완료 전달 수락을 연결했다. 이번 감사가 Job을 강제 실행하거나 새 check-in을 보내지 않았다.

| 날짜(KST) | 실제 작업 완료(KST) | 확인 결과                                                                 |
| --------- | ------------------- | ------------------------------------------------------------------------- |
| 10월 31일 | 09:00:21            | Scheduler HTTP 200 → Job 성공·exit 0 → 카탈로그 OK → Sentry `ok/accepted` |
| 11월 1일  | 09:00:32            | 동일하게 모두 정상. 실제 월 전환 뒤 자연 실행                             |
| 11월 2일  | 09:00:18            | 동일하게 모두 정상                                                        |

실제 Job은 `harukoto-partition-check`, Scheduler는 `harukoto-partition-check-daily`다. 실행 호출자는 전용 Scheduler 계정으로 확인했다. 기존 `ENABLED / 0 9 * * * / Asia/Seoul`, 고정 이미지·secret 버전·runtime·Job 전체 spec과 Scheduler의 지속 설정은 10월 30일 기준과 동일하다. Job invoker는 전용 Scheduler 한 계정이며 기본 gcloud 계정도 바꾸지 않았다.

`ok/accepted`는 자연 실행 wrapper가 Sentry 전송 수락을 확인한 증거다. 이번에 새 장애·미실행·복구를 만들어 이메일을 수신했다는 뜻이 아니다. 실제 알림 수신 검증은 [10월 21일 운영 적용 기록](partition-monitor-deployment-2026-10-21.md)의 별도 결과다.

## 실제 카탈로그·보안과 다음 기한

전용 최소 권한 `partition_monitor_catalog`로 TLS 인증서·호스트 이름을 검증하고 UTC·READ ONLY·repeatable read transaction에서 조회했다. 학습 테이블의 행은 읽지 않았다.

| 평가                            | 실제 현재 카탈로그를 검사한 결과                                            |
| ------------------------------- | --------------------------------------------------------------------------- |
| 11월 2일 현재                   | `OK`, 파티션 12개, 2027년 2월 포함                                          |
| 연속 커버리지 끝                | exclusive `2027-03-01T00:00:00Z` — 3월 데이터는 포함하지 않음               |
| 10월 30일 보완 후 카탈로그 대조 | JSON 전체 동일, 기존 구조·보안 변경 없음                                    |
| 12월 1일 기준 사전 평가         | `ADVISORY`, `FUTURE_MONTH_MISSING: 2027-03`, 요구 끝 `2027-04-01T00:00:00Z` |

현재 정책은 UTC 현재 월과 다음 3개월을 요구한다. 따라서 다음 보완 대상은 **2027년 3월 파티션**이며 **2026년 12월 1일 09:00 KST 점검 전** 준비가 필요하다. 사전 평가는 현재 카탈로그에 미래 기준일을 대입한 것으로 미래 상태 예측·DDL 실행이 아니다. 3월 생성 마이그레이션은 이번에 작성하거나 적용하지 않았다.

전용 역할의 애플리케이션 테이블·열·시퀀스·루틴 유효 권한은 0이다. 기존 RLS·권한·DDL guard·빈 PostgREST 노출 스키마 검사도 통과했다. 별도의 본문 없는 익명 Data API HEAD 한 번은 404였다. 사용자 토큰은 읽거나 갱신하지 않았으므로 이번 검사에서 인증 조합 전체를 다시 확인했다고 주장하지 않는다. 플랫폼 Data API 토글 자체는 SQL 카탈로그만으로 검증할 수 없다는 경계도 유지한다.

기존 임시 CA 경로가 없어 최초 로컬 guard가 중단됐지만 DB 연결·설정 변경은 없었다. 기존 Secret Manager의 공개 CA 버전 1을 읽고 기존 지문과 같음을 확인한 뒤 검사를 완료했다. 새 secret이나 권한을 만들지 않았다.

## Sentry 오류 재발 확인

확인 대상은 WhiteMouseDev / `harukoto-api`다. 원래 `offset-naive`·`offset-aware` 날짜 비교 오류와 최근 배포 이후 오류를 구분해 확인한다. 당시 수정은 #177과 이후 미완료 조회·이어하기 회귀 기록에 연결된다.

연결 가능한 Sentry 전용 플러그인을 찾지 못해 공식 웹 화면을 사용했다. 사용자의 재요청대로 로그인 창을 다시 열었으나, 기존 Chrome 앱 전체 읽기는 무관한 사적 창 노출 위험으로 자동 승인 검토가 거절했다. 대신 Sentry 전용 브라우저 탭을 만들고 사용자가 직접 로그인한 뒤 그 탭만 읽었다. Google 인증 화면·쿠키·토큰을 추출하지 않았고 Chrome의 Apple Events JavaScript 설정도 변경하지 않았다.

조회 조건은 `project:harukoto-api`, 최근 30일, 모든 환경, Last Seen 내림차순이다. `is:unresolved`를 제거해 resolved/ongoing도 포함했으며, 페이지는 1–6 of 6이고 다음 페이지가 없었다. 다음은 직접 확인한 결과다. 건수는 해당 30일 범위의 누적 건수이며 11월 재발 건수로 해석하지 않는다.

| 이슈                                                                                                   | 구간 건수 | 마지막 발생(KST)   | 직접 관찰                                       |
| ------------------------------------------------------------------------------------------------------ | --------- | ------------------ | ----------------------------------------------- |
| [HARUKOTO-API-1V](https://whitemousedev.sentry.io/issues/7778425690/) 날짜 비교 TypeError              | 58        | 10월 13일 17:45:56 | Ongoing 표시는 남아 있지만 이후 새 이벤트 없음  |
| [HARUKOTO-API-1X](https://whitemousedev.sentry.io/issues/7812508767/) 가나 진도 `updated_at`           | 9         | 10월 26일 16:28:33 | 미해결 과거 이슈. 이후 새 이벤트 없음           |
| [HARUKOTO-API-1Y](https://whitemousedev.sentry.io/issues/7812509611/) 가나 답안 `updated_at`           | 5         | 10월 26일 16:30:12 | 미해결 과거 이슈. 이후 새 이벤트 없음           |
| [HARUKOTO-API-1Z](https://whitemousedev.sentry.io/issues/7812511133/) 가나 단계 완료 `updated_at`      | 1         | 10월 26일 16:30:14 | 미해결 과거 이슈. 목록 중 가장 최근 발생        |
| [HARUKOTO-API-1W](https://whitemousedev.sentry.io/issues/7803596946/) 파티션 rehearsal missed check-in | 23        | 10월 21일 11:22:00 | Resolved. 실운영 자연 실행 장애로 해석하지 않음 |
| [HARUKOTO-API-1T](https://whitemousedev.sentry.io/issues/7700270253/) 퀴즈 답안 DBAPIError             | 10        | 10월 7일 16:13:58  | Ongoing 과거 이슈. 이후 새 이벤트 없음          |

원래 날짜 비교 오류는 최초 `2026-10-07T09:08:36.441Z`, 마지막 `2026-10-13T08:45:56Z`였고 누적 58건이다. 상세에서 production release `harukoto-api-00234-dr9`, `GET /api/v1/quiz/incomplete`, `app/services/quiz_session_query.py:57`의 `session.started_at < cutoff` 비교와 `app/routers/quiz.py:120` 호출을 확인했다. 오래된 이벤트를 현재 release 오류로 혼동하지 않는다.

**이 조회 범위에서 11월 1일 00:00 KST 이후 점검 시점까지 새 이벤트와 날짜 비교 오류 재발은 0건으로 확인했다.** 이는 Sentry가 수집해 표시한 이벤트의 결과이며, 모든 요청의 무오류·알림 이메일 신규 수신을 보장하는 판정은 아니다. 기존 미해결 가나 이슈의 현재 코드 수정 여부·Resolve 처리는 별도 후속 범위로 남기고 이번 읽기 전용 점검에서 상태를 바꾸지 않았다. 파티션 wrapper의 `accepted`만으로 재발이 없다고 판정한 것이 아니다.

보조 증거로 Cloud Run API 로그를 읽기 전용 조회했다. **2026년 10월 30일 17:53:23~11월 2일 10:24:06 KST** 구간에서 `harukoto-api`의 ERROR 이상 또는 HTTP 5xx는 0건, `offset-naive`/`offset-aware` 문자열 로그도 0건이었다. 각각 최대 500건 제한이며 반환 0건이므로 상한으로 잘린 결과는 아니다. **이 결과를 Sentry 원본 이벤트·이슈 상태의 직접 검증으로 대체하지 않는다.**

API는 `harukoto-api-00251-cwz`·트래픽 100%다. 실제 이미지 digest·Service 전체 설정·Revision·환경/Secret 바인딩은 10월 30일 기준과 동일했다. 남성·여성 음성 참조는 version 1, 모델 참조는 기존 latest이며 실제 Secret 값이나 최신 버전 값까지 읽은 검사는 아니다. 추가 보조 점검에서도 사용자 토큰·학습 행 조회·refresh·운영 변경·Sentry 전송은 0이다. 증거는 같은 비공개 디렉터리의 `api-followup/api-observability-safe.json`에 남겼다.

## 변경·보존 경계

- 학습 행 조회 0, DB 쓰기·DDL·백필 0.
- 클라우드 설정 변경·Job 강제 실행 0.
- 이번 감사가 보낸 Sentry check-in·장애·알림·이메일 0.
- 기존 로그인 토큰 읽기·갱신·로그아웃·시뮬레이터 설치/조작 0.
- 기존 학습 기록·복습 기한·음원 캐시·Data API 설정을 변경하는 작업 0. 학습 행을 조회하지 않았으므로 전 사용자의 행 해시를 새로 전수 비교했다고 표현하지 않는다.

원문·접속 값·오류에 포함된 사용자 식별자·HTTP 헤더는 저장소에 넣지 않았다. 로컬 비공개 `/private/tmp/harukoto-november-audit-20261102/ops/`의 `final-audit-safe.json`, `natural-run-summary-safe.json`, `catalog-summary-safe.json`, `privileges-safe.json`, `anonymous-data-api-safe.json`에 비식별 증거를 남겼다. 이 임시 경로는 영구 보관소가 아니므로 실제 결과와 한계를 문서로 기록한다.

레슨 제출의 API·DB 변경안은 [별도 설계 문서](lesson-submit-idempotency-proposal-2026-11-02.md)다. 설계와 이번 읽기 전용 감사는 실제 변경 승인·적용과 구분한다.
