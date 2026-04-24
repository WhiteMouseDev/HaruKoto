# N5 파일럿 학습 플로우 UAT 실행 기록

> 실행일: 2026-04-24
> 실행 환경: iOS Simulator
> 실행 방식: `flutter run --route=...` + 시뮬레이터 스크린샷 확인

## 1. 실행 메모

- Computer Use 권한은 대화 중 허용되었지만 MCP 상태 반영이 되지 않아 실제 탭 자동화에는 사용하지 못했다.
- 웹 타깃은 `record_web` / `record_platform_interface` 불일치로 빌드에 실패했다.
- 따라서 학습 탭, 레슨 목록, 레슨 상세는 각 경로로 직접 앱을 띄워 시각 확인했다.
- 테스트 계정의 현재 레벨은 `ABSOLUTE_ZERO`였지만, lesson API 응답은 파일럿 레슨 데이터로 연결되어 있었다.

## 2. 실행 시나리오 결과

### 시나리오 A. 신규 진입과 추천 카드

- 상태: `Pass`
- 근거:
  - `/study` 진입 시 상단 추천 카드가 노출됨
  - 카드 라벨 `추천 레슨`, 버튼 `시작하기` 확인
  - 챕터 카드에도 `추천` 배지가 함께 표시됨
- 증빙: 시뮬레이터 화면에서 직접 확인했다. N5 기준 최종 화면은 `../qa/assets/harukoto-study-uat-n5-1.png`에 보존했다.

### 시나리오 B. 진행 중 레슨 이어하기

- 상태: `Pass`
- 근거:
  - 레슨 start API 호출 후 `/study` 재진입 시 카드 라벨이 `이어하기`로 변경
  - 카드 버튼도 `이어하기`로 변경
  - 챕터 내부 추천 타일 역시 `이어하기` 라벨로 변경
- 증빙: 시뮬레이터 화면에서 직접 확인했다. N5 기준 최종 화면은 `../qa/assets/harukoto-study-uat-n5-1.png`에 보존했다.

### 시나리오 C. 추천이 아닌 레슨 직접 진입

- 상태: `Pass`
- 근거:
  - `/study/lessons` 진입 시 다른 챕터와 레슨이 잠금 없이 그대로 노출됨
  - 목록 표면상 잠금 아이콘이나 차단 메시지는 없었음
- 한계:
  - 실제 탭 자동화는 막혀 있었기 때문에 목록에서 직접 터치해 이동하는 것까지는 확인하지 못했고,
    대신 상세 경로 직접 진입으로 자유 접근 가능성을 보완 검증했다.
- 증빙: 시뮬레이터 화면에서 직접 확인했다.

### 시나리오 D. 레슨 상세 직접 진입

- 상태: `Pass`
- 근거:
  - 실제 API lesson id로 `/study/lessons/{lessonId}` 경로를 열었고 상세 페이지가 정상 렌더링됨
  - 제목, 소요 시간, 배울 단어/문법, `학습 시작하기` CTA가 모두 보임
- 주의:
  - 콘텐츠 JSON의 `lesson_id` (`HN5-001`)는 API detail path에서 쓰는 id가 아니므로 직접 경로 진입 시 사용할 수 없음
- 증빙: 시뮬레이터 화면에서 직접 확인했다.

## 3. 발견 사항

### Flag 1. 테스트 계정 레벨 불일치

- 현재 테스트 계정의 로컬/서버 레벨이 `ABSOLUTE_ZERO`로 설정되어 있다.
- 파일럿 문서 기준은 `N5 Ch.01-Ch.06`이므로, 정식 UAT에서는 N5 계정 또는 N5로 고정한 테스트 계정이 필요하다.

### Flag 2. 웹 UAT 차단

- `flutter run -d chrome --dart-define-from-file=.env` 실행 시 아래 오류로 웹 빌드가 실패했다.
- 요약: `record_web`가 `RecordConfig.streamBufferSize`를 참조하지만 현재 `record_platform_interface`에는 해당 getter가 없다.
- 결과적으로 브라우저 기반 UAT는 현재 불가능하다.
- 결정: 이번 파일럿은 mobile-only로 유지하므로 웹 빌드 문제는 본 작업의 블로커로 보지 않는다.
- 후속 조건: 웹 레슨 표면 또는 브라우저 기반 모바일 UAT가 필요해질 때 Flutter web dependency 정리를 별도 작업으로 분리한다.

### Note 1. 추천 경로 표현은 의도대로 동작

- 추천 카드, 챕터 배지, 레슨 타일 라벨이 같은 대상을 가리키고 있다.
- `추천 레슨`과 `이어하기`의 상태 전환도 시각적으로 명확하다.

## 4. 결론

- 이번 실행 기준으로 추천 경로 UI는 파일럿 의도에 맞게 동작한다.
- 특히 `추천 레슨 -> 이어하기` 전환은 실제 서버 상태 변경 후에도 일관되게 반영됐다.
- N5 기준 재확인은 아래 추가 실행에서 완료했다.
- 웹 빌드 문제는 이번 mobile-only 파일럿의 블로커로 보지 않기로 결정했다.

## 5. N5 기준 재확인

> 추가 실행: 2026-04-24

### 실행 조건

- 원격 사용자 프로필은 변경하지 않았다.
- 시뮬레이터 로컬 preference의 `flutter.user_jlpt_level`만 `N5`로 변경했다.
- `/study` 경로로 앱을 재실행했다.

### 확인 결과

- 상태: `Pass`
- 근거:
  - 앱 로그에서 `/api/v1/lessons/review/summary?jlptLevel=N5` 호출 확인
  - 앱 로그에서 `/api/v1/lessons/chapters?jlptLevel=N5` 호출 확인
  - 화면 상단 레벨 칩이 `N5`로 표시됨
  - 추천 카드, 챕터 배지, 레슨 타일이 같은 레슨을 `이어하기` 대상으로 표시함
- 증빙:
  - `../qa/assets/harukoto-study-uat-n5-1.png`

### 남은 한계

- 원격 테스트 계정의 기본 레벨은 아래 추가 실행에서 N5로 고정했다.

## 6. 원격 N5 테스트 계정 고정

> 추가 실행: 2026-04-24

### 실행 조건

- 대상 계정: `test1@test.com`
- 사용자 승인 후 HaruKoto API `PATCH /api/v1/user/profile`을 호출했다.
- 변경 payload는 `{"jlptLevel":"N5"}` 하나만 사용했다.

### 확인 결과

- 상태: `Pass`
- 근거:
  - API 응답에서 `email = test1@test.com`, `jlptLevel = N5` 확인
  - 앱 재실행 후 `/api/v1/lessons/review/summary?jlptLevel=N5` 호출 확인
  - 앱 재실행 후 `/api/v1/lessons/chapters?jlptLevel=N5` 호출 확인
  - 화면 상단 레벨 칩이 `N5`로 유지됨
- 증빙:
  - `../qa/assets/harukoto-study-uat-n5-remote-profile.png`

### 결론

- `test1@test.com`은 반복 UAT용 N5 테스트 계정으로 사용할 수 있다.
- 이후 N5 파일럿 학습 플로우 검증은 로컬 preference 우회 없이 이 계정으로 재현 가능하다.

## 7. Lesson 1 완료 플로우 확인

> 추가 실행: 2026-04-24

### 실행 조건

- 대상 계정: `test1@test.com`
- 대상 레슨: N5 Ch.01 Lesson 1
- 실행 방식: 원격 API로 lesson detail 조회 후 5개 문항 전체 제출

### 확인 결과

- 상태: `Flag`
- 근거:
  - submit 응답은 `status = COMPLETED`, `scoreCorrect = 5`, `scoreTotal = 5`
  - 챕터 목록에서도 첫 레슨이 `COMPLETED`, `scoreCorrect = 5`, `scoreTotal = 5`로 반영됨
  - review summary는 정상 응답했지만, lesson detail progress의 `srsRegisteredAt`이 `null`로 남음

### 원인

- 기존 서버 구현은 문항별 `process_answer`를 먼저 실행한 뒤 `register_items_from_lesson`을 호출했다.
- `process_answer`가 먼저 SRS progress row를 만들면, 이후 `register_items_from_lesson`은 이미 존재하는 row로 판단해 신규 등록 수를 `0`으로 반환한다.
- 그 결과 레슨 자체는 완료되지만 `srsRegisteredAt`이 기록되지 않고, 모바일 결과 화면의 SRS 등록 안내도 표시되지 않을 수 있다.

### 조치

- 로컬 코드에서 SRS 등록을 문항별 answer processing보다 먼저 수행하도록 수정했다.
- SRS 등록 또는 answer processing 실패 시 500을 반환하고 레슨 완료 커밋을 막도록 수정했다.
- 이미 SRS row가 존재해 신규 등록 수가 `0`이어도, 레슨에 SRS 대상 item link가 있으면 `srsRegisteredAt`을 기록하도록 수정했다.

### 남은 조건

- 위 조치는 로컬 코드 기준이며, 원격 API에는 아직 배포되지 않았다.
- 배포 후 같은 N5 계정 또는 새 N5 테스트 계정으로 Lesson 1 완료 플로우를 다시 실행해 `srsRegisteredAt` 기록과 결과 화면 SRS 안내를 재확인해야 한다.
