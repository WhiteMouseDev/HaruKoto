# PR #215·#216·#217: CI 확인과 병합·운영 적용 순서

확인일: 2026-11-03 약 10:00 KST. 이번 요청은 CI·의존 관계 확인과 적용안 정리다. PR 병합/대상 브랜치 변경, workflow 실행/설정 변경, 운영 DB/클라우드 설정 변경, 배포·기기 업데이트는 하지 않았다. 새 문서만 작성한다.

## 확인한 CI와 브랜치 상태

| PR                                                         | 역할과 현재 head                                | 대상             | GitHub Actions                                                                    | Vercel Preview                         |
| ---------------------------------------------------------- | ----------------------------------------------- | ---------------- | --------------------------------------------------------------------------------- | -------------------------------------- |
| [#215](https://github.com/WhiteMouseDev/HaruKoto/pull/215) | 학습일/주간 집계 호환 OFF·폰트 복구, `3d1cdcec` | main             | [CI 862](https://github.com/WhiteMouseDev/HaruKoto/actions/runs/41419923336) 성공 | 앞선 검증에서 세 앱 성공               |
| [#216](https://github.com/WhiteMouseDev/HaruKoto/pull/216) | API·웹 학습일 gate ON 두 줄과 문서, `ef744b59`  | #215 작업 브랜치 | 해당 head의 실행 0개                                                              | 이번 확인에서 웹·관리자·랜딩 모두 성공 |
| [#217](https://github.com/WhiteMouseDev/HaruKoto/pull/217) | 완료 원자성·중복 방지·계정별 목표, `db28556a`   | #215 작업 브랜치 | 해당 head의 실행 0개                                                              | 이번 확인에서 웹·관리자·랜딩 모두 성공 |

세 PR 모두 draft/open/unmerged다. #217의 GitHub head별 전체 Actions 목록도 `total_count=0`으로 교차 확인했다. check-runs는 Vercel Preview Comments 성공 1개이며 상태 컨텍스트에 세 Preview 성공이 있다. 이는 전체 API/모바일 CI 성공을 뜻하지 않는다.

CI의 `.github/workflows/ci.yml`은 push/pull_request 모두 **main만** 대상으로 한다. #216·#217은 대상 브랜치가 `codex/lesson-study-day-compatibility`라 실행되지 않았다. 실패한 실행이나 재실행 대기 상태가 아니다. CI workflow 자체와 `Deploy API` workflow는 현재 모두 active다.

#215의 기존 CI는 changes·backend·schema-drift·api-contract·mobile(Android debug 포함)·admin-e2e·frontend 7개 job이 모두 성공했다. 이 head에는 #217이 없으므로 #217의 검증으로 대신하지 않는다. #217의 로컬 API 1,341/필수 PG 285/Flutter 1,064, 웹 신규 31/실제 PG 18 결과는 [구현 검증 기록](study-completion-safety-2026-11-03.md)을 따른다.

### CI에서 추가로 구분할 점

현재 frontend job은 lint·typecheck·build·폰트 검사를 수행하지만 **웹 Vitest를 실행하지 않는다.** 따라서 전체 CI가 성공해도 새 완료 회귀 31개가 CI에서 자동 실행됐다고 말할 수 없다. 권장 보완은 기존 frontend job에 다음의 집중 회귀 명령을 추가하는 소스 변경이다. 이번에는 workflow를 수정하지 않았다.

```sh
pnpm --filter web exec vitest run \
  src/__tests__/quiz-completion-atomicity.test.ts \
  src/__tests__/study-activity-routes.test.ts \
  src/__tests__/quiz-session-routes.test.ts
```

전체 웹 테스트에는 기존 실패 7개가 남아 있다. 이들을 숨기거나 이번 작업에서 임의로 정답을 바꾸지 않는다. 위 집중 회귀는 이번 완료 처리의 필수 검증으로 추가하고, 나머지 실패는 별도 정상화 대상으로 둔다. 실제 웹 PG 18개는 현재 수동 검증이며 새 CI 명령에 포함되는 검사와 다르다.

## 권장 소스 통합 순서

**#217 → #215 브랜치 통합 → 통합 OFF CI → #215 main 병합/통제된 OFF 배포 → 갱신한 #216 ON 검증·마지막 적용** 순서다.

1. 승인을 받은 뒤 #217을 현재 대상인 #215 작업 브랜치에 먼저 병합한다. #217을 main에 바로 retarget하거나 #215 단독 코드를 중간 운영 버전으로 사용하지 않는다. 이 단계는 운영 main을 바꾸지 않는다.
2. #215 head가 갱신되면 main 대상 PR의 synchronize 이벤트로 CI를 실행한다. API·모바일·schema/contract·웹 빌드/E2E와 위 웹 집중 회귀 결과를 **새 통합 head/검증 merge commit**에 대해 확인한다. 기존 #215 성공을 재사용하지 않는다. 새 OFF image digest·웹 deployment·모바일 build의 소스 일치를 기록한다.
3. #216은 현재 #217과 형제 브랜치다. #217을 포함한 OFF 기반으로 갱신해야 한다. API·웹 두 gate ON 외에 완료 보호나 계정별 목표가 빠지지 않았는지 diff/ancestry와 테스트로 확인한다.
4. #215를 main에 병합하는 시점은 아래 운영 전제 충족 뒤다. 자동 배포를 통제한 상태에서 #217 포함 OFF만 main에 넣고, 정확한 artifact를 수동 배포·승격한다. main 병합과 즉시 운영 배포를 분리한다.
5. OFF 안정화 뒤 #216을 새 main 기준으로 다시 정리하고 main 대상 PR로 바꿔 CI를 실행한다. squash/merge 방식에 따라 과거 commit이 중복되지 않게 확인한다. 최종 ON 코드에서 API·웹 두 gate가 True이고 #217 수정이 유지되는지 검증한다. 최종 diff는 활성화 두 줄과 필요한 문서로 제한한다.
6. 새 ON head의 CI·실제 ON 회귀·별도 격리 앱 검증과 운영 활성화 승인을 받은 뒤 #216을 마지막으로 main에 병합·배포한다. #216의 현재 Preview 성공은 #217 포함 ON 검증을 대체하지 않는다.

현재 CI 대상을 유지하면 위 순서로 #215와 갱신 #216에서 통합 CI를 얻을 수 있다. #217 자체에 병합 전 독립 Actions 결과가 꼭 필요하다면, 별도 소스 변경으로 CI에 stacked PR 대상 필터를 추가하거나 #217을 main 대상으로 바꾸는 안을 먼저 검토한다. 이번에는 이 설정이나 PR 대상을 변경하지 않았다.

## 운영 적용 전에 필요한 변경과 승인 대상

| 항목                   | 구체 변경안                                                                                                                              | 보존 조건과 복구 기준                                                                                                                        |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| DB p6                  | `daily_progress.activity_recorded BOOLEAN NOT NULL DEFAULT FALSE` 1컬럼과 비공개 `study_activity_receipts` 1테이블·관련 제약/인덱스 추가 | 기존 행 false·신규 영수증 빈 상태. 백필·기한/XP/목표 재계산 없음. 기존 owner·ACL·RLS·service_role 구분·빈 PostgREST schema·DDL guard 유지    |
| API 자동 배포          | 현재 active인 `deploy-api.yml`을 전환 중 일시 비활성화하고 승인한 commit/image digest만 수동 배포                                        | 원래 active 상태와 workflow ID 기록. 확인 후 enable하되, 대기 중인 main 변경이 예전 코드를 재배포하지 않는지 확인                            |
| Vercel production 전환 | 프로젝트의 production 자동 배포·승격을 일시 보류하고 검증한 OFF/ON deployment만 명시적으로 승격                                          | 기존 Git 설정·production alias·deployment ID snapshot을 보존. Preview 빌드와 production 승격을 구분                                          |
| 학습 저장 STOP bridge  | 현재 운영 schema/잠금 순서와 호환되는 별도 코드로 학습 writer 진입을 DB/AI 호출 전에 503+Retry-After·private/no-store로 중단             | 로그인·허용 GET·기존 영수증 조회·일반 음성 재생·결제 callback 유지. 로컬 답안/pending 삭제 금지. 아직 미구현                                 |
| 구 웹/서버 진입 차단   | Cloud Run 구 tag/revision과 웹 immutable/branch/alias/팀 접근의 학습 쓰기를 차단. WAF는 method+명시적 path/host allow/deny 목록으로 설계 | 설정 JSON·host/revision 목록과 기존 설정 snapshot을 변경 전 제시. 구 host 차단은 새 서비스 재개 뒤에도 유지. WAF 403과 앱 503 처리 차이 검증 |
| 구 실행 종료           | 새 진입 차단 뒤 진행 중 writer와 DB transaction/잠금 종료를 확인. 필요 시 특정 구 revision 종료/삭제                                     | 삭제 대상·보존 이미지·복구 가능성을 별도 승인. 관측 증거가 부족하면 마이그레이션 진행 중지                                                   |
| 활성화                 | #216의 API·웹 소스 플래그를 함께 False→True로 배포                                                                                       | 새 runtime env/Secret Manager key는 필요하지 않음. 롤백용 OFF artifact는 #217 수정 포함                                                      |
| 모바일                 | #217 포함 호환 빌드를 기존 앱 위에 업데이트                                                                                              | 앱 삭제/로그아웃/SharedPreferences 삭제 없음. 로그인·답안·checkpoint·pending·계정별 목표 복원 확인                                           |

#217 자체에는 추가 DDL·API 필드·runtime env가 없다. 필요한 DB 변경은 #215에 포함된 p6다. 기존 영수증 테이블의 client 권한을 열거나 Data API를 재활성화하는 작업은 없다. 새 비공개 영수증 테이블의 직접 접근 제한은 p6의 보안 구성이다.

### 정확한 실행 순서와 중단 조건

1. **읽기 전용 재조사·기준 보존:** DB head/마이그레이션 checksum, 데이터/기한/목표/음원·보안 fingerprint, 배포·tag·host 목록과 자동 배포/보호 설정을 읽는다. 11월 2일의 o5/p6 미적용·READY16개·alias55개는 과거 조사값이며 현재 상태로 단정하지 않는다. 이번에는 운영 DB·GCP/Vercel 설정을 다시 조회하지 않았다.
2. **자동 배포 통제 후 legacy STOP 적용:** STOP bridge는 현재 구 schema/잠금 코드로 별도 구현·검증해야 한다. #215/#217의 새 ORM·잠금을 섞어서 STOP보다 먼저 올리지 않는다. 퀴즈 start도 이전 세션 자동 완료/보상을 수행하므로 차단 대상이다.
3. **구 진입 차단과 실제 종료 확인:** 로그인 등 허용 기능은 유지한다. Cloud Run traffic100%·Retired·504·로그 부재·고정 sleep만으로 종료를 판정하지 않는다. Cloud Run timeout 뒤에도 컨테이너가 요청 처리를 계속할 수 있다는 [공식 문서](https://docs.cloud.google.com/run/docs/configuring/request-timeout)를 따른다. Vercel도 실제 함수 한도·마지막 invocation/종료 기록·DB 상태를 함께 확인한다. 정확한 통제 JSON/대상과 종료 증거를 얻지 못하면 NO-GO다.
4. **p6만 지정 적용:** `alembic upgrade p6q7r8s9t0u1`을 검토된 연결로 실행하는 안이다. migration 안의 lock2초/statement15초 제한을 유지한다. head가 o5가 아니거나 checksum/권한 전제가 다르면 덮어쓰지 않고 중단한다. 실패는 원자적으로 롤백하고 원인부터 확인한다.
5. **보존 검사 후 통합 OFF 배포:** 새 마커/빈 영수증과 기존 기록·권한 보존을 확인한다. #217 포함 #215 main 병합은 자동 배포 통제 안에서 하고, 정확한 API image를 무트래픽 배포·웹 deployment를 준비해 검증 후 승격한다. 고의 쓰기 검증은 별도 시험 계정·승인된 활동으로 제한한다.
6. **새 OFF 경로 재개와 모바일 검증:** 구 host 차단을 유지하고 새 writer만 재개한다. 로그인·완료 중복/실패 복구·기존 학습/복습/음성/이어하기·계정별 목표를 확인한다. 모바일은 기존 앱 위 업데이트로 검증한다. 읽기/음성이 유지된다고 학습 저장 중지 시간이 0이라고 약속하지 않는다.
7. **최종 ON 검증 후 별도 활성화:** #216 갱신·main 대상 CI·실제 ON 정책 테스트를 확인한다. 승인 뒤 활성화하고 첫 정답/오답·재전송·응답 유실·KST 경계·재실행 복원·오늘 목표/주간 통계를 점검한다. 과거 출석을 소급 인정하지 않는다.
8. **안정화 후 설정 복구:** 오류율·잠금 대기·교착·pending 복구·중복 지급을 확인한다. 자동 배포/Git 설정을 원래 상태로 복구하되 구 immutable host의 writer 차단은 유지한다. 매일 09시 읽기 전용 파티션 점검도 유지한다.

STOP bridge 코드·현재 프로젝트에 맞는 WAF rule JSON/host 목록·구 runtime 종료 방식은 아직 준비가 끝난 운영 artifact가 아니다. [기존 전환안](study-day-font-fix-and-rollout-2026-11-02.md)에 필요한 범위가 있으며, 구현·격리 검증과 실제 설정안 확정이 선행돼야 한다. 기존 postgres owner 계정의 비밀번호/권한 변경으로 선택적 쓰기 중지를 대신하지 않는다.

## 단계별 롤백

| 실패 시점             | 기본 롤백                                                                                               | 하지 않을 동작                                             |
| --------------------- | ------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| source 통합/CI 단계   | draft 상태 유지, 검토 브랜치 수정. 운영은 기존 버전 유지                                                | 실패한 CI를 건너뛰고 main 병합/배포                        |
| p6 적용 전            | legacy STOP 또는 같은 구 schema/잠금의 원래 artifact로 복귀. 차단·라우팅은 보존 snapshot 기준으로 복구  | 새 잠금 writer와 구 writer 혼용                            |
| p6 후, OFF 배포 문제  | 새 schema를 이해하고 #217의 중복 방지·원자성을 포함한 검증 OFF API/웹 artifact 유지 또는 수정 배포      | 취약한 #215 단독 artifact/옛 writer로 즉시 전환            |
| ON 후 인정 오류       | #217 포함 **OFF API·웹**으로 함께 되돌려 새 한 문항 인정만 중지. 기존 영수증 GET/학습·pending 복구 유지 | 이미 인정한 마커·영수증·연속일·학습 기록 삭제, 과거 재산정 |
| 모바일 표시/저장 문제 | 같은 저장 형식을 이해하는 #217 포함 수정 호환 빌드로 앱 위 업데이트                                     | 앱 삭제·로그아웃·키 삭제 또는 공통 목표 캐시로 강제 복귀   |
| 차단/배포 설정 문제   | 저장한 설정 snapshot과 검증 artifact로 복구하되 새/구 writer 경계를 유지                                | 구 host를 일괄 개방하거나 Data API 재활성화                |

DB downgrade가 기본 롤백은 아니다. p6는 영수증이 하나라도 있거나 `activity_recorded=true`가 있으면 downgrade를 거부한다. 완전히 미사용·빈 상태라도 별도 승인과 security 전제 확인 후에만 검토하며, 기본은 새 schema를 유지하는 OFF 복귀다. downgrade하려고 데이터를 지우지 않는다.

모바일 예전 바이너리는 새 계정별 목표 키를 모른다. 기존 공통 키가 보존됐다는 이유로 예전 바이너리를 안전한 목표 표시 롤백으로 간주하지 않는다. 계정별 목표 확인과 저장 위치/pending을 이해하는 호환 빌드를 기준으로 삼는다.

## 이번에 한 일과 다음 준비

이 문서 작성 뒤 사용자는 CI 보완과 별도 STOP PR 구현·격리 검증을 승인했다. 이후 #217의 [웹 완료 CI 보완](web-completion-ci-2026-11-03.md)과 운영 코드 기반 STOP PR을 준비한다. 아래의 ‘미구현’은 이 계획을 작성한 시점이며 운영 적용 승인은 계속 별도다.

GitHub PR/CI/배포 workflow 상태를 읽기 전용으로 확인했고, 로컬 코드·기존 검증 기록·공식 runtime 문서를 대조해 이 계획을 작성했다. 신규 API/DB/클라우드 변경을 실행하지 않았다.

다음 작업은 **웹 집중 회귀 CI 보완안과 legacy STOP bridge 구현·격리 검증, 정확한 운영 통제/복구 설정안 준비**다. #217→#215 통합 및 새 CI, #216 갱신도 승인된 소스 통합 단계에서 진행한다. 실제 운영 적용은 그 결과와 DB/설정 변경 대상을 제시한 뒤 별도 승인 범위로 다룬다.
