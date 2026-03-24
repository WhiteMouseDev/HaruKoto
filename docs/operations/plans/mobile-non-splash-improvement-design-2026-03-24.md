# Mobile Non-Splash Improvement Design (2026-03-24)

> 스플래시/브랜드 애니메이션을 제외한 모바일 구조 개선 설계. 목표는 "새 기능을 더 빨리 붙이는 것"이 아니라, "복잡도가 누적될수록 개발 속도가 꺾이는 구조를 바로잡는 것"이다.

## 문서 목적

이 문서는 다음 네 가지를 설계한다.

- 네트워크/인증 경로 일원화
- 설정 상태의 소유권 재정의
- 대형 화면과 장수명 세션 로직 분해
- 테스트 전략 재구성

스플래시/앱 시작 시간 정책은 별도 문서로 분리한다.

- `docs/operations/mobile/mobile-startup-splash-policy-2026-03-24.md`

## 범위

### 포함

- `apps/mobile/lib/core/network/**`
- `apps/mobile/lib/core/providers/**`
- `apps/mobile/lib/features/auth/**`
- `apps/mobile/lib/features/my/**`
- `apps/mobile/lib/features/chat/**`
- `apps/mobile/lib/features/study/**`
- `apps/mobile/test/**`

### 제외

- 스플래시 애니메이션 길이와 전환 정책
- 디자인 시스템 전면 개편
- 상태관리 라이브러리 교체
- 전체 앱의 일괄 Clean Architecture 재작성

## 냉정한 진단

현재 모바일 앱은 기능 추가 속도는 빠르지만, 유지보수 비용이 이미 올라가기 시작한 상태다.

핵심 문제는 다섯 가지다.

1. 네트워크 정책이 한 군데서 관리되지 않는다
2. 설정 상태가 local/server/provider에 분산돼 있다
3. `study`와 `chat` 피처에 지나치게 많은 책임이 몰려 있다
4. 테스트가 "모델 파싱 성공"에 편중되어 있다
5. 런치 토글과 레거시 경로가 코드 주석으로 남아 있다

이 상태에서 기능을 더 얹으면 단기 생산성은 유지될 수 있어도, 2~4주 뒤부터는 회귀 비용이 개발 속도를 먹기 시작한다.

## 설계 원칙

### 1. 기존 스택은 유지한다

- Riverpod 유지
- Dio 유지
- GoRouter 유지
- feature-based 구조 유지

문제는 기술 선택보다 책임 배치에 있다. 프레임워크를 바꾸는 것은 해법이 아니다.

### 2. 소스 오브 트루스를 다시 정한다

같은 설정을 두 군데 이상이 "정답"이라고 주장하면 결국 디버깅 비용이 폭증한다.

### 3. 장수명 상태와 일회성 UI 상태를 분리한다

음성 통화, 레슨 플로우, 퀴즈 세션 같은 것은 단순한 `setState()`로 버티는 수준을 이미 넘었다.

### 4. 리팩터링은 국소적으로 한다

전체를 한 번에 갈아엎지 않는다. 가장 비싼 지점만 먼저 자른다.

## 개선 설계

## A. 네트워크와 인증 경로 재설계

### 현재 문제

- `_RetryInterceptor`가 raw `Dio()`를 새로 만든다
- `AuthInterceptor`도 401 재시도 시 별도 `Dio()`를 생성한다
- `AuthRepository.signInWithKakao()`도 공통 클라이언트를 우회한다

이 구조는 "정책은 공통"이라고 말하지만 실제로는 경로마다 다르게 동작한다.

### 목표 상태

모든 앱 API 요청은 아래 두 경로 중 하나로만 흐른다.

- 일반 API 경로
- 인증 refresh/exchange 전용 경로

중요한 점은 "둘 다 명시적으로 설계된 경로"여야 한다는 것이다. 지금처럼 우연히 raw client가 생기면 안 된다.

### 제안 구조

```text
core/
  network/
    app_http_client.dart
    auth_refresh_client.dart
    api_exception.dart
    retry_policy.dart
    request_context.dart
  auth/
    auth_session_manager.dart
```

### 역할

- `app_http_client.dart`
  - 일반 API 요청 전용
  - auth header, logging, error mapping, retry policy 포함
- `auth_refresh_client.dart`
  - refresh/token exchange 전용
  - 의도적으로 일반 interceptors 일부 제외 가능
  - 단, 이 예외는 코드 구조로 보장해야 한다
- `auth_session_manager.dart`
  - 현재 세션 조회
  - refresh lock
  - refresh 결과 배포
  - sign-out fallback 정책

### 핵심 규칙

- Repository에서 `Dio()` 직접 생성 금지
- refresh와 social login token exchange는 dedicated client를 주입받아 사용
- retry는 `requestOptions.extra`에 metadata를 남겨 멱등성/재시도 횟수/최종 실패 원인을 추적 가능하게 한다
- 401 처리 정책은 interceptor 여러 개가 나눠 갖지 말고 auth session manager를 통해 일원화한다

### 파일별 적용 방향

- `core/network/dio_client.dart`
  - `createDioClient()`를 단순 팩토리에서 `AppHttpClient` builder로 격상
- `core/network/auth_interceptor.dart`
  - refresh 로직 대부분을 `AuthSessionManager`로 이동
- `features/auth/data/auth_repository.dart`
  - Kakao exchange raw `Dio()` 제거

### 기대 효과

- 요청 경로마다 예외 동작이 달라지는 문제 축소
- trace/logging/Sentry tagging 일관성 확보
- auth 실패 시 디버깅 비용 감소

## B. 설정 상태의 소유권 재정의

### 현재 문제

현재 설정은 사실상 세 갈래다.

- 디바이스 로컬 설정
- 서버 프로필 설정
- local+server 혼합 설정

특히 `showFurigana`는 이중 저장 구조라 가장 애매하다.

### 원칙

설정은 아래 둘 중 하나여야 한다.

- device-scoped
- user-scoped

"둘 다"는 피한다. 정말 필요할 때만 `local cache of server-scoped setting`으로 표현한다.

### 권장 분류

#### Device-scoped

- theme mode
- sound enabled
- haptic enabled
- local notification enabled/time

이 값들은 기기마다 달라도 자연스럽다.

#### User-scoped

- JLPT level
- showKana
- dailyGoal
- callSettings
- showFurigana

이 값들은 계정 수준 설정으로 보는 편이 더 자연스럽다. 특히 `showFurigana`와 `callSettings`는 학습 습관과 직접 연결되므로 디바이스마다 다르게 두면 오히려 예측 가능성이 낮아진다.

### 제안 구조

```text
core/
  settings/
    device_settings.dart
    device_settings_repository.dart
    user_preferences.dart
    user_preferences_repository.dart
    settings_sync_service.dart
```

### 상태 모델

- `DeviceSettings`
  - theme
  - sound
  - haptic
  - local notifications
- `UserPreferences`
  - showFurigana
  - showKana
  - dailyGoal
  - jlptLevel
  - callSettings

### 동작 규칙

- UI는 `DeviceSettingsProvider`와 `UserPreferencesProvider`만 읽는다
- `Notifier.build()` 안에서 비동기 부작용 실행 금지
- user-scoped setting은 서버 응답을 기준으로 하되, 로컬 캐시는 bootstrap과 오프라인 완충 용도로만 사용한다
- local notification scheduling은 `DeviceSettings`가 변할 때만 실행한다

### 현재 코드에 대한 직접 교정 방향

- `themeProvider`
  - 영속화 추가
- `quizSettingsProvider`
  - standalone local provider로 유지하지 말고 `UserPreferences`로 흡수
- `notificationSettingsProvider`
  - `AsyncNotifier` 또는 bootstrap 이후 hydrate되도록 변경
  - `_applySchedule()`는 provider build가 아니라 explicit sync point에서만 실행
- `my_page`의 `onUpdate('app_settings', {'showFurigana': value})`
  - 임시 브리지 코드는 가능하지만 최종 구조로 남기면 안 된다

### 기대 효과

- 설정 플리커 감소
- 디버깅 대상 축소
- 다기기 동기화/오프라인 정책 명확화

## C. `study`와 `chat` 피처를 화면 중심에서 세션 중심으로 재구성

### 현재 문제

대형 파일의 본질적 문제는 "길이"가 아니라 "세션 로직이 화면에 붙어 있다"는 점이다.

- `lesson_page.dart`는 레슨 상태 머신 + 제출 + step UI를 한 파일에서 관리
- `voice_call_page.dart`는 음성 세션 생성, 토큰 수급, character detail 조회, timer, 종료 후 이동을 모두 담당
- `quiz_page.dart`도 세션 초기화/답안 제출/완료 이동을 화면이 직접 수행

### 목표 상태

화면은 "현재 상태 렌더링 + 사용자 이벤트 전달"만 담당하고,
세션 생명주기는 controller/use case가 담당한다.

### C-1. Lesson Flow

#### 제안 구조

```text
features/study/
  application/
    lesson_flow_controller.dart
    lesson_submission_service.dart
  presentation/
    lesson_page.dart
    lesson_steps/
      context_preview_step.dart
      guided_reading_step.dart
      recognition_step.dart
      matching_step.dart
      reorder_step.dart
      result_step.dart
```

#### controller 책임

- 현재 step
- 현재 answer set
- skip logic
- submit lifecycle
- back navigation rule

#### page 책임

- app bar
- progress bar
- step widget composition
- sheet/dialog trigger

### C-2. Quiz Session

#### 제안 구조

```text
features/study/
  application/
    quiz_session_controller.dart
    quiz_session_state.dart
```

#### controller 책임

- session init
- resume/start 분기
- timer lifecycle
- answer submit
- complete 처리

#### page 책임

- special mode 분기 렌더링
- exit confirm dialog
- snackbar 표시

### C-3. Voice Call Session

#### 제안 구조

```text
features/chat/
  application/
    voice_call_controller.dart
    voice_call_state.dart
  data/
    gemini_live_service.dart
    call_bootstrap_service.dart
```

#### 역할 분리

- `call_bootstrap_service`
  - live token
  - character detail
  - call settings 결합
- `gemini_live_service`
  - websocket/audio/transcript transport
- `voice_call_controller`
  - UI state
  - ringtone start/stop
  - timer
  - end-call decision
  - auto-analysis 분기

이렇게 나누면 `VoiceCallPage`는 실제로는 render shell 수준으로 내려갈 수 있다.

## D. 런치 토글과 레거시 경로를 코드 주석에서 꺼낸다

### 현재 문제

현재는 launch 상태가 주석과 빈 routes에 숨어 있다.

이건 "임시 대응"으로는 가능하지만, 장기적으로는 제품 상태를 코드가 설명하지 못하는 상태다.

### 제안 구조

```text
core/config/
  feature_flags.dart
```

### 최소 규칙

- 구독 기능 off
- 전화 CTA off
- legacy route on/off

이 정도만 있어도 주석 기반 상태 관리에서 벗어난다.

### 원칙

- 주석으로 라우트를 끄지 않는다
- feature flag는 compile-time이어도 괜찮다
- remote config는 지금 당장 없어도 된다

## E. 테스트 전략 재구성

### 현재 문제

테스트는 통과하지만 분포가 왜곡돼 있다.

- 모델 테스트 많음
- 실제 플로우 테스트 적음
- 장수명 세션 테스트 없음

### 목표 분포

#### 1. Core/infra tests

- auth refresh/401 retry
- settings hydration
- notification schedule apply rules

#### 2. Controller tests

- lesson flow transitions
- quiz session lifecycle
- voice call lifecycle

#### 3. Widget tests

- auth/login
- onboarding flow
- my settings save flow
- study start/resume flow

#### 4. Repository contract tests

- Dio mock adapter로 request/response mapping 검증

### 우선순위 높은 신규 테스트

1. `auth` 로그인 성공/실패/취소
2. `my` 설정 저장 후 재마운트 시 값 유지
3. `quiz_page` resume/start/complete
4. `voice_call_controller` 연결 실패/재연결/종료
5. `lesson_flow_controller` step 전이와 submit

## 단계별 실행 계획

## Phase 1. 네트워크 일원화

### 작업

- `AuthSessionManager` 도입
- raw `Dio()` 생성 제거
- dedicated refresh client 도입

### 완료 기준

- Repository 직접 `Dio()` 생성 0건
- auth refresh 경로 1곳으로 축소
- retry/auth 정책 테스트 추가

## Phase 2. 설정 재구성

### 작업

- `DeviceSettings`와 `UserPreferences` 분리
- `theme`, `furigana`, `notification` 책임 재배치
- provider build 부작용 제거

### 완료 기준

- `Notifier.build()` 내부 fire-and-forget 로딩 제거
- 설정 소스 오브 트루스 문서화
- 재시작 후 설정 유지 테스트 추가

## Phase 3. Study/Chat 세션 분해

### 작업

- `LessonFlowController`
- `QuizSessionController`
- `VoiceCallController`

### 완료 기준

- `lesson_page.dart` 2,000줄 해소
- `voice_call_page.dart`에서 토큰/세션 orchestration 제거
- controller 단위 테스트 추가

## Phase 4. Flags/Test Upgrade

### 작업

- feature flags 도입
- legacy 경로 처리 방침 확정
- 핵심 플로우 테스트 보강

### 완료 기준

- 주석으로 비활성화된 라우트/기능 제거
- auth/practice/voice_call 영역 테스트 공백 축소

## 타당성 교차검증

이 문단은 일부러 "반론" 기준으로 다시 점검한다.

### 반론 1. 그냥 지금 구조로도 기능은 돌아간다

맞다. 지금도 동작은 한다.

하지만 이 설계의 목적은 "지금 당장 앱이 죽는다"를 막는 것이 아니라, 아래 비용을 미리 줄이는 것이다.

- 기능 추가 시 회귀 반경
- 설정 관련 버그 디버깅 시간
- auth/network 재현 불가 이슈
- 대형 파일 수정 공포

즉, 이 설계는 성능 최적화가 아니라 유지보수 비용 최적화다.

### 반론 2. 너무 많은 계층을 추가하는 것 아닌가

그 위험은 있다.

그래서 이 설계는 다음을 일부러 하지 않는다.

- Riverpod → BLoC 마이그레이션
- full Clean Architecture
- Repository/UseCase/Entity 전면 재작성

추가하는 계층은 "실제로 생명주기가 긴 상태"에만 한정한다.

- auth session
- user preferences
- lesson flow
- voice call session

이건 계층 과잉이 아니라 책임 복구에 가깝다.

### 반론 3. `showFurigana`를 서버 설정으로 보는 건 과한 것 아닌가

반론은 타당하다.

`showFurigana`는 디바이스별 취향일 수도 있다. 다만 현재 코드베이스는 이미 서버 `appSettings`를 사용하고 있고, 모바일 학습 경험에서 해당 값이 중요한 사용자 선호값으로 쓰이고 있다.

따라서 두 가지 선택지만 유효하다.

- 완전 로컬화
- 완전 서버화 + 로컬 캐시

현재처럼 동시 저장은 가장 나쁜 중간 상태다.

### 반론 4. raw `Dio()`를 완전히 없애면 refresh 루프 위험이 생기지 않나

이 반론도 맞다.

그래서 설계는 "refresh 전용 client"를 없애자는 게 아니라, "우발적인 raw client"를 없애자는 것이다.

즉:

- 일반 API client
- refresh/exchange 전용 client

둘은 분리할 수 있다. 다만 코드에서 명시적으로 관리되어야 한다.

### 반론 5. 대형 화면을 지금 나누면 delivery가 늦어지지 않나

맞다. 그래서 한 번에 다 자르지 않는다.

우선순위는 아래 두 개만 먼저 자르는 것이 적절하다.

- `lesson_page.dart`
- `voice_call_page.dart`

이 둘은 크기뿐 아니라 세션 복잡도까지 높아서 ROI가 가장 높다.

### 반론 6. 테스트를 늘리면 속도만 느려지는 것 아닌가

모델 테스트만 늘리면 그렇다.

하지만 지금 추가해야 하는 것은 수십 개의 세세한 테스트가 아니라,
"운영 중 비싼 버그를 막는 소수의 플로우 테스트"다.

즉, 양이 아니라 분포를 바꾸는 것이 핵심이다.

## 최종 판단

이 설계는 과한 리라이트 문서가 아니다. 오히려 지금 코드베이스가 이미 감당하고 있는 복잡도를 기준으로 최소한의 수술 부위를 정리한 문서다.

가장 타당성이 높은 실행 순서는 아래다.

1. 네트워크/인증 경로 일원화
2. 설정 소스 오브 트루스 재정의
3. `lesson`과 `voice_call` 세션 분해
4. 플로우 테스트 보강

이 순서를 뒤집으면 효과가 떨어진다.

- 테스트부터 먼저 늘리면 구조적 진동이 커서 유지비가 높다
- 화면 분해를 먼저 해도 설정/네트워크 모호성이 남아 다시 꼬인다
- feature flag 정리만 먼저 해도 핵심 비용은 줄지 않는다

즉, "네트워크 → 설정 → 세션 분해 → 테스트" 순서가 가장 방어적이고 현실적이다.
