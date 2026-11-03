# 레슨 학습일 인정 구현·격리 검증

> **11월 2일 정책 갱신:** 사용자가 ‘한 문항에 답해도 학습일 인정’을 채택했다. 아래는 이전 **레슨 전체 완료 기준**의 구현·검증 이력이며 새 정책의 검증 결과가 아니다. 새 API·DB와 모바일/웹 연결은 [한 문항 인정 구체안](answered-study-day-policy-proposal-2026-11-02.md)을 먼저 확인한다. PR #215·#216은 draft·운영 미적용으로 유지하며 기존 완료 기준을 그대로 활성화하지 않는다.

## 승인과 작업 경계

2026년 11월 2일 사용자가 PR #214 병합과 [학습일 인정 A안](lesson-study-day-recognition-proposal-2026-11-02.md)의 구현·회귀·시뮬레이터 검증을 승인했다. 운영 적용 전 검증 결과·적용안을 먼저 보고하도록 했다. 기존 로그인·학습 기록·복습 기한·오늘 단어 목표·Data API 차단을 유지하며 과거 기록을 백필하지 않는다.

PR #214는 검증된 head `5b1cc3f6`로 2026-11-02 14:36:57 KST에 squash `363b1661` 병합했다. 구현은 해당 main 기준으로 시작했고 호환 `codex/lesson-study-day-compatibility`와 활성화 `codex/lesson-study-day-recognition` 두 브랜치로 나눈다. 이 병합은 모바일 복습 카드/문서 변경이며 이번 학습일 서버 기능을 운영에 적용한 것이 아니다.

## 구현 계획

1. backend-agent가 `daily_progress.lesson_completed BOOLEAN NOT NULL DEFAULT false`와 Alembic `p6q7r8s9t0u1`을 작성한다. 운영이 아닌 격리 PostgreSQL에서만 적용·보존·권한·반복/실패와 롤백 경계를 검사한다.
2. 새 멱등 제출 ID의 최초 정상 완료에만 학습일을 기록한다. 영수증·마커·연속일·기존 SRS 효과를 한 트랜잭션으로 묶는다. 과거 영수증·레거시 제출·GET/POST 재조회는 새 출석을 만들지 않는다.
3. API와 웹의 기존 연속일 writer를 사용자 행 → 도메인/세션 → 일별 행 순서로 직렬화하고 잠금 후 최신 필드를 읽는다. 기존 인증·XP·복습 정책·응답 형식을 유지한다.
4. shared-packages-agent가 새 마이그레이션을 적용한 별도 로컬 DB에서 `pnpm db:sync`로 Prisma를 미러링한다. 새 Prisma client는 새 컬럼을 기본 조회할 수 있으므로 운영 마이그레이션 선행이 필요하다.
5. 실제 PostgreSQL 회귀와 CI 무스킵 gate, API/웹/직접 소비자 검사, 현재 모바일 소비자 계약과 전체 회귀를 확인한다.
6. 별도 시뮬레이터·합성 계정·로컬 서명 인증·실제 로컬 FastAPI/PostgreSQL에서 서버 처리 전 실패 재시도와 commit 뒤 응답 유실·완전 재실행 복구를 검사한다. 원래 시뮬레이터·실물 아이폰·운영 계정에 접근하거나 설치하지 않는다.
7. 결과·한계·운영 마이그레이션/배포 순서·롤백안을 기록하고 PR을 제출한다. 새 구현 PR의 main 병합·운영 DB 적용·서버/웹 배포는 이번 작업의 승인 범위가 아니다.

비밀 값·토큰·연결 문자열·사용자 원문 행·debug URI는 저장소/PR에 넣지 않는다. 검증용 로컬 파일은 `/private/tmp/harukoto-study-day-recognition-20261102/`에 보관한다.

## 완료한 동작

`daily_progress.lesson_completed`는 같은 날 정상 완료를 한 번 이상 했는지를 나타낸다. 기존 고유 키 `(user_id, date)`를 사용하며 UPSERT의 UPDATE는 이 불리언만 `true`로 만든다. 기존 단어·문법·퀴즈 수·XP를 임의로 늘리거나 덮어쓰지 않는다. 기존 행의 새 값은 `false`이며 과거 레슨이나 영수증을 해석해 채우지 않는다.

새 멱등 제출의 첫 `COMPLETED` 처리에서만 기존 SRS 효과·학습일·사용자 연속일·영수증을 함께 commit한다. 유효한 0점 완료도 인정하지만 시작·중단·실패는 인정하지 않는다. GET·같은 ID POST·과거 영수증·구형 `/submit`에는 새 학습일을 만드는 효과가 없다. 활성화 전 OFF 버전에서 처리한 영수증도 나중에 출석으로 바꾸지 않는다.

기존 FastAPI `today.hasStudied`, `weeklyStats[].hasStudied`, history의 `hasStudied`와 저장 연속일을 사용한다. 새 엔드포인트·요청/응답 필드는 없다. 웹의 다섯 활동 writer는 같은 잠금에 참여하지만 **웹 BFF 달력 응답 확장**은 별도 미승인 범위로 남긴다. 기존 `totalStudyDays`의 전체 일별 행 집계 정의도 변경하지 않았다.

동시 완료는 API 퀴즈·가나·회화와 웹의 대응 다섯 경로가 사용자 `FOR NO KEY UPDATE` → 도메인/세션 → 일별 행 순서를 공유하도록 했다. 인증 시점의 오래된 User 값 대신 잠금 후 활동 필드만 새로 읽는다. 퀴즈 시작 시 기존 미완료 세션 자동 완료의 XP writer도 참여한다. 이를 모든 미션/보상 writer의 동시성까지 해결했다고 표현하지 않는다. 미션 XP 지급의 기존 별도 처리와 보상 정책은 이번 범위에 포함하지 않는다.

## 실제 검증에서 찾은 보완점

- **KST 자정과 밀리초 반올림:** 기존 `users.last_study_date`는 UTC-naive `TIMESTAMP(3)`다. 자정 직전 마이크로초가 DB에서 다음 날로 반올림될 수 있었다. 새 공통 처리 시각은 UTC 밀리초 아래를 버린 후 영수증·날짜·연속일에 동일하게 사용한다. 기존 컬럼 형식이나 과거 시각은 바꾸지 않는다.
- **가나 단계의 필수 시각:** 실제 PostgreSQL 회귀에서 완료/다음 단계 해제의 Core UPSERT가 기존 `updated_at NOT NULL`을 빠뜨리는 것을 확인했다. 두 경로에 완료 시각을 명시했으며 DB default 추가나 과거 데이터 보정은 하지 않았다.
- **운영 권한 전제:** 최초 마이그레이션 초안은 `service_role`에도 기존 접근이 없다고 잘못 가정했다. 기존 보안 적용안은 신뢰하는 서버 전용 `service_role`을 보존한다. 독립 검토 결과에 따라 기존 ACL을 보존하고 PUBLIC·anon·authenticated 차단을 유지하는 검증으로 수정했다. 권한을 자동 REVOKE/GRANT하여 전제를 맞추지 않는다.
- **구형 마이그레이션 테스트:** 새 모델의 Python default를 과거 스키마에 INSERT하면 아직 없는 컬럼을 쓸 수 있었다. 새 필드는 DB server default로만 선언해 과거 마이그레이션 fixture를 변경하지 않고 검사한다.

## 시뮬레이터 검증 결과

기존 사용자/기기와 분리한 `HaruKoto Study Day QA` 시뮬레이터, Flutter 3.41.3, 합성 계정과 합성 N5 콘텐츠를 사용했다. 앱의 실제 로그인·네트워크·레슨 제출·체크포인트 흐름과 최종 ON 소스를 로컬 FastAPI/PostgreSQL에 연결했다. 로컬 GoTrue 테스트 응답과 실제 서명 JWT 검증을 사용한 것으로, **운영 Supabase 로그인 검사로 확대하지 않는다.** 네이티브 화면에서 답안을 직접 선택했고 음성 provider 호출은 하지 않았다.

| 시나리오                              | 실제 결과                                                                                                   |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| 첫 제출이 서버 처리 전에 503          | 완료 영수증 0, 학습일 0, 실패 전후 전체 활동 해시 동일                                                      |
| 같은 답안으로 재시도                  | 같은 ID GET 404 → POST 200, 3/3 결과, 해당 레슨 시도 1회·영수증 1개·연속 학습 1일                           |
| 같은 날 다른 레슨의 저장 후 응답 유실 | 실제 트랜잭션은 성공하고 앱에는 503, 영수증 총 2개·각 시도 1회, 오늘 학습일은 여전히 하나                   |
| 앱 프로세스 완전 종료·재실행          | 로그인 유지, 저장 카드에 ‘제출 결과 확인’ 표시                                                              |
| 저장 카드에서 원래 결과 복구          | 같은 ID GET 200 **1회**, 추가 POST **0회**, 원래 3/3 결과와 최초 처리 시각 복구                             |
| 복구 전후 DB 비교                     | 전체 활동·SRS 기한·영수증 처리 시각 해시 동일, 연속일 추가 증가 0                                           |
| 화면 반영                             | 홈 ‘1일 연속 학습 / 오늘 학습 완료’, 11월 2일 달력 ‘학습 완료’                                              |
| 다른 정책 보존                        | XP 300, 목표 20, 오늘 단어 **0/20·0%**, 해당 수치와 미션 집계 부풀림 없음                                   |
| 보호 대상 보존                        | 다른 계정·과거 일별 행·기존 별도 SRS·기존 완료 레슨·음원 fixture 해시 동일; ACL/RLS/Data API 설정 해시 동일 |

새로운 정상 시도 자체의 SRS 갱신은 기존 정책대로 일어난다. ‘복습 기한 보존’은 정상 학습 효과까지 없애는 뜻이 아니라, 보호한 기존 대상과 같은 제출의 재시도/복구가 기한을 추가로 변경하지 않는다는 뜻이다. 다음 날 동일 ID 복구와 0점·동시 완료·월/연 경계는 아래 실제 PostgreSQL 회귀로 확인했다. 시뮬레이터 시계를 조작해 다음 날 운영 출석을 만들지는 않았다.

시뮬레이터 결과·홈·달력 PNG와 단계별 비교 자료는 검증용 private 디렉터리의 `sim/`에 있다. 소스 상수는 QA 당시 ON이었으며, 호환 PR에서는 OFF로 분리한다. 인증 의존성·채점·학습일 로직을 mock하여 통과시킨 시뮬레이터 검증이 아니다. 실패 주입은 로컬 HTTP 경계에서 한 번씩만 수행했다.

## 검증 범위와 한계

| 검사                       | 결과                                                                                                                                               |
| -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| API 전체                   | 최종 호환 OFF 소스에서 **1,258 통과**, 기존 Wave-1 관리자 fixture 미구현 13 skip                                                                   |
| 신규 실제 PostgreSQL 회귀  | **37개 통과**, 기존 trusted service_role 권한 보존 사례 포함                                                                                       |
| 필수 PostgreSQL JUnit gate | **210개 통과·skip 0**; 삭제/누락/skip/failure를 거부하는 gate 자체 10개 통과                                                                       |
| Ruff / mypy                | 316파일 포맷·lint, 179개 소스 타입 검사 통과                                                                                                       |
| API 계약                   | OpenAPI 105개 경로 스냅샷 동일, 모바일·관리자 계약 검사 통과                                                                                       |
| 웹 관련 회귀               | 새 writer/기존 퀴즈/KST 관련 85개 통과                                                                                                             |
| 웹 전체                    | 233개 통과, **기존 baseline 실패 7개**: gamification 상수 기대 2개·stats UI 라벨 기대 5개. 병합 기준 `363b1661` 별도 archive에서도 동일 실패 확인  |
| 웹 정적 분석·빌드          | lint·typecheck 통과, 공식 Next webpack 빌드 통과. 이 worktree의 기본 shim/Turbopack symlink 제약으로 webpack 사용; 제품 설정 변경 없음             |
| 모바일                     | 전체 **988개**, 관련 소비자 72개 통과; analyze 0문제·585파일 포맷 변경 0·추적/환경/잠금 687개 해시 동일                                            |
| Prisma                     | Alembic 적용 로컬 DB에서 `db:sync`, validate/generate/build/lint/드리프트 검사 통과; 실제 생성 client에서 마커 기본값/일반 카운터 UPSERT 보존 검사 |

API, 모바일, CI gate 수는 서로 다른 검사다. 중복 실행을 합쳐 하나의 테스트 수로 과장하지 않는다. 웹 전체가 모두 통과했다거나 운영 계정·실기기를 확인했다고 쓰지 않는다. 기존 웹 실패 7개는 이번에 무관하게 수정하지 않았다.

최종 마이그레이션 SHA-256: `bfed009c9bc138755f3d6c846cacd375ce3a8940cf9d6548bdfccf98e67b0c4b`. 최종 API JUnit은 `/private/tmp/lesson-study-day-api-compat-off.xml`이며 source OFF/ON 회귀 모두 명시적으로 검사한다. 독립 최종 코드 검토에서 미해결 P0/P1/P2 지적은 없다.

### 검토 PR과 원격 검사

- [PR #215](https://github.com/WhiteMouseDev/HaruKoto/pull/215)는 호환 OFF 버전이다. 코드 커밋 `36b0dfe3`의 [GitHub CI](https://github.com/WhiteMouseDev/HaruKoto/actions/runs/41399407622)에서 frontend·admin-e2e·backend·api-contract·schema-drift가 모두 통과했다. 모바일 소스 무변경으로 원격 mobile job은 skip이며, 위 로컬 988개 검사는 별도 수행했다.
- [draft PR #216](https://github.com/WhiteMouseDev/HaruKoto/pull/216)은 #215 기반 활성화 한 줄이다. 실제 ON 소스·최종 마이그레이션의 PostgreSQL 37개+단위 10개, 총 **47개 통과**를 확인했다. main 대상만 CI를 실행하는 현재 규칙 때문에 이 stacked draft에는 원격 CI가 실행되지 않는다. #215 squash 병합 후 main으로 rebase·base 전환하고 CI를 다시 확인해야 한다.
- PR #215의 Vercel 웹 미리보기는 통과했고 landing은 ignore 규칙으로 취소·성공 처리됐다. **관리자 Vercel 미리보기 1개는 폰트 빌드 실패로 남는다.** 변경하지 않은 Noto Sans JP import에서 Google의 확장자 없는 URL과 Next 16.1.6 Turbopack의 쿼리 파싱 결함이 만났다. 이 결과를 ‘모든 원격 검사 통과’라고 쓰지 않는다.
- 관리자 폰트 이슈는 [upstream #99114](https://github.com/vercel/next.js/issues/99114)·[수정 PR #100158](https://github.com/vercel/next.js/pull/100158)과 맞으며, webpack도 해당 URL의 확장자를 가정해 단순 bundler 전환을 영구 해결책으로 삼지 않는다. 로컬/원격 GitHub 빌드 성공과 별개인 간헐적 외부 폰트 빌드 위험이다. [별도 판단 기록](../../../.planning/escalations/2026-11-02-admin-preview-font-build.md)에 비운영 재확인·장기 개선안을 남겼다. 이번 범위에서 Next 의존성·브랜드 폰트·Vercel 설정·운영 배포는 바꾸지 않았다.

## 운영 적용안 — 아직 실행하지 않음

한 번의 코드 배포로 인정을 켜지 않는다. 새 컬럼과 호환 writer/reader를 배포하는 **호환 PR(소스 상수 OFF)**, 인정을 켜는 **활성화 PR(True 한 줄)**로 나눈다. 이는 새 환경 변수·원격 설정이 아니라 코드 변경 두 단계다.

1. **읽기 전용 사전 감사:** 실제 Alembic head가 `o5p6q7r8s9t0`인지, 새 컬럼 부재·owner·RLS·DDL guard·권한·Data API 차단을 확인한다. 기존 행은 새 컬럼을 제외한 원래 컬럼 투영으로 수/키/해시·SRS 기한을 보관하고 별도 음원 캐시·Kenzo/Shizuka 설정·학습 기록도 비교 기준으로 둔다. 전제가 다르면 중단하며 임의 권한 수정은 하지 않는다.
2. **승인 마이그레이션 적용:** `p6q7r8s9t0u1`만 적용한다. 새 필드는 `BOOLEAN NOT NULL DEFAULT FALSE` 하나이며 백필 SQL은 없다. 마이그레이션은 2초 lock timeout·15초 statement timeout으로 실패 시 전체 취소한다. 구 컬럼/권한/RLS/Data API·기존 기한을 전후 비교하고 기존 행 새 마커가 전부 false인지 확인한다.
3. **호환 웹·API 배포:** OFF 버전의 공통 writer/reader를 배포한다. OFF라도 SQLAlchemy/Prisma는 새 컬럼을 SELECT하므로 **DB 마이그레이션이 반드시 먼저**다. 로그인·조회·기존 제출/영수증·기한·목표를 확인한다. 이 단계 새 완료는 기존 SRS 처리만 하고 출석을 만들지 않는다.
4. **구 writer 종료 확인:** Cloud Run 트래픽 100%와 잠시 대기만으로 끝났다고 판단하지 않는다. 기존 장시간 AI 요청은 proxy timeout 뒤에도 컨테이너에서 계속 실행될 수 있다. 구 revision의 tag/direct URL·구 웹 배포 URL/alias 등 인증된 쓰기 진입 가능성과 진행 중 실행을 읽기 전용으로 확인하고, 구 handler/process 및 DB 트랜잭션 종료 증거가 있어야 활성화한다. 구 revision/웹 배포를 정리하거나 접근을 막아야 한다면 **대상·영향·명령·복구 방법을 먼저 제시하고 추가 승인**을 받는다. 단순 로그 부재/고정 sleep을 종료 증거로 쓰지 않는다.
5. **활성화 PR 배포:** 구 writer 종료 조건이 충족된 뒤 True 한 줄을 main에 반영·배포한다. 기존 OFF 영수증은 소급 인정하지 않고 이 시점 이후 새 완료만 인정한다. 실제 운영 검증은 사용자가 승인한 전용 QA 계정/시뮬레이터로 수행하며 기존 사용자 기록은 건드리지 않는다.
6. **사후 검증:** 정상 완료 → 오늘/주간/달력/프로필, 동일 ID 재조회/응답 유실/재실행, 오늘 단어 목표·기존 SRS·음원/권한/Data API 보존을 검사한다. 적용 revision과 시간 범위를 붙여 ERROR/5xx·Sentry를 읽기 전용 확인한다. 시뮬레이터 로컬 결과를 운영 결과로 대신하지 않는다.

구 writer 종료 기준의 근거: [Cloud Run request timeout](https://docs.cloud.google.com/run/docs/configuring/request-timeout)은 504가 컨테이너의 요청 처리를 종료시키지 않을 수 있다고 명시한다. [container shutdown 계약](https://docs.cloud.google.com/run/docs/container-contract#instance-shutdown)과 실제 runtime 상태를 함께 확인해야 한다. 현재 저장소 배포 설정만으로 운영 종료를 이미 증명할 수는 없다.

### 롤백

- 활성화 후에는 **새 컬럼을 이해하는 호환 OFF 버전**으로 되돌려 새 인정을 중지한다. 이미 저장한 마커·영수증·연속일은 남긴다.
- 원래 구버전 writer로 무조건 돌아가지 않는다. 잠금/최신 값 읽기를 잃으면 인정된 연속일이 덮어써질 수 있다.
- 마커가 true인 행이 있으면 downgrade가 명시적으로 거부한다. 컬럼 삭제·기록 삭제·SRS 재계산·Data API 재개방은 롤백 방법이 아니다.
- 마커가 전부 false여도 reader 배포 상태 확인과 별도 DB 승인 없이 downgrade하지 않는다. 운영에서는 컬럼을 유지한 호환 배포를 우선한다.

**현재 승인 대기:** 운영 마이그레이션, 호환 PR 병합/배포, 구 writer 종료를 위한 구체적인 클라우드 작업(필요 시 별도안), 활성화 PR 병합/배포. 이번에는 PR #214 병합과 격리 구현·검증만 수행했다.
