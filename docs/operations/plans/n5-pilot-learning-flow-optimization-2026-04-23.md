# N5 파일럿 학습 플로우 고도화 계획

> 작성일: 2026-04-23
> 대상: N5 Ch.01-Ch.06 파일럿 레슨
> 주 표면: Mobile
> 목적: 전체 JLPT 콘텐츠 확장 전에 학습 플로우, 진행 상태, 복습 연결 설계를 제품 수준으로 검증한다.

## 1. 배경

현재 레슨 시스템은 모바일과 백엔드의 해피패스가 연결되어 있다.

- 데이터: `packages/database/data/lessons/n5/`
- 범위: N5 6챕터, 30레슨, 150문항
- API: `/api/v1/lessons/chapters`, `/api/v1/lessons/{id}`, `/start`, `/submit`, `/review/summary`
- 모바일: 챕터 목록, 레슨 상세, 가이드 리딩, 인식 문제, 매칭, 문장배열, 결과 제출

이번 작업의 목표는 N4-N1까지 데이터를 늘리는 것이 아니다. N5 일부 데이터를 파일럿 세트로 고정하고, 학습 경험과 시스템 가드레일이 실제 운영 가능한 구조인지 검증한다.

## 2. 파일럿 범위

### 포함

- N5 Part 1 파일럿: Ch.01-Ch.06
- 모바일 학습 탭의 체계적 학습 영역
- 레슨 시작, 제출, 완료, SRS 등록, 복습 CTA
- 개발/스테이징 환경 seed 절차
- 서버/모바일 계약 검증

### 제외

- N4-N1 레슨 확장
- 웹 레슨 화면 구현
- 새 DB 스키마 설계
- 타이핑, STT, 고급 음성 피드백
- 한자/후리가나 점진 제거 정책

## 3. 파일럿 성공 기준

파일럿은 아래 조건을 만족해야 한다.

| 영역 | 성공 기준 |
|------|-----------|
| 데이터 로딩 | 새 개발/스테이징 환경에서 N5 6챕터와 30레슨이 재현 가능하게 seed된다. |
| 진입 | N5 사용자는 학습 탭에서 첫 미완료 레슨으로 자연스럽게 진입할 수 있다. |
| 진행 | 시작 실패, 제출 실패, 네트워크 실패가 성공처럼 보이지 않는다. |
| 완료 | 모든 필수 문제에 답해야 `COMPLETED`가 된다. |
| 복습 | 레슨 완료 후 학습 아이템이 SRS에 등록되거나, 실패 시 재시도 가능한 상태로 남는다. |
| 상태 | 챕터/레슨 목록의 진행률이 제출 결과와 일치한다. |
| UX | 1레슨이 8-12분 안에 완료되고, 학습자가 다음 행동을 이해한다. |

## 4. 핵심 제품 결정

### 4.1 접근 정책

파일럿은 **추천 경로 + 자유 접근**을 기본 정책으로 한다.

- 모든 파일럿 레슨은 직접 진입 가능하다.
- 학습 탭은 첫 미완료 레슨 또는 최근 이어할 레슨을 **추천**한다.
- 챕터/레슨 순서는 "권장 학습 순서"를 나타내며, 접근 제한 규칙이 아니다.
- 권장 순서 밖 레슨에 진입해도 막지 않고, 필요하면 가벼운 안내만 표시한다.

이유: JLPT 학습자는 선행지식 편차가 크고, 이미 아는 범위를 건너뛰거나 필요한 문법만 골라 학습하려는 경우가 많다. 파일럿에서도 사용자의 자율성을 유지한 상태에서 추천 품질을 검증하는 편이 제품 방향과 더 잘 맞는다.

### 4.2 완료 기준

파일럿에서는 **정답률 컷 없이 전체 제출 완료**를 완료 기준으로 한다.

- 모든 서버 문항 order가 제출되어야 한다.
- 중복 order, 알 수 없는 order, 타입에 맞지 않는 payload는 400으로 거절한다.
- 점수는 기록하되 추천 상태와 진행률만 갱신한다.

정답률 컷은 학습 난이도 조정 후 도입한다. 초기부터 컷을 넣으면 콘텐츠 품질 문제와 사용자 실력 문제를 분리하기 어렵다.

### 4.3 SRS 정책

파일럿은 **레슨 완료와 SRS 등록을 강하게 연결**한다.

- SRS 등록 성공: 레슨 완료 커밋
- 일시 실패: 레슨 완료를 막거나, 명시적인 retry 상태를 남긴다.
- 조용히 실패하고 `COMPLETED`만 남기는 동작은 허용하지 않는다.

기존 edge-case 문서에는 SRS 등록 실패 시 레슨 완료를 허용하는 방향이 있으나, 파일럿에서는 복습 연결 품질이 핵심 검증 대상이므로 실패를 가시화한다.

### 4.4 공개 상태

lesson JSON의 `meta.status`는 파일럿 동안 아래 정책으로 정리한다.

- `PILOT`: 파일럿 공개 데이터, seed 시 `is_published=true`
- `PUBLISHED`: 운영 공개 데이터, seed 시 `is_published=true`
- `DRAFT`: 비공개 초안 데이터, seed 시 `is_published=false`

N5 Part 1 데이터는 `PILOT`으로 전환한다. `DRAFT` 데이터를 무조건 `is_published=true`로 올리는 방식은 허용하지 않는다.

## 5. 현재 갭

| 우선순위 | 갭 | 영향 |
|----------|----|------|
| P0 | 레슨 seed가 canonical DB seed와 분리되어 있음 | 새 환경에서 챕터 목록이 비어 파일럿 검증 불가 |
| P0 | `/lessons/{id}/submit`이 부분 제출을 완료 처리할 수 있음 | 사용자 진도와 SRS 상태가 오염됨 |
| P0 | 모바일이 lesson start 실패를 무시함 | 404/잠금/서버 오류가 성공처럼 보임 |
| P1 | 레슨/챕터 추천 상태가 API에 없음 | 자유 접근은 가능하지만 "지금 무엇을 하면 좋은지" 안내가 약함 |
| P1 | SRS 실패를 삼키고 레슨 완료 커밋 | 복습 연결 검증 불가 |
| P1 | sentence arrange quiz type 계약 불일치 가능성 | 스테이지 기반 문장배열 진입 실패 |
| P2 | 레슨 JSON validator 부재 | 데이터 확장 시 회귀 탐지 불가 |
| P2 | 웹은 레슨 표면 없음 | 파일럿이 mobile-only임을 명확히 해야 함 |

### 진행 현황

| 항목 | 상태 | 비고 |
|------|------|------|
| 레슨 JSON validator | 완료 | `pnpm --filter @harukoto/database lessons:validate` |
| 제출 계약 강화 | 완료 | 부분 제출, 중복 order, 타입 불일치 거절 |
| 모바일 시작 실패 UX | 완료 | `startLesson` 실패 시 practice 진입 차단 |
| 추천 경로 표현 | 완료 | 학습 탭 카드, 챕터 배지, 레슨 타일 강조 |
| N5 반복 UAT 계정 | 완료 | `test1@test.com` 원격 프로필 `N5` 고정 |
| SRS 실패 처리 | 완료 | SRS 등록을 answer processing 전에 수행하고, SRS 실패 시 500 반환 및 레슨 완료 커밋 차단 |
| DRAFT/PILOT 공개 정책 | 완료 | N5 Part 1은 `PILOT`, seed는 `PILOT`/`PUBLISHED`만 publish |
| 파일럿 seed 재현성 | 완료 | `pnpm seed:learning`이 Prisma 정적 콘텐츠 이후 lessons/study stages seed 실행 |
| 파일럿 이벤트 계측 | 완료 | 모바일 학습 홈/목록/레슨 세션/복습 CTA에서 `LessonPilotTelemetry` 이벤트 기록, 기본 sink는 Sentry breadcrumb로 수집 |
| 모바일 UAT 재실행 | 부분 완료 | Lesson 2/3 실제 완료 플로우와 핵심 계측 PASS, 결과 화면 SRS 안내는 위젯 계약 테스트 보강, review CTA 실기는 due 준비 커맨드로 재실행 가능 |

## 6. 실행 계획

### Phase 1. 파일럿 seed와 데이터 검증

목표: N5 파일럿 데이터가 모든 개발/스테이징 환경에서 재현 가능하게 로드되도록 한다.

작업:

1. `apps/api/app/seeds/lessons.py`를 공식 파일럿 seed로 문서화한다. 완료: `pnpm seed:learning`에 포함.
2. 개발/스테이징 setup 문서에 vocabulary/grammar seed 이후 lesson seed 실행 순서를 추가한다. 완료: README와 table ownership 문서에 반영.
3. lesson JSON validator를 추가한다.
4. validator를 CI 또는 최소한 로컬 검증 명령에 연결한다.

검증 규칙:

- `meta.lesson_count == lessons.length`
- `lesson_no`와 `chapter_lesson_no`가 연속
- 각 레슨 문항 수가 5개 이상
- `VOCAB_MCQ`, `CONTEXT_CLOZE`는 `correct_answer`가 options 안에 존재
- `SENTENCE_REORDER`는 `tokens`와 `correct_order`가 같은 원소 집합
- `vocab_orders`가 해당 JLPT vocabulary JSON에 존재
- `grammar.grammar_order`가 해당 JLPT grammar JSON에 존재
- `meta.status`가 허용된 값인지 확인

완료 기준:

- validator가 현재 N5 6챕터를 통과한다.
- seed 실행 후 `/api/v1/lessons/chapters?jlptLevel=N5`가 6챕터/30레슨을 반환한다.

### Phase 2. 제출 계약 강화

목표: 레슨 완료 상태가 신뢰 가능한 서버 상태가 되도록 한다.

작업:

1. 서버에서 lesson submit payload를 검증한다.
2. 누락 order, 중복 order, 알 수 없는 order를 거절한다.
3. 타입별 필수 필드를 검증한다.
4. `score_total`은 제출된 답 개수가 아니라 서버 문항 수 기준으로 계산한다.
5. 관련 API 테스트를 추가한다.

완료 기준:

- 일부 문항만 제출하면 400을 반환한다.
- 중복 order를 제출하면 400을 반환한다.
- 정상 5문항 제출만 `COMPLETED`가 된다.

### Phase 3. 모바일 시작/제출 실패 UX 정리

목표: 실패를 성공처럼 보이지 않게 한다.

작업:

1. `startPractice`에서 `startLesson` 실패를 삼키지 않는다.
2. 시작 실패 시 사용자 메시지를 표시하고 practice step으로 이동하지 않는다.
3. 제출 실패 메시지는 유지하되 재시도 CTA를 명확히 한다.
4. 모바일 테스트를 추가한다.

완료 기준:

- start API 실패 시 레슨이 practice 상태로 진입하지 않는다.
- submit API 실패 시 같은 단계에서 재시도 가능하다.

### Phase 4. 추천 경로 표현

목표: 접근은 자유롭게 유지하면서, 유저가 "지금 무엇을 하면 좋은지" 명확히 이해하게 한다.

작업:

1. 챕터 목록 응답에 `isRecommended`, `isSequentialNext`, `prerequisiteCompleted`와 같은 추천성 상태를 추가할지 결정한다.
2. 모바일 레슨 타일에서 추천 레슨과 완료 레슨의 시각적 차이를 정리한다.
3. 학습 탭 상단 CTA를 "다음 추천 레슨" 중심으로 정리한다.
4. 권장 순서 밖 레슨 진입 시 필요한 안내 문구를 최소 수준으로 설계한다.
5. 추천 카피를 아래 의미로 일관되게 정리한다.

카피 기준:

- `이어하기`: 이미 시작했지만 끝나지 않은 레슨
- `추천 레슨`: 아직 시작하지 않은 레슨 중 지금 하기에 가장 적절한 레슨
- `다시 보기 추천`: 완료한 레슨만 남았을 때의 복습 진입점
- `추천`: 챕터 안에 현재 추천 레슨이 포함되어 있음을 나타내는 배지

완료 기준:

- 모든 파일럿 레슨은 직접 접근 가능하다.
- 사용자는 목록 화면에서 다음 추천 레슨을 쉽게 식별할 수 있다.
- 추천 경로를 따르지 않아도 시작/제출/완료 흐름이 정상 동작한다.
- 추천 라벨만 보고도 "지금 이어할 것"과 "새로 시작할 것"을 구분할 수 있다.

### Phase 5. SRS 실패 처리 재정의

목표: 레슨 완료와 복습 연결이 분리되어 조용히 실패하지 않게 한다.

작업:

1. `process_answer` 실패와 `register_items_from_lesson` 실패 처리 정책을 정한다.
2. 파일럿에서는 실패를 API error 또는 retryable 상태로 노출한다.
3. 이미 완료된 레슨 재제출/재시도 시 SRS 재등록이 idempotent하게 동작하는지 확인한다.
4. 테스트를 추가한다.

완료 기준:

- SRS 등록 실패가 사용자/운영자에게 보인다.
- 동일 레슨을 재시도해도 중복 링크/중복 progress 오염이 없다.

### Phase 6. 파일럿 UAT

목표: 데이터와 플로우가 실제 10분 학습 경험을 만드는지 확인한다.

시나리오:

1. 신규 N5 유저가 학습 탭 진입
2. Ch.01 Lesson 1 시작
3. context preview와 guided reading 확인
4. recognition, matching, reorder 완료
5. 결과 화면에서 점수와 SRS 등록 안내 확인
6. 레슨 목록 복귀 후 Ch.01 진행률 확인
7. 다음 추천 레슨 표시 확인
8. review summary CTA 확인
9. 추천 레슨 대신 다른 레슨 직접 진입
10. 자유 진입 후에도 추천 상태가 자연스럽게 갱신되는지 확인

현재 실행 결과:

- 2026-04-24 모바일 재실행에서 N5 Ch.01 Lesson 2 `어디서 오셨나요?`는 추천 카드 진입부터
  submit까지 실제 UI 탭으로 완료했다.
- submit API는 200을 반환했고 `status = COMPLETED`, `scoreCorrect = 5`, `scoreTotal = 5`,
  `srsItemsRegistered = 7`을 기록했다.
- 레슨 목록 복귀 후 Ch.01 진행률은 `40%`, Lesson 1/2는 각각 `5/5`, 다음 추천 레슨은
  Lesson 3 `이야기 주제 세우기`로 갱신됐다.
- 이어서 Lesson 3 `이야기 주제 세우기`도 추천 카드 진입부터 submit까지 실제 UI 탭으로 완료했다.
- Lesson 3 최초 submit API는 200을 반환했고 `status = COMPLETED`, `scoreCorrect = 5`,
  `scoreTotal = 5`, `srsItemsRegistered = 6`을 기록했다.
- Lesson 3 재시도 submit은 `srsItemsRegistered = 0`을 반환해 동일 레슨의 SRS 등록이
  중복 증가하지 않는 것을 확인했다.
- 결과 화면은 이벤트 로그로 확인했고, `LessonResultStep` 위젯 테스트로 `srsItemsRegistered > 0`일 때
  점수와 SRS 등록 안내가 표시되는 UI 계약을 보강했다. 다만 세션 중단 이후 앱이 로그인 화면으로
  전환되어 실제 기기 스크린샷은 보존하지 못했다.
- `review_cta_clicked`는 실계정에서 복습 대기 카드가 미노출되어 end-to-end 탭 검증을 하지 못했다.
  대신 `StudyPage` 위젯 테스트로 `totalDue > 0`일 때 `복습 시작` 탭 이벤트 계약을 검증했고,
  `app.seeds.prepare_review_due`로 테스트 계정의 기존 SRS 항목을 due 상태로 당겨 실기 재검증을 준비할 수 있다.

관찰 항목:

- 총 소요 시간
- 각 단계에서 사용자가 다음 행동을 이해하는지
- 문제 난이도가 지나치게 쉽거나 어려운지
- 해설이 오답 원인을 설명하는지
- 결과 화면이 복습으로 이어지는지
- 다음 추천 레슨 진입 동기가 생기는지
- 추천 카드, 챕터 배지, 레슨 타일 라벨의 의미를 혼동하지 않는지
- 사용자가 자유 진입 가능한 구조를 제약으로 오해하지 않는지

UAT 체크 질문:

1. 학습 탭 첫 화면에서 "지금 해야 할 것"이 3초 안에 보이는가
2. `이어하기`와 `추천 레슨`의 차이를 설명 없이 이해할 수 있는가
3. 추천 레슨이 아닌 다른 레슨을 눌렀을 때 막힌 느낌 없이 진입되는가
4. 자유 진입 이후에도 다음 추천이 납득 가능한 순서로 갱신되는가
5. 레슨 완료 후 다음 행동이 "복습"인지 "다음 레슨"인지 명확한가

## 7. 측정 지표

파일럿에서 최소한 아래 이벤트를 확인한다.

| 이벤트 | 목적 |
|--------|------|
| lesson_list_viewed | 챕터 목록 도달 |
| lesson_started | 레슨 시작 성공 |
| lesson_step_completed | 단계별 이탈 지점 |
| lesson_submitted | 제출 성공/실패 |
| lesson_completed | 완료율 |
| lesson_retry_clicked | 난이도/실패 신호 |
| review_cta_clicked | SRS 연결 |

2026-04-24 모바일 재실행 확인 상태:

| 이벤트 | 상태 | 메모 |
|--------|------|------|
| lesson_list_viewed | 확인 | N5 학습 홈 진입 시 6챕터/30레슨과 추천 Lesson 2/3 기록 |
| lesson_started | 확인 | Lesson 2/3 start 시 recognition/reorder 문항 수와 추천 속성 기록 |
| lesson_step_completed | 확인 | context, vocab, grammar, recognition, matching, reorder 단계 기록 |
| lesson_submitted | 확인 | Lesson 2 success 5/5 SRS 7개, Lesson 3 success 5/5 SRS 6개 등록 속성 기록 |
| lesson_completed | 확인 | 완료율 측정 이벤트 기록 |
| lesson_retry_clicked | 확인 | 완료 직후 재학습 CTA 탭에서 기록 |
| review_cta_clicked | 계약 확인 / 실계정 재실행 준비됨 | 복습 CTA 미노출. 위젯 테스트로 due card 탭 이벤트 속성 검증, `app.seeds.prepare_review_due --apply`로 due 데이터 준비 가능 |

결과 화면 SRS 안내는 `LessonResultStep` 위젯 테스트로 `srsItemsRegistered > 0` 배너 표시와
완료/재시도 CTA 동작을 별도로 고정했다.

현재 모바일 기본 sink는 `debugPrint`와 Sentry breadcrumb를 함께 사용한다.
운영 분석 도구가 별도로 정해지면 sink만 교체하고, 이벤트 이름과 속성 계약은 유지한다.

## 8. 리스크와 대응

| 리스크 | 대응 |
|--------|------|
| 데이터가 DRAFT인데 publish됨 | `DRAFT`는 seed 시 비공개, 파일럿 공개 데이터는 `PILOT`으로 명시 |
| 추천 상태가 약하면 학습 경로가 흐려짐 | 추천 레슨 강조와 이어하기 CTA를 함께 제공 |
| SRS 실패를 hard fail하면 UX가 막힘 | 재시도 메시지와 idempotent 재제출 보장 |
| 30레슨만으로 장기 리텐션 판단 어려움 | 파일럿 목표를 단기 플로우 품질로 제한 |
| 웹 미지원 혼선 | 파일럿 범위를 mobile-only로 문서화 |

## 9. 권장 작업 순서

1. Phase 1: seed와 validator
2. Phase 2: submit 계약 강화
3. Phase 3: 모바일 실패 UX
4. Phase 4: 추천 경로 표현
5. Phase 5: SRS 실패 처리
6. Phase 6: 파일럿 계측과 UAT 체크리스트

이 순서가 중요한 이유는, seed와 제출 계약이 불안정하면 이후 UX 테스트 결과를 신뢰할 수 없기 때문이다.

## 10. 이번 파일럿에서 하지 않을 결정

- N5 전체 160레슨 구조 확정
- N4-N1 콘텐츠 생성
- 정답률 기반 통과 컷
- adaptive difficulty
- 웹 레슨 학습 화면
- 후리가나 fade 정책
- 서버 강제 잠금 정책

이 항목들은 파일럿 데이터로 사용성/상태 전이/SRS 연결이 검증된 뒤 별도 단계에서 결정한다.
