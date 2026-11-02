# 레슨 제출 중복 반영 방지 API·DB 구체안

후속 상태: 사용자가 같은 날 PR #211 병합과 이 안의 구현·회귀·시뮬레이터 검증을 승인했다. 아래는 승인 당시의 설계 기준이며 실제 구현·검증 결과와 운영 미적용 경계는 [구현 기록](lesson-submit-idempotency-implementation-2026-11-02.md)을 따른다.

## 상태와 승인 경계

2026년 11월 2일 사용자가 승인한 것은 **설계안 준비**다. 이 문서는 구현·마이그레이션·운영 적용 승인이 아니다. 실제 API·DB·Prisma·앱·인증·운영 설정과 기존 로그인·학습 기록·복습 기한·Data API 차단은 변경하지 않았다. 운영 학습 행을 조회해 영향 건수를 조사하지도 않았다.

추천 범위는 **신규 제출 프로토콜의 같은 계정·같은 제출 ID를 한 번만 반영하고 원래 결과를 재사용**하는 것이다. 레슨·퀴즈 SRS 정책 통합, 한 레슨 안의 동일 항목 여러 문항을 한 번만 반영하는 정책, 과거 기록 보정은 제외한다. 기존 [복습 정책 비교 90개와 차이](srs-policy-alignment-proposal-2026-10-23.md)는 그대로 보존한다.

구현 승인 시 API·새 테이블·모바일 pending 복구·공유 타입/Prisma 미러·회귀를 함께 작업해야 한다. 기존 데이터 일괄 백필, 새 환경 변수·운영 계정 권한·주기 작업·production dependency 추가는 제안하지 않는다.

동시성 경계에는 새 경로뿐 아니라 **기존 lesson start·legacy submit의 사용자 mutex 공유**도 포함한다. 기존 wire 요청·응답과 정상 처리의 SRS 의미는 유지하되 내부 transaction의 잠금 경계를 맞추는 변경이다. 이것을 legacy 제출 재전송까지 멱등 처리하는 것으로 표현하지 않는다.

## 현재 문제와 소스 근거

- [`POST /lessons/{id}/submit`](../../../apps/api/app/routers/lessons.py)는 `answers`만 받아 [`submit_lesson_attempt`](../../../apps/api/app/services/lesson_command.py)를 실행한다. 같은 요청을 다시 보내면 각 답안의 SRS와 이벤트를 다시 처리하고 `attempts`를 늘린다. 현재 경로에는 요청 ID와 원래 결과의 원자적 연결이 없다.
- [`LessonSubmitRequest`](../../../apps/api/app/schemas/lesson.py)는 기존 `CamelModel`의 extra-ignore 동작을 따른다. **기존 경로에 optional ID만 추가하면 구서버가 ID를 무시하고 비멱등 제출을 실행할 수 있다.**
- 현재 레슨 제출에는 XP 지급 코드·응답이 없다. 이번 안을 “중복 XP 지급 버그 수정”이나 새 XP 정책으로 설명하지 않는다.
- Flutter [`lesson_session_provider.dart`](../../../apps/mobile/lib/features/study/providers/lesson_session_provider.dart)는 pending을 먼저 저장하고 타임아웃 뒤 자동 재전송을 억제한다. 서버 진도 stamp 변경은 다른 기기의 제출 때문일 수도 있어 해당 요청이 성공했다는 영수증이 아니다.
- [`lesson_checkpoint.dart`](../../../apps/mobile/lib/features/study/domain/lesson_checkpoint.dart)의 content signature에는 제목·`audioUrl`·`voiceId`도 포함된다. 최신 detail의 유효성 검사부터 하면 내용·음원 변경 또는 비공개/삭제 뒤 원래 제출의 결과 복구가 막힐 수 있다.
- 현재 [`AuthInterceptor`](../../../apps/mobile/lib/core/network/auth_interceptor.dart)는 401 때 전역 현재 세션으로 POST까지 재시도한다. 계정 A의 요청 대기 중 B가 로그인하면 A의 요청이 B 자격으로 전송될 위험을 새 경로에서 차단해야 한다.

## 제안 API

기존 `POST /api/v1/lessons/{lessonId}/submit`와 응답은 구 앱 호환을 위해 유지한다. 이 legacy 경로의 재전송까지 중복 방지된다고 주장하지 않는다. 새 앱은 아래 새 경로를 사용하며 **404/405 때 legacy 경로로 fallback하지 않는다.**

### 새 제출

`POST /api/v1/lessons/{lessonId}/submissions`

```json
{
  "submissionId": "<UUID v4>",
  "expectedUserId": "<처음 제출한 계정 UUID>",
  "answers": [
    {
      "order": 1,
      "selectedAnswer": "a",
      "submittedOrder": null,
      "responseMs": 8000
    }
  ]
}
```

`answers`는 현재 `AnswerSubmission`의 필드·정상 채점 의미를 유지한다. 새 DTO만 엄격하게 검증하고 기존 모델의 전역 extra 처리나 구 API 계약을 강화하지 않는다. 실제 권한의 근거는 기존 `get_current_user`와 JWT다. `expectedUserId`는 권한을 부여하는 값이 아니라 **동결 요청의 원래 계정과 현재 인증 계정의 일치 assertion**이다. 불일치하면 403·쓰기 0이다.

성공은 최초 처리와 재전송 모두 200이며 같은 envelope를 반환한다.

```json
{
  "submissionId": "<같은 UUID>",
  "processedAt": "<최초 처리 시각 UTC>",
  "result": {
    "scoreCorrect": 1,
    "scoreTotal": 1,
    "results": [],
    "status": "COMPLETED",
    "srsItemsRegistered": 1
  }
}
```

`result`는 **실제 기존 `LessonSubmitResponse` 전체**를 저장한다. 위 `results: []`는 구조 설명용 축약이며 실제 문항별 결과를 생략하는 계약이 아니다. 날짜·정답·해설·이전/이후 상태·등록 개수도 최초 결과 그대로 반환한다. replay 때 최신 SRS나 현재 문항으로 결과를 재생성하지 않는다. `processedAt`는 최초 처리에 기록한 시각이며 정밀한 DB commit 시각이라고 표현하지 않는다.

### 결과 조회

`GET /api/v1/lessons/{lessonId}/submissions/{submissionId}?expectedUserId=<원래 계정 UUID>`

본인·같은 레슨의 완료 영수증만 읽고 동일 envelope를 반환한다. 이 GET은 상태를 만들거나 SRS를 갱신하지 않는다. 인증 계정 assertion을 먼저 검사하고, 다른 계정의 영수증 존재 여부는 노출하지 않는다.

새 GET/POST의 개인 결과와 결과 없음 응답에는 `Cache-Control: private, no-store`를 적용한다. 과거 404의 캐시가 나중에 commit된 결과 복구를 가리지 않아야 한다. 기존 API 전체의 캐시 정책을 바꾸는 안은 아니다.

**GET 404는 “원래 POST가 실행되지 않았다”는 증명이 아니다.** 아직 commit되지 않은 동시 요청의 행은 보이지 않을 수 있다. 이때도 같은 ID·동결 body만 재시도하며 새 ID를 자동 발급하지 않는다.

| 상황                                             | 제안 응답·동작                                       |
| ------------------------------------------------ | ---------------------------------------------------- |
| 같은 계정·ID·레슨·지문                           | 최초 결과 200, 채점·시도·SRS·이벤트 재실행 0         |
| 같은 계정·ID지만 답안·순서·응답 시간·레슨이 다름 | 409, 기존 결과·기록 불변, 자동 새 ID 없음            |
| JWT 없음/만료                                    | 기존 401, pending 보존 후 같은 계정의 정상 인증 회복 |
| `expectedUserId`와 현재 계정이 다름              | 403, 쓰기 0, 원래 계정 복귀 안내                     |
| 조회 대상 없음/다른 사용자/다른 레슨             | 404, 다른 사용자 데이터 노출 없음                    |
| 새 경로가 없는 구서버                            | 404/405, 기존 submit fallback 금지·pending 유지      |
| 잠금 시간 초과·일시 장애·commit 결과 불명        | 503 등 재확인 가능 오류, 같은 ID 조회·재시도만       |
| 손상된 영수증/알 수 없는 저장 스키마             | 실패 안내, 원본 보정·재실행·삭제 금지                |

새 경로의 403/404/409는 Flutter의 전역 일반 오류 문구만 쓰지 않고 해당 경로에 한정한 도메인 예외로 구분한다. 계정 변경·답안 불일치·아직 미확정인 결과를 같은 “이미 처리됨” 안내로 합치지 않는다. 확정 실패에 대한 영수증 저장은 1차 범위에 넣지 않으며, 미확정 pending의 자동 폐기·새 ID 교체도 허용하지 않는다.

## DB 제안: 완료 영수증 테이블 하나

`public.lesson_submissions`를 **빈 새 비파티션 테이블**로 추가한다. 아래는 승인 전 구조안이며 DDL 파일을 만들거나 실행하지 않았다.

| 필드                      | 제안 타입·제약                                  | 목적                                                              |
| ------------------------- | ----------------------------------------------- | ----------------------------------------------------------------- |
| `user_id`                 | UUID, NOT NULL, FK `users.id ON DELETE CASCADE` | 기존 인증 사용자 범위. 계정 삭제 시 개인정보 정리                 |
| `submission_id`           | UUID, NOT NULL                                  | 클라이언트가 동결한 제출 UUID                                     |
| `lesson_id`               | UUID, NOT NULL, 의도적으로 lesson FK 없음       | 레슨 삭제 뒤에도 과거 영수증 복구. 최초 처리에서는 실제 레슨 검증 |
| `request_fingerprint`     | TEXT, 소문자 SHA-256 64자리 CHECK               | 같은 ID의 다른 요청 거절                                          |
| `fingerprint_version`     | SMALLINT, NOT NULL, 초기 1                      | 정규화 규약의 명시적 버전                                         |
| `response_schema_version` | SMALLINT, NOT NULL, 초기 1                      | 과거 응답 snapshot reader 구분                                    |
| `response_body`           | JSONB, NOT NULL, object CHECK                   | 최종 envelope 전체                                                |
| `processed_at`            | TIMESTAMPTZ, NOT NULL                           | 최초 처리 시각                                                    |

- PK는 `(user_id, submission_id)`다. 보조 인덱스는 `(user_id, lesson_id, processed_at)`을 제안한다. 같은 UUID가 다른 사용자에게 생겨도 분리되지만, body의 원래 계정 assertion이 있어 계정 전환 오염은 거절한다.
- 지속적인 `PROCESSING` 행은 만들지 않는다. 업무 반영과 **완료 영수증이 한 transaction에서만 commit**된다. 중간 상태 청소 작업이나 lease 복구 cron은 필요하지 않다.
- 처음에는 자동 TTL·영수증 삭제·ID 재사용을 두지 않는다. 보관 정책을 줄이려면 결과 만료 후에도 같은 ID의 재실행을 막는 tombstone/410 정책을 별도로 승인받는다. 무기한 보관의 저장 비용도 추후 운영 평가 대상이다.
- lesson FK를 생략하는 것은 의도적인 보존 결정이다. 출처 UUID의 참조 유효성은 최초 처리에서 검증하고, 이후 콘텐츠 삭제·재시드가 이미 확정된 영수증을 지우지 않도록 한다. 기존 레슨 삭제 정책을 변경하는 안은 아니다.

### 보안·마이그레이션 경계

Alembic이 유일한 DDL 권한자로 새 테이블을 만들고 SQLAlchemy 모델을 맞춘 뒤, shared-packages-agent가 `pnpm db:sync`로 Prisma를 미러링한다. Prisma가 별도 운영 DDL을 실행하지 않는다.

새 테이블은 기존 운영 owner, RLS 활성, 클라이언트용 정책 없음, PUBLIC·anon·authenticated·service_role의 유효 테이블/열 권한 0을 검증한다. 기존 DDL guard·default privilege·빈 PostgREST 노출 스키마·Data API 차단을 유지한다. API는 기존 DB 실행 역할만 사용하고 새 권한·환경 변수는 추가하지 않는다. 기존 테이블·사용자·학습 행·복습 기한을 재작성하거나 영수증을 백필하지 않는다.

적용 직전 실제 Alembic head와 같은 이름의 객체가 없는지 확인한다. 예상 밖 기존 테이블·다른 소유자/제약/권한이 있으면 덮어쓰거나 자동 보정하지 않고 중단한다. 빈 새 테이블이어도 사용자 FK·인덱스·보안 DDL은 짧은 잠금을 요구할 수 있으므로 저부하 시간과 제한된 lock/statement timeout을 사용하고 실패 시 전체 rollback한다. 구체 실행 SQL·전후 비교·안전 재시도 조건은 구현 PR에서 별도 검토한다. 2027년 3월 파티션 보완과 이 변경은 다른 승인·마이그레이션 범위로 유지한다.

## 원자적 처리와 동시성

1. 기존 인증과 원래 계정 assertion을 확인하고 요청을 정규화한다.
2. 기존 완료 영수증을 **현재 레슨 조회보다 먼저** 찾는다. 같은 지문이면 원래 결과를 반환한다. 콘텐츠 수정·비공개·삭제 후에도 본인의 확정 결과를 복구할 수 있다.
3. 영수증이 없으면 해당 사용자 행에 `FOR NO KEY UPDATE` 잠금을 획득하고 영수증을 다시 찾는다. 앞 요청이 기다리는 동안 commit했을 수 있기 때문이다.
4. 여전히 없을 때만 현재 레슨·답안·SRS 매핑을 검증하고 기존 등록·문항별 SRS 처리·진도 집계를 수행한다. 최초 처리의 검증·공개/접근 정책은 현재 legacy 규칙을 보존하며, 별도의 권한 정책 강화까지 이번 안에 묶지 않는다.
5. typed 응답을 완성·검증하고 최종 JSON snapshot과 영수증을 넣은 뒤 **한 번만 commit**한다. 현재 helper 내부의 commit은 내부 apply 함수와 transaction 조정 경계로 분리해야 한다.
6. 실패하면 새 영수증·진도·SRS·이벤트를 모두 rollback한다. commit은 성공했지만 응답이 유실됐다면 다음 같은 ID 조회/제출은 원래 결과를 반환한다.

현재 인증 쿼리로 session이 이미 autobegin 상태일 수 있어 무조건 `db.begin()`을 중첩하는 구현은 피한다. FK의 `KEY SHARE`와 불필요하게 충돌하지 않도록 `FOR UPDATE` 대신 `FOR NO KEY UPDATE`를 택한다. 이 잠금 조합의 호환성은 [PostgreSQL 17 공식 문서](https://www.postgresql.org/docs/17/explicit-locking.html#LOCKING-ROWS), `key_share=True`의 SQL 매핑은 [SQLAlchemy 2.0 공식 문서](https://docs.sqlalchemy.org/en/20/core/selectable.html#sqlalchemy.sql.expression.Select.with_for_update)와 대조했다. 설치된 SQLAlchemy의 오프라인 SQL 컴파일도 확인했으나 실제 DB 동시성 증명은 승인 후 회귀가 필요하다.

초기 잠금·문장 제한은 기존 운영의 제한된 처리 원칙을 따르며 예를 들어 transaction-local 잠금 2초·문장 15초를 검증 후보로 둔다. 실제 적정값은 레슨 크기·부하 회귀 후 확정하며 전역 DB 설정은 바꾸지 않는다. timeout은 원래 ID의 처리 여부를 재확인해야 하는 상태이지 새 제출 허가가 아니다.

같은 사용자·서로 다른 ID는 사용자가 명시적으로 시작한 다른 시도다. 이를 같은 payload라는 이유로 합치지 않는다. legacy submit·lesson start도 같은 사용자 mutex를 먼저 쓰게 해야 같은 레슨 진행 행의 경합을 줄일 수 있지만, **ID 없는 legacy 재전송의 중복 반영까지 해결되는 것은 아니다.** 다른 사용자는 독립적으로 처리한다. 퀴즈·웹 전체 SRS 갱신의 동시성까지 통일했다고 주장하지 않는다.

### 요청 지문 규칙

- 유효하게 해석한 기존 필드, UUID 표준 문자열, 명시적 null/default(`responseMs=0` 등), JSON object key 순서를 정규화하고 SHA-256을 계산한다. 원래 계정·path의 레슨 ID와 지문 버전을 포함한다.
- **`answers` 배열과 `submittedOrder` 토큰 배열의 순서, 문자열·정오답·`responseMs` 값은 그대로 유지한다.** 서버가 임의 정렬·중복 제거해 같은 요청으로 간주하지 않는다. 현재 같은 문법을 평가하는 여러 문항의 SRS 전이는 순서에 영향을 받을 수 있다.
- 최초 전송 전에 확정한 응답 시간을 재시도 시 다시 계산하지 않는다. 지문 규약·응답 스키마의 알 수 없는 버전은 임의로 최신 규칙에 맞춰 덮어쓰지 않는다.

## 모바일 저장·복구 동작

### 새 제출의 생애주기

1. 처음 제출할 때 UUID v4·원래 계정·레슨·정확한 answers body를 한 번 동결한다. 현재 안전한 helper가 없으면 Dart 표준 `Random.secure`의 16바이트에 표준 UUID v4 version/variant를 적용하는 안을 검증한다. 보안 난수를 사용할 수 없으면 실패 처리하며 timestamp·화면 shuffle seed·일반 Random으로 fallback하지 않는다. 신규 패키지는 제안하지 않으며 패키지 채택이 필요해지면 별도 production dependency 승인 대상이다.
2. 계정·레슨별 **단일 원자적 pending envelope**에 ID와 동결 payload를 먼저 저장하고 성공을 기다린다. 저장 실패 시 POST는 0회다. `SharedPreferences`의 저장 성공을 물리적 fsync 보장으로 확대하지 않는다.
3. 새 POST/GET에는 이미 있는 `skipAuthRefresh` 옵션을 적용한다. 전역 현재 세션으로의 무조건적인 401 재전송·sign-out을 이 두 요청에서 피하고, pending을 보존한 채 같은 계정의 정상 인증 회복 후 다시 확인한다. 글로벌 인증 동작을 임의로 바꾸지 않는다.
4. 요청 전·응답 처리 전 계정과 generation을 확인한다. 늦은 응답이 다른 계정의 화면·조회 캐시·진도를 덮지 않게 하고, 서버 `expectedUserId` assertion으로 잘못된 계정의 첫 쓰기도 막는다.
5. 타임아웃·앱 완전 재실행은 같은 ID의 결과 조회부터 한다. 아직 결과가 없거나 불명확하면 같은 동결 요청만 재시도한다. 같은 레슨에서 미확정 제출이 남은 동안 새 ID를 자동 만들거나 답안을 바꾸지 않는다. 다른 레슨의 사용까지 막을 필요는 없다.
6. 성공 결과는 저장된 원래 결과로 표시하고 조회 캐시만 갱신한다. 재개를 새 완료 telemetry·보상·학습 mutation으로 중복 반영하지 않는다. ack 저장·삭제 실패 후에도 같은 ID가 남아 안전하게 재조회돼야 한다.
7. 이전 결과가 확인되고 사용자가 진짜 재학습을 시작할 때 새 ID를 발급한다. 앱 삭제·저장소 유실로 ID 자체를 잃은 논리적 시도를 서버가 추정해 합친다고 보장하지 않는다.

### 기존 checkpoint와 rollback

| 기존 상태                              | 제안 처리                                                                          |
| -------------------------------------- | ---------------------------------------------------------------------------------- |
| ID 없는 pending                        | 새 ID를 사후 붙여 자동 POST하지 않음. 기존 모호 상태·서버 기록 확인·보존 안내 유지 |
| 아직 제출하지 않은 유효 non-pending    | 기존 카드 위치·답안·계정 분리 보존. 앞으로 첫 제출 때만 ID를 추가                  |
| 이미 acknowledged                      | 재전송하지 않고 기존 완료 tombstone/정리 유지                                      |
| ID와 동결 body가 있는 새 pending       | 같은 ID 조회·재전송으로 복구                                                       |
| ID/owner/body가 손상되거나 서로 불일치 | fail closed. 새 ID 자동 발급·임의 답안 보정 금지                                   |

서로 독립된 두 활성 key에 legacy 초안과 새 receipt를 쓰면 구 앱이 오래된 non-pending 초안을 legacy 제출할 수 있다. 한 envelope의 저장 버전·known pending 표시와 구 reader의 실제 동작을 fixture로 검증해야 한다. 기존 reader가 새 버전을 무시하고 새 시도로 돌아갈 수 있다면 그 구 앱으로의 롤백은 안전하지 않다. **호환 reader와 pending 차단을 유지한 수정 배포**를 기본으로 하며, 단순 version 증가만으로 이전 앱 안전성을 주장하지 않는다.

구체적인 1차 저장안은 기존 `lesson_checkpoint.v1.<account>.<lesson>` **key 하나를 유지**하고, 최초 새 POST 직전에 payload만 `version: 2` envelope로 원자적으로 교체하는 것이다. top-level에 `lessonId`, `submissionPending: true`, `acknowledged: false`를 유지하고, 내부에 기존 V1 초안과 `protocolVersion: 1`·ID·원래 계정·동결 body를 함께 둔다. 최대 512KB의 기존 읽기 제한과 정합을 맞추고 초과·저장 실패 시 POST하지 않는다. 다른 활성 receipt key를 추가해 stale V1을 남기지 않는다.

현재 #209 reader는 버전 2를 읽지 못해도 위 pending flag 때문에 `_knownNonPending`으로 초기화하지 않고 원문을 보존하며 제출을 차단한다. 이 소스 관찰을 실제 이전-reader fixture로 고정해야 한다. 완료 ack도 같은 key에 기록한 뒤 정리하고, 실패하면 ID가 있는 pending 또는 acknowledged envelope가 남아 재조회되게 한다. 이 동작을 임의의 더 오래된 앱 전체에 대한 호환 보장으로 확대하지 않는다.

### detail 변경과 결과 화면

현재 detail GET·전체 content signature 검증보다 먼저, 최소한의 계정·레슨·제출 ID·동결 body 복구 정보를 읽어 결과 조회에 도달해야 한다. 변경된 음원·제목·비공개·삭제가 이미 확정된 제출 결과의 복구를 가로막지 않게 한다.

현재 서버 커리큘럼에서 레슨이 사라져도 복구 진입점이 남아야 한다. 기존 저장 목록/이어하기의 계정별 key 검사에서 pending envelope를 찾아, 최신 chapter/detail에 없는 레슨도 “제출 결과 확인”으로 열 수 있게 한다. 별도 활성 저장 key를 만들지 않고, 제출 당시 제목이 있으면 안내용으로만 사용하며 없으면 일반 레슨 결과 제목을 쓴다. raw UUID나 내부 오류를 제품 화면에 표시하지 않는다.

1차 복구 화면은 **현재 detail에 의존하지 않는 점수 요약·처리 시각·복구 안내**를 권한다. 현재 `LessonResultStep`은 order를 못 찾으면 첫 문항으로 fallback하므로, 과거 결과를 최신 문항에 억지로 붙이지 않는다. 검증된 제출 당시 표시 snapshot이 있을 때만 상세 원문을 표시한다.

저장된 `nextReviewAt`는 제출 당시 기한이며 현재의 최신 기한이 아닐 수 있다. 과거 결과는 절대 시각과 “제출 당시” 맥락으로 보여주고 음수 “분 후”를 만들거나 최신 기한처럼 표시하지 않는다. 현재 기한이 필요하면 별도의 읽기 전용 조회임을 구분한다. 이번 안은 학습 시작 당시 콘텐츠의 채점 버전 고정까지 구현하는 안은 아니다.

## 보존·배포·롤백

- 과거 영수증 백필·기존 attempts/완료 시각을 요청 ID로 재해석·기존 SRS 기한 재계산은 하지 않는다. 진도 stamp만으로 과거의 특정 제출 성공을 확정하지 않는다.
- 현재 레슨 정답/오답의 간격·상태 전이와 같은 항목의 여러 문항별 갱신은 유지한다. 멱등성은 **동일 제출의 전송 중복**만 제거한다. 한 레슨 안의 동일 항목을 한 번만 갱신하는 교육 정책과 구분한다.
- 새 빈 테이블·보안 검증 → 서버 새 경로/reader 전체 트래픽 확인 → 새 앱 순으로 배포한다. 구서버가 남은 동안 새 앱을 활성화하지 않는다. 새 경로 미지원 시 legacy fallback은 없다.
- 웹 코드에서 현재 레슨 submit BFF/호출자는 발견하지 못했다. 웹 quiz BFF와 혼동하지 않는다. 그래도 OpenAPI 생성 타입·Prisma가 바뀌므로 web/admin 등 직접 소비자의 타입·빌드·계약 검증이 필요하다.
- 이미 새 영수증이 생긴 뒤에는 테이블을 유지하고 reader를 가진 수정 배포를 기본으로 한다. 과거 앱/서버로 단순 회귀하거나 receipt를 삭제해 같은 ID를 다시 실행하게 하지 않는다. `DROP`·`CASCADE`·학습 기록 되감기·Data API 재개방은 롤백 수단이 아니다.

## 구현 승인 후 회귀 기준

| 영역                     | 반드시 증명할 동작                                                                                                            |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| 순차·별도 DB 연결 재시도 | 같은 ID/body N회에 영수증 1개·시도 1회분·SRS/event 1회분, 같은 날짜·결과 JSON                                                 |
| 요청 충돌·격리           | 답안·배열 순서·responseMs·레슨 변경은 409·변경 0. 계정 assertion 불일치는 403·쓰기 0. 타인 조회 404                           |
| 동시성                   | 같은 ID POST 20개·POST/GET 경합·첫 SRS/진도 생성·다른 ID의 의도적 재학습·다른 사용자 병렬                                     |
| 실패 원자성              | 등록·n번째 답안·이벤트·영수증 flush·commit 전 실패 후 전체 rollback. commit 성공/응답 유실은 같은 결과 복구                   |
| 콘텐츠·응답 수명         | 수정·비공개·삭제 뒤 원래 결과 조회. 손상·unknown schema에서 원본 재채점/수정 0                                                |
| 모바일 저장              | 저장 실패 시 POST 0, cold restart 뒤 같은 ID/body/시간, ack/정리 실패, 손상·큰 payload, OS hit-test와 구분된 실제 UI/API 검증 |
| 계정·인증                | A의 401 대기 중 B 로그인, 늦은 응답·자동 로그아웃·B의 쓰기 오염 0. refresh/재로그인 후 같은 A의 결과 복구                     |
| legacy·rollback          | ID 없는 pending 자동 POST 0, acknowledged 재전송 0, 구서버 fallback 0, 기존/이전 reader fixture                               |
| 기존 정책·기록           | 비교 90개·같은 문법 3회 갱신 등 기존 결과 유지, 과거 진도/SRS/event/로그인/음원·Data API 불변                                 |
| 스키마·소비자            | 실제 PostgreSQL RLS/열 권한/guard·Prisma drift·OpenAPI·생성 타입·모바일 계약·web/admin 직접 소비자                            |

이번에는 소스 검토와 SQL 잠금 구문의 오프라인 컴파일만 수행했다. 위 회귀를 구현·실행했거나 운영에서 새 프로토콜을 검증했다고 표현하지 않는다. 구현 전 독립 검토에서 로컬 envelope의 rollback 안전성·잠금 범위·보관 정책을 특히 확인한다.
