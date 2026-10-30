# 특수 퀴즈 이어하기 API·기존 세션 처리 제안

## 상태와 목표

**이 문서는 승인 전 설계 이력이다.** 이후 사용자가 2026년 10월 30일 PR #208 병합과 이 안의 구현·회귀 테스트·시뮬레이터 검증을 승인했다. 현재 결과는 [구현·검증 기록](special-quiz-resume-implementation-2026-10-30.md)을 따른다. 아래의 미구현·미검증 표현은 제안 작성 당시를 가리키며 운영 배포 완료를 의미하지 않는다.

사용자는 먼저 특수 퀴즈 이어하기의 API와 기존 세션 처리안을 준비하도록 요청했다. 설계 조사에서는 소스·기존 테스트만 확인했고 운영 퀴즈·답안·학습 행은 조회하거나 변경하지 않았다. API 구현과 운영 적용은 이 안을 확인한 뒤 별도로 진행하도록 제안했다.

목표는 matching(짝 맞추기)과 arrange(문장 배열)를 중단했다가 **같은 세션·같은 문제·같은 모드**로 이어 푸는 것이다. 이미 저장된 정답·오답을 건너뛰고 첫 채점·복습 기한·XP 정책은 유지한다. 모드를 알아내려고 콘텐츠를 새로 뽑거나 기존 기록을 보정하지 않는다.

DB 스키마·권한·Data API·환경 변수 변경은 필요하지 않은 안이다. 신규 특수 세션에 저장할 기존 JSON의 내용과 API 응답, 모바일 및 공유 DB를 읽는 웹 BFF의 호환 처리가 변경 대상이다.

## 원인과 근거

조사 기준 실행 소스는 #204 배포 소스와 같으며, #203·#205 병합은 문서만 추가했다.

1. [`quiz_start.py`](../../../apps/api/app/services/quiz_start.py)의 `/quiz/start` 경로는 `_create_quiz_session` 호출에 `mode`를 넘기지 않는다. helper는 이미 이를 지원하지만 matching/arrange의 모드가 남지 않는다. smart 시작은 별도로 `mode="smart"`를 남긴다.
2. [`quiz_session_query.py`](../../../apps/api/app/services/quiz_session_query.py)의 resume 응답에는 모드와 매칭 쌍이 없다. [`quiz_session.py`](../../../apps/api/app/services/quiz_session.py)의 응답 변환도 저장된 `word`/`meaningKo` 등의 매칭 표시 정보를 반환하지 않는다.
3. [`quiz_session_service.dart`](../../../apps/mobile/lib/features/study/providers/quiz_session_service.dart)는 `quizType` 또는 진입 화면의 fallback mode로 화면을 선택한다. 실제 `VOCABULARY + matching` 세션은 `quizType=MATCHING`이 아니므로 홈에서 재개할 때 일반 선택형 화면으로 떨어질 수 있다.
4. matching 화면만 강제로 열어도 [`matching_quiz_controller.dart`](../../../apps/mobile/lib/features/study/presentation/widgets/matching_quiz_controller.dart)가 표시 정보와 빈 `options`를 처리하지 못해 예외가 날 수 있다.
5. 기존 [`quiz_session_provider_test.dart`](../../../apps/mobile/test/features/study/providers/quiz_session_provider_test.dart)는 가짜 `quizType=MATCHING` 재개 응답을 검사한다. 실제 카테고리와 별도 mode가 결합된 부분 재개 경로를 보장하는 테스트가 빠져 있다.

`quizType`을 `VOCABULARY`에서 `MATCHING`으로 바꾸는 해결책은 사용하지 않는다. 콘텐츠 카테고리는 답안 타입·SRS·통계에 쓰이므로 화면 표시 모드와 분리해야 한다.

## 제안 API 계약

기존 경로·요청·응답 필드는 유지하고 다음 필드만 추가한다. 성공 시 서버가 검증한 값을 반환하되 새 필드는 nullable/default를 두고 새 앱도 구 서버의 필드 부재를 허용한다. 구 앱이 추가 필드를 무시할 수 있다는 사실은 구 앱의 특수 이어하기가 고쳐진다는 보장은 아니다. 새 모바일 버전까지 배포해야 기능이 완성된다.

| API                                           | 요청                          | 추가 응답 필드와 동작                                                                                      |
| --------------------------------------------- | ----------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `POST /api/v1/quiz/start`                     | 기존 요청 유지                | `mode: string 또는 null`. 기존 `matchingPairs` 유지. 실제 실행한 모드와 표시 스냅샷을 저장                 |
| `GET /api/v1/quiz/incomplete`                 | 기존 요청 유지                | `session.mode`, `session.resumeStatus` 추가. 상태는 `available`, `legacy_unavailable`, `invalid_snapshot`  |
| `POST /api/v1/quiz/resume`                    | 기존 `{sessionId}` 유지       | `mode`, `matchingPairs: MatchingPair[] 또는 null` 추가. 기존 `questions`·답한 ID·총수·정답수·quizType 유지 |
| `POST /api/v1/quiz/smart-start`               | 기존 유지                     | 공유 start 모델에 `mode="smart"`, pairs는 기존 null                                                        |
| `POST /api/v1/quiz/wrong-answer-review/start` | 기존 `{sourceSessionId}` 유지 | 공유 resume 모델에 `mode="wrong_answer_review"`, pairs=null. 특수 유형 오답 복습 지원을 새로 추가하지 않음 |

새 필드 이름은 CamelModel을 거치는 wire key 기준이다. `MatchingPair`는 기존 `{id, word, meaning}` 형식을 재사용한다. `mode`는 현재 구현된 `normal`, `matching`, `arrange`, `cloze`, `review`, `smart`, `wrong_answer_review`를 대상으로 검증하며, FastAPI가 아직 실제 지원하지 않는 typing을 이번에 새로 지원한다고 약속하지 않는다.

현재 start 요청의 mode는 자유 문자열이며 알 수 없는 값이 normal loader로 흐른다. 이번에는 요청 enum을 갑자기 좁히지 않는다. 응답/저장 메타데이터는 **실제 실행한 지원 모드**로 정규화하고 임의 요청 문자열을 그대로 믿지 않는다. 모든 일반 세션을 일괄 객체 JSON으로 전환하지 않고, 우선 새 matching/arrange의 기존 JSON에 메타데이터를 보존한다.

### 오류 응답

- 인증401, 타인/없는 세션404, 이미 완료400, 잘못된 UUID422는 기존대로 유지한다.
- 모드·표시 스냅샷을 안전하게 복원할 수 없으면 **409**, 기존 형식인 `{ "detail": "한국어 안내" }`를 사용한다. 새 공통 오류 객체나 전역 오류 계약 변경은 필요하지 않다.
- 미지원 기존 형식은 “이 퀴즈는 이전 형식으로 저장되어 이어서 불러올 수 없어요. 저장된 학습 기록은 유지됩니다.”로 안내한다. 손상·불일치는 기록 보존과 함께 불러올 수 없음을 안내하고 raw 데이터는 노출하지 않는다.
- [`ApiException.userMessage`](../../../apps/mobile/lib/core/network/api_exception.dart)는 현재 409를 “이미 처리된 요청입니다.”로 바꾼다. **서버 문구만 추가해서는 해결되지 않는다.** 새 앱은 resume 경로의 409만 repository/domain 상태로 구분해 위 안내를 표시한다. 다른 API의 409 처리나 답안 충돌 안내는 바꾸지 않는다.
- 통신 오류에는 같은 세션 재시도를 제공한다. 영구적인 `legacy_unavailable`/`invalid_snapshot`에는 돌아가기를 제공하고 자동 새 퀴즈 시작이나 무한 재시도를 하지 않는다. 알 수 없는 새 모드/상태도 임의 일반 화면으로 열지 않고 안내한다.

## 신규 세션 저장안

현재 `QuizSession.questions_data`는 이미 배열과 `{stage_id?, mode?, questions}` 객체를 지원하는 JSON이다. 신규 matching/arrange에서만 필요한 메타데이터를 추가한다. 새 컬럼·테이블·인덱스·마이그레이션·Prisma 구조 변경은 없다.

- matching: `mode="matching"`, 기존 `stage_id`, 전체 원본 `questions`, 시작 응답에 사용한 **동일한** `matchingPairs`를 한 번에 저장한다. 문장 매칭도 양쪽 표시 문장을 모두 이 스냅샷에 보존한다.
- arrange: `mode="arrange"`, 기존 `stage_id`, 한국어 문장·일본어 정답 문장·토큰·설명이 포함된 원본 `questions`를 저장한다.
- 질문의 canonical 콘텐츠/문항 UUID, 순서, 기존 `correctOptionId`와 pair ID를 유지한다. 재개 때 ID나 원문을 재발급·재생성하지 않는다.
- mode와 snapshot의 일치, 중복 ID·유실 필드를 저장 전에 검증한다. 네트워크 재시도 때 표시 데이터를 다시 생성하는 로직을 두지 않는다.

## 기존 세션: 백필 없는 제한적 복원

기존 세션을 일괄 조회·백필하거나 현재 콘텐츠 테이블에서 빈 문장을 보충하지 않는다. **사용자가 해당 세션을 열 때 저장 스냅샷만 읽어** 아래 제한된 decoder로 판정한다. 이는 알려진 과거 직렬화 형식을 fixture로 검증하는 서버 호환 계층이며, 앱이 문장 모양이나 빈 선택지만 보고 추측하는 방식이 아니다.

| 저장 상태                                                                  | 처리안                                                                                                                               |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| 명시 mode와 완전한 snapshot                                                | mode와 표시 데이터를 검증한 뒤 같은 모드로 재개                                                                                      |
| mode 없는 VOCAB matching                                                   | `word`·`meaningKo`·기존 pair ID·canonical 질문 ID가 모두 있고 알려진 형식과 정확히 일치하면 읽기만으로 복원                          |
| mode 없는 GRAMMAR matching                                                 | `pattern`·`meaningKo`·기존 pair ID·canonical 질문 ID에 같은 검증 적용                                                                |
| mode 없는 arrange                                                          | `type=SENTENCE_ARRANGE`·한국어 원문·`japaneseSentence`·`tokens` 등 알려진 전체 형식을 검증한 경우 복원                               |
| mode 없는 SENTENCE matching                                                | 저장에 일본어 상대 문장이 빠진 형식은 **복원 불가**. 최신 콘텐츠를 조회해 과거 문장으로 간주하지 않음                                |
| 기존 normal/smart/오답 복습 선택형                                         | 기존 배열/객체를 지원하고 해당 화면 유지. mode 없는 선택형의 원래 생성 요청이 normal/review 중 무엇이었는지까지 안다고 주장하지 않음 |
| 혼합 형식·중복 ID·답안 참조 불일치·알 수 없는 metadata·필수 표시 정보 없음 | 보수적으로 거절하고 기존 기록 유지                                                                                                   |

decoder는 전체 질문 수=저장 total, 유효·고유 canonical UUID, 동일한 알려진 형식, 모든 표시 필드, 질문과 pair의 일대일 대응, 기존 pair ID의 유일성, 저장 답안의 질문 소속을 검증한다. mode 근거는 내부적으로 `stored`와 `legacy_snapshot`을 구분한다. 후자는 원래 요청을 복구한 확정 정보가 아니라 검증된 호환 표현이라는 한계를 남긴다.

중복된 과거 답안이 있다면 기존 canonical 첫 답안 규칙으로 읽고 ID 집합으로 진행을 계산한다. 충돌·미등록 참조가 있다면 거절하며 행 삭제·correct_count 덮어쓰기·재채점은 하지 않는다. 본 조사에서는 운영 학습 행을 읽지 않았으므로 영향 세션 수나 실제 발생 비율은 아직 모른다.

## 진행·복습·보존 정책

1. 정답·오답과 관계없이 **서버에 저장된 canonical 질문 ID**는 이미 답한 항목이다. matching은 임의 순서 답안이 가능하므로 답한 개수만큼 앞에서 잘라서는 안 된다.
2. 전체 원본 질문 수와 저장된 답안 수를 유지하고 남은 질문만 제시한다. 화면의 원본 진행률과 특수 위젯의 남은 목록 기준 진행을 혼동하지 않게 한다.
3. 미제출 토큰 선택·매칭판 셔플·좌우 선택 상태는 저장하지 않는다. 저장 완료 답안 다음부터 복원한다.
4. 기존 FastAPI의 답안 row lock·동일 답안 재시도 성공·다른 답안409·canonical 첫 답안 채점·완료 재호출 XP=0을 유지한다. 새 답안을 실제 제출한 경우에만 기존 정오답별 SRS 정책을 적용한다. 재개 조회 자체가 XP나 복습 기한을 바꾸지 않는다.
5. 한 쌍만 남은 matching과 전부 저장됐으나 complete 응답이 유실된 경우도 지원한다. 빈 판을 새 퀴즈로 간주하지 않고 정상 완료 경로로 연결한다.
6. 특수 모드 오답 복습은 기존 미지원 상태를 유지한다. mode metadata가 생겨 기존 거절 코드 경로가 달라질 수 있으므로 400/409와 한글 안내를 회귀로 고정하고 의도치 않은 지원 확대를 막는다.

### 현재 정책의 중요한 부작용

`GET /quiz/incomplete`는 24시간 지난 세션의 `completed_at`을 실제 변경하고 commit한다. `/quiz/start`는 먼저 기존 모든 미완료 퀴즈를 자동 완료하고 pending XP를 지급한다. **이번 읽기 전용 조사에서는 두 API를 호출하지 않았다.**

이번 설계는 그 만료·신규 시작 정책을 바꾸지 않는다. 따라서 `resumeStatus`를 더한다고 incomplete가 순수 읽기 API로 바뀌는 것은 아니다. 복원 불가 안내의 돌아가기/재시도는 원본을 완료하거나 새 퀴즈를 시작하지 않게 한다. “새로 시작” 자동 대체 버튼은 이번 범위에서 제외한다. 향후 만료 정책 변경이나 기존 기록 보정이 필요하면 다시 구체안을 제시한다.

## 웹·구 앱 호환과 배포 순서

웹은 FastAPI 호출만 하는 소비자가 아니라 같은 DB를 읽는 자체 Prisma BFF도 있다. [`웹 resume`](../../../apps/web/src/app/api/v1/quiz/resume/route.ts)는 `questionsData`를 그대로 배열처럼 내보내며, [`웹 answer`](../../../apps/web/src/app/api/v1/quiz/answer/route.ts)는 배열의 `.find()`와 웹 `questionId` 모양을 가정한다. [`웹 complete`](../../../apps/web/src/app/api/v1/quiz/complete/route.ts)도 FastAPI와 별도로 완료·XP를 갱신한다. 새 특수 metadata만 추가해도 이 경로를 검토해야 한다.

권장 순서는 다음과 같다.

1. backend-agent가 위 API와 저장 형식·decoder 및 실제 PostgreSQL 회귀를 구현한다. shared-packages-agent가 OpenAPI 생성 타입을 동기화한다.
2. web-agent가 공유 JSON의 배열/객체와 Python `id`/웹 `questionId` 원본 ID를 검증해 정규화하는 호환 처리와 테스트를 추가한다. 새 계약의 특수 세션은 이번에 웹에서까지 풀 수 있게 확장하지 않고 안내한다. **웹에서 지원하지 않는 저장 형식은 UI뿐 아니라 answer·complete BFF도 쓰기 전에 거절**해 기존 Prisma 채점으로 우회 제출되지 않게 한다. 기존 웹 자체 생성 형식의 지원은 유지하고 FastAPI의 첫 답안·SRS 보장을 웹 전체에 이미 갖췄다고 주장하지 않는다. typing 등 별도 신규 기능 구현으로 범위를 넓히지 않는다.
3. mobile-agent가 mode 우선 복원·matchingPairs 결합·409 전용 안내·진행 표시·재시도 테스트를 구현한다. 구 서버 필드 부재에서는 기존 유효한 일반 선택형만 호환하고, 표시 정보 없는 특수 payload를 일반 화면으로 열지 않는다.
4. OpenAPI freshness·TypeScript 생성 타입·mobile 계약 validator·각 소비자 검증을 통과시킨다. 서버와 웹 호환 배포를 먼저 준비하고 모바일 업데이트를 이어 진행한다. 새 형식 세션을 만들기 전에 웹 호환이 배포돼 있어야 한다. 구 앱의 특수 재개 제한은 릴리스에 명시한다.
5. 시뮬레이터와 격리 QA 계정으로 실제 시작→저장→홈 재개→앱 완전 재실행을 검증한다. 사용자의 현재 테스트 선호대로 아이폰 설치·조작은 하지 않는다.

롤백은 새 JSON을 읽을 수 있는 호환 reader를 유지하면서 앱·서버 동작을 되돌리는 것을 기본으로 한다. **이미 새 형식으로 생성한 세션을 예전 코드가 읽을 수 있다고 가정해 과거 서버로 바로 내리지 않는다.** 실제 rollback 후보와 저장 fixture의 호환을 검증하고, 필요한 경우 reader를 유지한 수정 배포를 선택한다. 새/기존 세션 JSON을 역변환하거나 답안·XP·SRS를 되돌리지 않는다. 롤백을 위한 운영 설정 토글 신설도 이번 안에 포함하지 않는다.

## 구현 승인 후 검증 기준

| 계층              | 필수 검증                                                                                                                                                         |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| API 단위/계약     | 실제 `VOCABULARY + matching`과 `SENTENCE_ARRANGE + arrange` mode 저장·응답, matching snapshot, status/한국어409, 기존 normal/smart/오답 복습, 권한·UUID·완료 상태 |
| 기존 형식 fixture | 배열/객체, mode 없음, 검증 가능한 VOCAB/GRAMMAR matching과 arrange, 복원 불가 SENTENCE matching, 혼합/손상/미등록 답안, 읽기 전후 원본 불변                       |
| 격리 PostgreSQL   | 부분 답안 후 별도 DB 세션 재개, 첫 오답 보존, 중복·동시 답안/완료, 한 쌍 남음·모든 답안 저장/complete 재시도, SRS·XP 한 번만 적용                                 |
| 웹                | 두 JSON 모양·두 ID 키 검증, 불완전 snapshot 거절, 비순차 답안 ID 확인, 새 계약의 특수 화면 안내와 answer/complete 쓰기 전 거절, 기존 자체 생성·일반 답안 회귀     |
| Flutter           | 실제 카테고리+mode 재개, 구 서버 호환, blank options 안전 처리, scoped409 문구, 로딩·통신 오류 재시도, 저장 실패 시 종료 방지, 원본 총수 기반 진행                |
| 시뮬레이터        | matching 정답/오답 각각 저장→종료→같은 세션 남은 항목, arrange 제출→재실행→다음 문제, 저장/완료 응답 유실 재시도, 로그인 유지                                     |
| 보호 경계         | DB 구조·권한·Data API·캐시 변경 없음, 재개/거절만으로 기존 세션·답안·XP·복습 기한 불변                                                                            |

새 퀴즈 시작의 기존 자동 종료 효과가 있으므로 운영 QA의 진행 중 퀴즈를 덮어쓰지 않게 먼저 격리 환경에서 검증한다. 기존 합성 테스트나 모든 문제를 이미 저장한 resume 테스트를 실제 부분 재개 검증으로 표현하지 않는다. 이번 설계 단계에는 새 코드나 회귀 테스트를 실행하지 않았다.

## 승인 경계

이 문서는 위 API 추가, 신규 특수 JSON, 제한된 서버 legacy decoder, web/mobile 호환과 회귀 검증을 **구체적으로 제안**한다. 기존 세션 백필·재채점·만료 정책 변경·DB DDL·권한/클라우드 설정 변경은 포함하지 않는다. 운영 영향 수량 조사가 필요해도 최소 범위의 읽기 전용 안을 먼저 정한다.

[기존 결정 대기 기록](../../../.planning/escalations/2026-10-07-special-quiz-resume-contract.md)은 이후 사용자의 구현 승인으로 resolved 처리했다. 운영 반영 범위는 구현 기록에서 별도로 구분한다.
