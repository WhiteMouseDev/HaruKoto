# 연속 학습일의 KST 날짜 비교 복구

작성일: 2026-10-30 KST. 기준 main: `fa82a4b855aac6b677529dd0dcf8e82ce7fe2d55`.

## 문제와 선택한 수정

노선도 누락을 조사하며 원본 로컬에만 남은 연속 학습일 수정도 발견했다. API와 웹은 저장된 UTC timestamp의 날짜와 한국 기준 학습 날짜를 다른 기준으로 비교했다. 한국 오전의 같은 날 학습을 다른 날로 보거나 연속한 날을 누락할 수 있었다. 순수 계산 테스트로 재현했으며 실제 운영 계정의 과거 오집계 규모를 조회·단정한 결과는 아니다.

- API는 `date` 입력은 그대로 유지하고 aware 시각은 KST로 변환한다. 과거 naive timestamp는 기존 UTC 저장 관례에 따라 UTC로 해석한 후 KST 날짜로 변환한다. 기본 오늘도 KST로 계산한다.
- 대시보드의 과거 naive timestamp 처리도 같은 helper를 사용한다. 기존 aware KST 동작을 유지한다.
- 웹은 기존 `getTodayKST()`의 UTC 자정 날짜 키 형식을 유지한다. 기존 timestamp를 같은 KST 날짜 키로 정규화하고 UTC 달력 일수 차이를 비교한다. 선택적 `Date` 인자는 테스트 시각 주입을 허용하며 기존 호출은 그대로다.
- 같은 날과 이전 날 요청에서는 기존 current/longest 카운터를 그대로 반환한다. 불일치한 과거 longest 값을 부가 보정하지 않는다. 첫 학습·정상 연속·하루 이상 건너뜀의 기존 정책을 보존한다.
- 사용 중인 실제 quiz·kana stage·kana quiz·conversation 완료 경로가 이 helper를 소비하는지 회귀로 확인한다. 이 변경이 동시 완료의 모든 경쟁을 해결하거나 날짜별 영속 출석을 보장한다고 주장하지 않는다.

런타임 변경은 API 3개 파일과 웹 2개 파일이다. API 테스트 4개 파일, 웹 테스트 2개 파일을 추가·보강했다. 웹의 기존 gamification 순수 함수 테스트에서는 DB 모듈을 mock해 실 DB import를 막는다.

## 보존 경계

DB·마이그레이션·권한·RLS·Data API·환경·의존성·API 요청/응답·XP·복습 기한을 변경하지 않았다. OpenAPI 103개 경로와 최신 wrong-answer-review 계약은 동일하다. 과거 학습 기록이나 streak 카운터를 일괄 갱신하지 않는다. 적용 이후 정상 학습 완료 요청은 기존 저장 경로에서 수정한 계산을 사용한다.

`hasStudied` history 응답 필드, 영속 출석 marker, 과거 streak 재계산, 미완성 사용자 잠금 helper는 포함하지 않았다. 학습 달력 API 추가안은 별도 사용자 승인 대기다. 기존 음원·캐시·모바일 체크포인트도 변경하지 않았다.

## 검증

| 검사                                 | 결과                                                                      |
| ------------------------------------ | ------------------------------------------------------------------------- |
| API 수정 전 날짜 경계 재현           | 4/4 실패                                                                  |
| API 관련 focused                     | 98 passed                                                                 |
| 새 API 날짜·완료 호출자 회귀         | 30 passed                                                                 |
| 전체 API                             | **1039 passed / 기존 admin fixture 13 skipped**                           |
| 필수 PostgreSQL 검사                 | **85/85 passed, skipped 0** — 전체 API에 포함                             |
| PostgreSQL guard 자체 검사           | 10 passed                                                                 |
| Ruff lint / format                   | 통과, 300개 파일 format 변경 없음                                         |
| mypy                                 | 173개 source 통과                                                         |
| OpenAPI                              | 103개 경로 완전 동일                                                      |
| 웹 신규 회귀                         | UTC·Asia/Seoul·America/Los_Angeles·America/New_York 각각 **23/23 passed** |
| 웹 lint / typecheck                  | 통과 (`--incremental false`)                                              |
| 웹 전체 테스트                       | **134 passed / 7 failed / 총 141개**                                      |
| 기준 main 웹 전체 테스트             | **111 passed / 같은 7 failed / 총 118개**                                 |
| 새 웹 회귀를 기준 main helper로 실행 | 11 failed / 12 passed                                                     |
| 독립 코드 검토                       | 이번 변경의 신규 결함 발견 없음                                           |

API 테스트는 상속 환경을 비우고 synthetic 설정·폐기형 로컬 PostgreSQL로 실행했다. 첫 sandbox 실행은 `shmget` 권한 차단으로 PG 초기화에 실패했고, 허용된 재실행에서 전체가 통과했다. 운영 DB·계정·환경 파일을 사용하지 않았다. Node 의존성은 기존 설치 런타임을 재사용하되 공유 source는 최신 작업트리로 해석되는지 확인했다. Prisma schema와 lockfile도 기준과 동일하다. 초기 공유 ignored Vitest cache는 최종 검증 전에 별도 로컬 cache로 분리했다. 감사 대상 원본 source에는 변경이 없다.

웹 전체 검사는 녹색이 아니다. 변경 전 main을 별도 archive하여 같은 일곱 실패를 재현했다. 업적 개수 20→23 및 가나 업적 threshold 가정 두 개, 현 UI와 다른 stats-component assertion 다섯 개다. 새 날짜 회귀는 모두 통과하며, 기존 실패를 이번 수정으로 발생한 것처럼 세거나 전체 통과로 숨기지 않는다.

현재 CI frontend는 install/lint/typecheck/build만 실행하고 `pnpm --filter web test`는 실행하지 않는다. 기존 일곱 assertion 정비와 CI unit test 편입은 별도 후속으로 남긴다. 이 lib-only 변경에는 웹 production build를 실행하지 않았으며 기기나 운영 로그인·학습을 실제 검증했다고 주장하지 않는다.

## 적용과 롤백

이 PR은 서버/웹에 사용할 소스 수정이다. 병합·배포는 아직 수행하지 않았다. 병합 이후 API 자동 배포와 웹 배포에서 해당 커밋 사용을 확인하고 기존 로그인·학습·이어하기 smoke를 점검해야 한다. 그 과정에서 학습 완료를 제출하면 기존 정책에 따른 정상 기록 변경이 발생하므로 합성 테스트 결과와 구분한다.

철회 시 이 PR을 revert하고 이전 애플리케이션 버전을 배포한다. 스키마 rollback이나 과거 학습 기록/음원 삭제는 필요 없다. 수정 버전에서 발생한 정상 학습 기록을 삭제하거나 이전 카운터를 추정해 덮어쓰는 rollback은 하지 않는다.
