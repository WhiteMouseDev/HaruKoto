# 레슨 제출 중복 반영 방지 구현·검증 기록

## 승인과 진행 계획

2026년 11월 2일 사용자가 [설계안](lesson-submit-idempotency-proposal-2026-11-02.md)의 구현·회귀·시뮬레이터 검증을 승인했다. PR #211은 `2d78c1de`로 병합했고, 구현은 그 main 기준 `codex/lesson-submit-idempotency`에서 완료했다. **운영 DB 마이그레이션·서버 배포·운영 앱/아이폰 업데이트는 이 문서의 구현·격리 검증에 포함하지 않았다.** 이후 별도 승인으로 완료한 PR #212 병합·마이그레이션·배포·운영 시뮬레이터 검증은 [운영 적용 기록](lesson-submit-idempotency-rollout-2026-11-02.md)에 남겼다.

1. Backend: 새 제출/완료 결과 조회 계약, 완료 영수증 테이블과 Alembic, 기존 레슨 의미를 유지한 단일 transaction·mutex, 실제 PostgreSQL 동시성·rollback 회귀.
2. Mobile: 단일 checkpoint V2에 ID·계정·동결 답안을 저장한 뒤 POST, 같은 ID 복구, 기존 pending·계정 전환·콘텐츠 변경·구 앱 reader 회귀.
3. Shared: 승인된 Alembic을 격리 로컬 DB에 적용한 뒤 Prisma introspection·OpenAPI 생성 타입, 직접 소비자 검증.
4. 통합: 실제 FastAPI·PostgreSQL·Flutter QA 시뮬레이터에서 응답 유실·재시도·완전 재실행·원래 결과 복구와 중복 쓰기 방지 확인.
5. 독립 검토·필수 검사·PR 정리. 운영 배포와 운영 마이그레이션은 별도 후속 단계로 구분한다.

## 보존 경계

별도 loopback PostgreSQL 17과 합성 QA 계정/레슨을 사용한다. 운영 DB·로그인 토큰·기록·복습 기한·음원 캐시·권한·Data API·클라우드 설정을 변경하지 않는다. 기존 시뮬레이터의 로그인을 교체하지 않고 별도 QA 시뮬레이터를 사용한다. 운영 키·토큰을 QA 앱에 넣지 않는다.

## 어떤 문제를 어떻게 해결했는가

기존 제출은 답안만 받아 SRS·review event·시도 횟수를 갱신했다. 서버가 commit한 뒤 응답만 끊기면 앱은 성공 여부를 알 수 없었다. 무조건 재전송하면 학습이 두 번 반영되고, 재전송을 막기만 하면 결과를 복구하지 못한다. 서버 진도 시각도 다른 기기의 학습으로 바뀔 수 있어 특정 제출의 성공 증거로 쓸 수 없다.

이번 구현은 네트워크 요청의 전송 횟수와 사용자의 학습 시도를 구분한다. 앱이 처음 만든 UUID·계정·답안·응답 시간을 저장하고, 서버는 같은 계정/ID를 한 번만 처리한다. 성공 결과는 학습 반영과 같은 transaction에서 저장한다. 재시도는 최초 결과를 돌려주고, 사용자가 완료 뒤 진짜 재학습할 때만 새 ID를 만든다. 한 레슨 안에서 같은 문법을 여러 문항으로 평가하는 기존 정책은 바꾸지 않았다.

## 구현한 계약·저장·보안

- 새 `POST /api/v1/lessons/{lessonId}/submissions`: 필수 `submissionId` UUID v4·`expectedUserId`·동결 답안. 최초/재시도 모두 `200 {submissionId, processedAt, result}`로 원래 전체 결과를 반환한다.
- 새 `GET /api/v1/lessons/{lessonId}/submissions/{submissionId}?expectedUserId=...`: 본인의 완료 결과만 읽는다. GET 404는 아직 commit되지 않은 POST의 부재를 보장하지 않으므로 새 ID를 발급하지 않는다.
- 계정 불일치 403·같은 ID의 다른 레슨/답안/순서/응답 시간 409·일시 장애/결과 불명 503을 구분한다. 새 경로의 인증·검증·정상·오류 응답에 `Cache-Control: private, no-store`를 적용한다.
- 새 빈 `lesson_submissions` 테이블은 `(user_id, submission_id)` PK와 완료 결과 JSON을 가진다. 사용자 삭제 FK만 두고 lesson FK는 의도적으로 생략해 콘텐츠 삭제 후에도 원래 결과를 복구한다. 지속 PROCESSING 행·TTL·백필은 없다.
- Alembic `o5p6q7r8s9t0`는 기존 head `n4o5p6q7r8s9` 다음이다. owner·guard·빈 PostgREST 스키마를 먼저 검증하고 RLS 활성·클라이언트 유효 권한 0을 확인한다. 예상 밖 기존 객체를 덮어쓰지 않는다. 새 역할·환경 변수·production dependency는 추가하지 않았다.
- 서버는 현재 레슨을 읽기 전에 영수증을 조회하고, 없을 때 사용자 `FOR NO KEY UPDATE` mutex → 재조회 → 기존 학습 처리 → 영수증과 단일 commit 순서로 실행한다. legacy submit/start도 같은 mutex를 쓰며 기존 wire/SRS 의미를 유지한다.
- **ID 없는 기존 submit 경로의 재전송은 여전히 서버 멱등 보장 대상이 아니다.** 구 앱 호환을 유지하되 새 앱은 구 경로로 fallback하지 않는다. 과거 pending·attempts로 ID를 추정하거나 기록을 소급 수정하지 않는다.

## 앱의 재시도·결과 복구

기존 `lesson_checkpoint.v1.<account>.<lesson>` key 하나에 V2 envelope를 저장한다. 안전한 난수 UUID와 깊게 복사한 답안·응답 시간을 **POST 전에 저장**하며, 저장 실패면 POST 0회다. 같은 키의 pending 표시가 이전 reader에서도 초기화·재제출을 막는지 fixture로 확인했다.

재시도는 GET부터 수행하고, 없을 때만 같은 ID/body로 명시적 POST를 한다. 두 경로의 자동 인증 갱신·네트워크 재시도는 비활성화하고 await 전후 계정/generation을 확인한다. 다른 계정의 요청이나 늦은 응답이 현재 계정에 반영되지 않는다.

완전 재실행은 현재 detail/content signature 검사 전에 V2를 읽는다. 삭제되거나 목록에 없는 레슨도 “제출 결과 확인”으로 진입하며, 복구 화면은 현재 문항에 과거 결과를 억지로 연결하지 않는다. 최초 점수와 “제출 당시” 시각을 표시하고 최신 복습 기한처럼 재계산하지 않는다. ack 저장·삭제 실패 때도 ID를 유지하며, 이미 ack된 결과는 조회만 가능하다. 확정 완료 뒤 화면 종료/재진입 또는 명시적 재학습은 다른 UUID를 발급한다.

## 회귀·소비자 검증

| 범위                    | 실제 결과                                                                                                                                                  |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| API 전체                | 1,211 통과, 기존 Wave 1 DB fixture 미구현 13개 skip, 실패 0                                                                                                |
| 신규 실제 PostgreSQL    | 21개 모두 실행·통과, skip 0. 마지막 보존 보강 뒤 21개 재실행 통과                                                                                          |
| 기존 레슨·매핑·SRS 비교 | 초기 영향 범위 125개 통과. 기존 문항별 반복 문법 갱신 의미 유지                                                                                            |
| DB 보존                 | migration 전에 합성 auth/user·레슨·진도·단어/문법 기한·review event·TTS 캐시 생성. upgrade→빈 downgrade→re-upgrade 동안 기존 행 SHA-256·보안 metadata 동일 |
| 원자성·동시성           | 20개 동시 최초 제출, 별도 연결 재시도, GET/POST 경합, 잠금 timeout, 사용자 간 병렬, 중간 5지점 실패 rollback, commit 응답 유실 모두 통과                   |
| 콘텐츠/격리             | 수정·비공개·삭제 뒤 원래 결과, 403/404/409·손상/unknown schema fail closed 통과                                                                            |
| API 정적 검사           | Ruff·format 312파일, Mypy 178파일 통과                                                                                                                     |
| 모바일 전체             | Flutter 3.41.3 전체 962개 통과. 이후 테스트 2개 추가 및 마지막 보강은 영향 범위 51개 재검증 통과                                                           |
| 모바일 정적 검사        | analyze 문제 0, format 582파일 0변경, 기존 lockfile 유지                                                                                                   |
| 계약·공유 패키지        | OpenAPI 103→105경로, 삭제 0. 모바일 61 Dio 호출·3 annotated model 일치. 생성 TS 300줄 추가·Prisma 18줄 추가, 기존 계약 삭제 0                              |
| Prisma                  | 격리 DB의 `pnpm db:sync`·validate/generate·drift 0·database lint 통과                                                                                      |
| 직접 소비자             | types lint, web/admin typecheck와 webpack build 통과(83/11페이지)                                                                                          |
| CI 필수 회귀            | 새 PostgreSQL 21개를 추가해 152→173개 실행 필수. 실제 전체 JUnit으로 gate 통과, 누락/skip/중복/실패를 거절하는 checker 자체 테스트 10개 통과               |

전체 모바일 964개를 재실행했다고 표현하지 않는다. API의 기존 skip 13개를 새 테스트 생략으로 혼동하지 않는다. backend/mobile 독립 소스 검토에서 추가 P1/P2는 없었고, 제안된 migration 전 기록 비교와 확정 결과 후 새 UUID 회귀를 보강했다.

### 도구·환경 차이에서 잡은 검증 문제

원래 체크아웃의 Python editable install이 export 스크립트에서 먼저 잡혀, 처음 생성한 OpenAPI가 오래된 102경로를 읽는 드리프트를 공유 패키지 검증에서 발견했다. 현재 worktree의 `PYTHONPATH`를 명시하고 `app.__file__`·`lesson_submission.__file__`을 확인해 105경로로 다시 생성했다. 현재 결과는 기존 경로 삭제 0이며 로컬 QA 서버도 105경로다. 잘못 생성된 삭제 diff는 채택하지 않았다.

PR #212의 첫 CI 계약 검사는 최종 오류 DTO·상태별 응답을 추가한 뒤 TypeScript 생성을 다시 수행하지 않은 누락을 잡았다. 마지막 OpenAPI에서 타입을 재생성하고 별도 임시 파일로 생성한 결과와 바이트 단위 일치, types lint와 web/admin typecheck를 확인했다. 런타임·앱·DB 변경은 없었다. 최종 생성 타입은 main 대비 300줄 추가·삭제 0이다.

설치된 Flutter 3.47.2는 기존 lucide_icons와 맞지 않아 공식 3.41.3 tag `48c32af0`를 임시 SDK로 복원했다. 프로젝트 dependency·lockfile을 올리지 않았다. Xcode QA 전용 비추적 xcconfig에서만 simulator target 15/arm64를 지정했다. 자동 CocoaPods 실행이 바꾼 도구 버전 한 줄은 HEAD와 대조해 복구했다. App Store 릴리스 빌드 검증을 의미하지 않는다.

기존 node_modules 외부 symlink 때문에 기본 Turbopack은 package resolution에서 실패했다. 설정 변경 없이 지원되는 webpack 빌드로 web/admin 소비자를 검증했고, DB/API/Auth는 로컬/더미 주소, Sentry 업로드 비활성 조건이었다.

## 실제 QA 시뮬레이터 결과

별도 iOS 26.5 QA 기기와 loopback PostgreSQL 17·실제 FastAPI·현재 Flutter 바이너리를 사용했다. 합성 계정 2개·레슨 3개에 기존 완료 진도·복습 기한·TTS 캐시 sentinel을 넣었다. 실제 앱 이메일 로그인→로컬 GoTrue 호환 경계→서버의 실제 JWT 검증을 통과했다. 인증 dependency override는 없다. **운영 Supabase/OAuth 로그인 UAT와 구분한다.**

단어·문법·대화·이해 체크·매칭·문장 배열을 실제 렌더링된 위젯 callback으로 진행했다. provider·답안·진도·결과를 주입하지 않았고 제출은 HTTP→FastAPI→PostgreSQL을 통과했다. 시뮬레이터 native CUA 앱 연결이 불가능해 기존 debug VM 검사 방식으로 진행했으며 **OS 터치 hit-test 검증은 아니다.**

| 시나리오              | 실제 관찰                                                                                                                           |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| 처리 전 통신 실패     | 로컬 전송 경계에서 최초 POST 503. 직전/직후 학습 행 해시 동일, 완료 결과·event 추가 0                                               |
| 같은 제출 재시도      | 실제 버튼→GET 404→같은 ID·동결 body POST 200. 최종 3/3·100%, 시도 1회·영수증 1개·정상 SRS/event 3개                                 |
| commit 뒤 응답만 유실 | 다른 합성 레슨 POST는 실제 commit 후 응답만 503. 앱에는 미확정 안내, 서버에는 그 레슨의 시도 1회·영수증 1개                         |
| 디스크 저장           | 기존 checkpoint key 하나에 V2·pending true·같은 ID/body가 저장됐음을 확인                                                           |
| 완전 재실행           | 앱 프로세스를 종료하고 새 PID로 같은 설치 바이너리 실행. 로그인 유지, 학습 탭의 “제출 결과 확인” 카드 복원                          |
| 결과 복구             | 실제 카드에서 같은 ID GET 200. “레슨 제출 결과를 복구했어요”·3/3·최초 11:08 처리 시각 표시. 새 제출 POST 0·현재 lesson detail GET 0 |
| 복구 전후 DB          | commit 직후와 복구 후 **전체 QA 학습 행·복습 기한·시도·event·영수증 해시 동일**. 저장된 envelope도 최초 응답과 동일                 |
| 기존 보존             | 보호 대상 사용자·과거 완료 레슨·기존 복습 기한·TTS 캐시와 보안 카탈로그가 최초 기준과 동일                                          |

두 레슨의 의도적인 정상 학습으로 완료 결과 2개·event 6개를 생성했다. 이를 기존 기록 불변과 혼동하지 않는다. 각각의 재시도/복구가 추가로 만든 중복 반영은 0이다. 운영 학습 행은 조회하지 않았으므로 운영 전 사용자 해시 비교를 수행했다고 표현하지 않는다.

비식별 증거는 비공개 `/private/tmp/harukoto-lesson-idempotency-20261102/`의 `simulator-verification-safe.json`, `snapshot-*-safe.json`, `backend-junit.xml`, `backend-preservation-pg-junit.xml`, 모바일 검사 로그에 보관했다. 계정·토큰·접속 값·debug URI·원문 행은 저장소/PR에 넣지 않았다. 시뮬레이터 이미지 `qa-retry-success.png`, `qa-receipt-restored.png`도 같은 임시 경로에 있다. 임시 경로는 영구 보관소가 아니므로 핵심 결과와 한계를 이 문서에 기록한다.

## 후속 운영 적용과 롤백

1. 운영 적용 시 실제 Alembic head·owner·guard·빈 PostgREST 스키마·대상 객체 부재와 보존 기준을 먼저 확인한다. 예상 밖 상태면 중단한다.
2. 승인된 migration만 제한된 timeout으로 적용하고 RLS·유효 권한 0·기존 기록/기한/캐시·Data API 차단을 비교한다. 기존 기록 백필·재계산은 없다.
3. 서버를 배포하고 새 결과 reader/경로가 전체 트래픽에서 정상인 것을 확인한 다음 앱을 반영한다. 현재 main-push 배포 workflow 자체는 migration 단계를 포함하지 않으므로 병합만으로 DB가 준비됐다고 간주하지 않는다.
4. 운영 QA 제출·결과 복구·로그인·학습·이어하기와 Sentry를 확인한다. 이번 로컬 검증을 운영 검증으로 대체하지 않는다.

새 receipt가 생긴 뒤에는 테이블·결과 reader를 유지한 수정 배포가 기본이다. 실제 migration의 downgrade는 빈 테이블에서만 가능하고, 데이터가 있으면 거절한다. receipt 삭제·학습 기록 되감기·Data API 재개방·ID 없는 과거 pending 재전송은 롤백 수단이 아니다.
