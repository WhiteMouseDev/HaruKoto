# 연속 학습일과 집계 기반 학습 달력 복구

작성일: 2026-10-30 KST. 기준 main: `fa82a4b855aac6b677529dd0dcf8e82ce7fe2d55`. PR #202의 서버·웹·공유 타입 범위다. 모바일 소비자는 별도 PR #201에서 구 응답도 지원한다.

## 문제와 날짜 계산 수정

노선도 누락을 조사하며 원본 로컬에만 남은 연속 학습일 수정도 발견했다. API와 웹은 저장된 UTC timestamp의 날짜와 한국 기준 학습 날짜를 다른 기준으로 비교했다. 한국 오전의 같은 날 학습을 다른 날로 보거나 연속한 날을 누락할 수 있었다. 순수 계산 테스트로 재현했으며 실제 운영 계정의 과거 오집계 규모를 조회·단정한 결과는 아니다.

- API는 `date` 입력을 유지하고 aware 시각을 KST로 변환한다. 과거 naive timestamp는 기존 UTC 저장 관례에 따라 UTC로 해석한 뒤 KST 날짜로 변환한다. 기본 오늘도 KST로 계산한다.
- 대시보드의 과거 naive timestamp 처리도 같은 helper를 사용한다. 기존 aware KST 동작을 유지한다.
- 웹은 기존 `getTodayKST()`의 UTC 자정 날짜 키 형식을 유지한다. 기존 timestamp를 같은 KST 날짜 키로 정규화하고 UTC 달력 일수 차이를 비교한다. 선택적 `Date` 인자는 테스트 시각 주입을 허용하며 기존 호출은 그대로다.
- 같은 날과 이전 날 요청은 기존 current/longest 카운터를 그대로 반환한다. 불일치한 과거 longest 값을 부가 보정하지 않는다. 첫 학습·정상 연속·하루 이상 건너뜀의 기존 정책을 보존한다.
- 실제 quiz·kana stage·kana quiz·conversation 완료 경로가 helper를 소비하는지 회귀로 확인한다. 동시 완료의 모든 경쟁을 해결하거나 날짜별 영속 출석을 보장하는 변경은 아니다.

## 사용자 승인된 additive history 계약

사용자는 2026-10-30 구체안에 **“API 필드 추가까지 복구”**라고 승인했다. 인증된 `GET /api/v1/stats/history`의 **200** 응답 `records[]`에 필수·non-null boolean **hasStudied**를 추가했다. query·인증·year/month/records envelope·기존 record 8개 필드는 유지한다.

기존 대시보드의 predicate를 순수 공유 함수로 추출했다. 기존과 AST 본문이 동일하며, 다음 집계 중 하나라도 양수이면 true다: words_studied, quizzes_completed, conversation_count, xp_earned, kana_learned, grammar_studied, sentences_studied, study_time_seconds, study_minutes. correct/totalAnswers나 행 존재 여부만으로 출석을 만들지 않는다. 시작만 한 행은 false다.

이는 **기존 집계에 남은 활동 여부**다. 아직 완료하지 않은 로컬 카드나 집계에 남지 않은 과거 활동을 증명하는 영속 출석 마커가 아니다. DB marker·미완성 사용자 잠금 helper·과거 기록 보정은 추가하지 않았다.

최신 OpenAPI에서 기존 생성기를 실행했다. snapshot 차이는 DailyProgressItem의 hasStudied property와 required 항목뿐이며 **103개 경로·다른 스키마는 완전 동일**하다. generated TypeScript도 required bool 한 필드의 2줄 추가뿐이다. 기존 wrong-answer-review/start와 admin ScenarioCategory 계약을 보존했다.

웹 history는 독립 Prisma/BFF와 로컬 HistoryRecord를 쓰며 이 DTO를 소비하지 않는다. FastAPI 필드 추가만으로 웹 달력 의미까지 바뀐다고 주장하지 않는다. 직접 생성 타입 소비자는 admin conversation 페이지의 ScenarioCategory이며, 기존 계약을 유지하고 해당 앱을 검증했다.

## 보존 경계

DB·ORM·마이그레이션·권한·RLS·Data API·환경·의존성·XP·복습 기한은 변경하지 않았다. 과거 학습 기록이나 streak 카운터도 일괄 갱신하지 않는다. 이후 정상 완료 요청은 기존 저장 경로에서 수정한 날짜 계산을 사용한다. 기존 음원·캐시·Kenzo/Shizuka v4·로그인·모바일 체크포인트도 변경하지 않았다.

## 검증

| 검사                                        | 결과                                                                      |
| ------------------------------------------- | ------------------------------------------------------------------------- |
| API 날짜 수정 전 경계 재현                  | 4/4 실패                                                                  |
| API 날짜 focused / 새 날짜·완료 호출자 회귀 | 98 passed / 신규 30개                                                     |
| 순수 날짜 단계 전체 API                     | 1039 passed / 기존 admin fixture 13 skipped                               |
| history 필드 추가 전 RED / 관련 GREEN       | 16 failed / 26 passed                                                     |
| 새 history schema/service/API 회귀          | 17 passed                                                                 |
| 승인 필드 포함 최종 전체 API                | **1056 passed / 기존 admin fixture 13 skipped**                           |
| 필수 PostgreSQL 검사                        | **85/85 passed, skipped 0** — 최종 전체 API에 포함                        |
| PostgreSQL guard 자체 검사                  | 10 passed                                                                 |
| Ruff lint / format                          | 통과, 302개 파일 format 변경 없음                                         |
| mypy                                        | 174개 source 통과                                                         |
| OpenAPI freshness / 기존 경로 보존          | 통과 / 103개 경로 동일                                                    |
| 공유 타입 2회 생성 freshness                | 바이트 동일                                                               |
| 공유 타입 lint / typecheck                  | 통과                                                                      |
| 직접 consumer admin lint / typecheck        | 통과 (`--incremental false`)                                              |
| admin test / build                          | **45 passed / 기존 TODO 10**, build `--webpack` 통과, 11 pages            |
| 웹 새 날짜 회귀                             | UTC·Asia/Seoul·America/Los_Angeles·America/New_York 각각 **23/23 passed** |
| 웹 lint / typecheck                         | 통과 (`--incremental false`)                                              |
| 웹 전체 테스트                              | **134 passed / 7 failed / 총 141개**                                      |
| 기준 main 웹 전체 테스트                    | **111 passed / 같은 7 failed / 총 118개**                                 |
| 새 웹 회귀를 기준 main helper로 실행        | 11 failed / 12 passed                                                     |

API 검사는 상속 환경을 비우고 synthetic 설정·폐기형 로컬 PostgreSQL로 실행했다. 최초 순수 날짜 단계의 sandbox 실행은 shmget 차단으로 초기화에 실패했으며 허용된 재실행에서 통과했다. 운영 DB·계정·환경 파일을 사용하지 않았다. Node는 기존 설치 런타임을 재사용하되 공유 source를 최신 작업트리로 해석하는지 확인했다. Prisma schema와 lockfile도 기준과 동일하다. 초기 공유 ignored Vitest cache는 최종 검사 전에 별도 local cache로 분리했다. 감사 대상 원본 source는 변경하지 않았다.

admin build는 synthetic localhost 설정과 Next가 지원하는 오프라인 폰트 fixture를 사용했다. 실제 운영 폰트 전달 검증으로 표현하지 않는다. admin 추적 소스 변경은 없으며 이력 생성 타입을 두 번 생성해 freshness를 검증했다. 타입 패키지 자체에는 test/build 스크립트가 없어 lint/typecheck로 검사했다.

웹 전체 검사는 녹색이 아니다. 변경 전 main archive에서도 같은 7개 실패를 확인했다. 기존 업적 개수·가나 threshold 가정 2개와 현 stats UI에 맞지 않는 assertion 5개다. 기존 테스트 정비와 frontend CI의 unit test 편입은 별도 후속이다. 날짜 수정 단계의 PR CI 40979761690은 backend·contract·schema drift·frontend lint/typecheck/build가 모두 통과했다. 이 CI가 웹 unit test를 실행했다는 뜻은 아니다. 필드 추가 뒤 최종 커밋의 CI는 별도 확인한다.

## 적용과 롤백

소스 구현 완료 시점에는 병합·운영 배포 전이었다. 이후 사용자 승인으로 2026-10-30 API #202 병합·서버 검증 후 모바일 #201을 병합하고 아이폰에 업데이트했다. 실제 리비전·설정/캐시/기록 보존·기기 확인 범위는 [운영 반영 기록](learning-ui-production-rollout-2026-10-30.md)을 따른다. 앱의 구 응답 fallback은 계속 유지한다.

철회 시 이 PR을 revert하고 이전 API/웹 애플리케이션 버전을 배포한다. 앱은 구 응답을 지원한다. 스키마 rollback·음원 삭제·학습 기록 삭제는 필요 없다. 수정 버전에서 발생한 정상 기록을 추정한 과거 카운터로 덮어쓰지 않는다.
