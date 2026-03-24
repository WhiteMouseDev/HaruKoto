# Mobile Architecture Audit (2026-03-24)

> HaruKoto Flutter 모바일 앱 전체 구조 감사. 범위는 `apps/mobile` 전체이며, 코드 구조, 상태 관리, 라우팅, 네트워크, 실시간 음성 통화, 설정 저장, 테스트 분포를 함께 점검했다.

## TL;DR

모바일 앱은 feature-based 구조와 Riverpod/Dio/GoRouter 조합이 잘 잡혀 있고, 데이터 모델 파싱 테스트도 꽤 잘 갖춰져 있다. 하지만 구조 리스크는 이미 보인다.

- 앱 시작과 인증 판정이 느리고 취약하다.
- 네트워크 재시도/토큰 갱신 경로가 일관되지 않다.
- 로컬 설정과 서버 설정의 책임이 분산되어 있다.
- `study`와 `chat` 피처의 화면 파일이 너무 커서 유지보수 비용이 빠르게 올라갈 구조다.
- 테스트는 많이 보이지만 대부분 모델 파싱 중심이라, 실제 사용자 플로우를 지키는 테스트는 얇다.

현재 상태는 "기능은 빠르게 붙일 수 있지만, 복잡도가 누적되면 속도가 급격히 떨어질 수 있는 앱"에 가깝다.

## 후속 문서

이번 감사의 후속 문서는 아래 두 개로 분리한다.

- 스플래시/시작 경험 정책:
  - `docs/operations/mobile/mobile-startup-splash-policy-2026-03-24.md`
- 비스플래시 구조 개선 설계:
  - `docs/operations/plans/mobile-non-splash-improvement-design-2026-03-24.md`

## 감사 범위와 방법

- 코드 구조 정적 분석: `apps/mobile/lib`, `apps/mobile/test`, `pubspec.yaml`, `analysis_options.yaml`, `README.md`, `RULES.md`
- 실행 검증:
  - `make analyze`
  - `make test`
- 감사 시점: 2026-03-24

## 현재 스냅샷

### 코드 규모

- Dart 소스 파일: 222개
- 테스트 파일: 33개
- 테스트 파일 비율: 약 14.9%

### 피처별 규모

- `study`: 55 files / 11,862 lines
- `chat`: 30 files / 5,763 lines
- `kana`: 23 files / 3,975 lines
- `home`: 15 files / 3,194 lines
- `stats`: 14 files / 2,911 lines
- `my`: 16 files / 2,878 lines
- `auth`: 19 files / 2,512 lines

### 가장 큰 파일

- `apps/mobile/lib/features/study/presentation/lesson_page.dart`: 2,034 lines
- `apps/mobile/lib/features/home/presentation/widgets/quick_start_card.dart`: 745 lines
- `apps/mobile/lib/features/stats/presentation/widgets/study_tab.dart`: 688 lines
- `apps/mobile/lib/features/study/presentation/study_page.dart`: 682 lines
- `apps/mobile/lib/features/study/presentation/widgets/study_tab_content.dart`: 644 lines
- `apps/mobile/lib/features/practice/presentation/practice_page.dart`: 608 lines
- `apps/mobile/lib/features/chat/data/gemini_live_service.dart`: 533 lines
- `apps/mobile/lib/features/chat/presentation/voice_call_page.dart`: 526 lines

### 테스트 분포

- 전체 테스트 33개 중 데이터 모델 테스트가 27개
- 프레젠테이션 테스트는 1개
- 프로바이더 테스트는 1개
- `auth` 테스트 0개
- `practice` 테스트 0개
- `voice_call` 관련 테스트 0개

### 실행 결과

- `make analyze`
  - 경고 1건
  - `lib/features/practice/presentation/practice_page.dart:492`의 `_QuickActionCard` 미사용
- `make test`
  - 182 tests passed

## 잘 되어 있는 점

### 1. 기본 아키텍처 방향은 맞다

`features/{feature}/data|providers|presentation` 구조가 비교적 일관적이다. 이 덕분에 코드베이스가 커져도 어디를 봐야 할지 찾기 어렵지는 않다.

### 2. 공통 네트워크/인증 진입점이 있다

`dioProvider`, `AuthInterceptor`, `ApiException`으로 최소한의 인프라 축은 잡혀 있다. 전역 HTTP 클라이언트를 하나로 모으려는 의도는 좋다.

### 3. 모델 파싱 안정성은 나쁘지 않다

모델 테스트가 많고, 기본값 방어도 많이 들어가 있다. API 스키마가 흔들릴 때 앱이 바로 죽지 않게 하려는 의도가 보인다.

### 4. 모바일 UX 디테일은 신경 쓴 편이다

스플래시, 햅틱, 사운드, 오프라인 배너, 리마인더, 바텀시트, 음성통화 등 모바일다운 요소를 적극적으로 도입했다.

## 핵심 문제점

### P1. 앱 시작과 인증 판정이 느리고 취약하다

관련 코드:

- `apps/mobile/lib/main.dart:13-54`
- `apps/mobile/lib/core/router/app_router.dart:64-86`
- `apps/mobile/lib/core/router/app_router.dart:378-408`
- `apps/mobile/lib/features/auth/providers/auth_provider.dart:9-16`

문제:

- `main()`에서 Supabase, 알림, 사운드, 햅틱, Sentry를 모두 `await`한 뒤에야 `runApp()`이 호출된다.
- 라우터는 `isAuthenticatedProvider`를 바로 읽는데, 이 값은 `StreamProvider`가 값을 내기 전까지 기본적으로 `false` 취급된다.
- 스플래시는 고정 3초 대기 후 다시 세션/프로필을 확인한다.

영향:

- cold start 체감이 느려진다.
- 인증 상태가 이미 있는데도 초기 몇 프레임 동안 비로그인으로 판단될 여지가 있다.
- 스플래시가 상태 준비를 기다리는 것이 아니라 시간을 기다리는 구조라, 빠른 기기에서는 불필요하게 느리고 느린 기기에서는 여전히 불안정하다.

개선:

- `BootstrapController` 또는 `AppStartupState`를 만들고, 앱 시작을 `시간 기반`이 아니라 `준비 상태 기반`으로 바꾼다.
- 인증 상태는 `bool` 하나로 축약하지 말고 `loading / authenticated / unauthenticated` 3상태로 유지한다.
- `GoRouter.redirect`에서 인증 스트림의 초기 로딩 상태를 명시적으로 처리한다.
- 스플래시 3초 고정 대기는 제거하고, 최소 노출 시간이 필요하면 300~600ms 정도의 상한만 둔다.

### P1. 네트워크 재시도와 토큰 갱신 경로가 일관되지 않다

관련 코드:

- `apps/mobile/lib/core/network/dio_client.dart:36-78`
- `apps/mobile/lib/core/network/auth_interceptor.dart:14-58`
- `apps/mobile/lib/features/auth/data/auth_repository.dart:48-81`

문제:

- `_RetryInterceptor`는 재시도 시 새 `Dio()`를 직접 만들어 원래 인터셉터 체인을 재사용하지 않는다.
- `AuthInterceptor`도 401 재시도 시 별도의 raw `Dio()`로 다시 요청한다.
- `AuthRepository.signInWithKakao()`도 raw `Dio()`를 직접 생성한다.

영향:

- 재시도 요청에 인증/에러 변환/로깅 정책이 일관되게 적용되지 않는다.
- 추후 공통 헤더, trace id, 디버그 로깅, Sentry 태깅, rate-limit 처리 등을 넣을수록 편차가 커진다.
- "처음 요청"과 "재시도 요청"의 동작이 달라지는 미묘한 버그가 생기기 쉽다.

개선:

- 재시도는 raw `Dio()`를 새로 만들지 말고, 공통 클라이언트에서 재진입 가능하도록 설계한다.
- `AuthRepository.signInWithKakao()`도 별도 raw `Dio()` 대신 공유된 API 클라이언트나 dedicated auth client provider를 사용한다.
- 네트워크 정책을 `ApiClient` 혹은 `NetworkExecutor` 레벨로 끌어올려, auth refresh와 retry가 한 곳에서만 일어나게 한다.

### P1. 설정 상태가 분산되어 있고, `Notifier.build()`에서 비동기 부작용이 일어난다

관련 코드:

- `apps/mobile/lib/core/providers/theme_provider.dart:4-12`
- `apps/mobile/lib/core/providers/quiz_settings_provider.dart:4-24`
- `apps/mobile/lib/core/providers/notification_settings_provider.dart:43-103`
- `apps/mobile/lib/features/my/presentation/widgets/app_settings_section.dart:65-156`
- `apps/mobile/lib/features/my/presentation/widgets/settings_menu.dart:89-99`

문제:

- `themeProvider`는 메모리 상태만 들고 있고 영속화가 없다.
- `quizSettingsProvider`와 `notificationSettingsProvider`는 `build()`에서 비동기로 `SharedPreferences`를 읽고 나중에 state를 덮어쓴다.
- `notificationSettingsProvider`는 로드 직후 `_applySchedule()`까지 수행한다. 즉, "설정 읽기"와 "실제 부작용 실행"이 결합되어 있다.
- 앱 설정 일부는 local-first, 일부는 server sync, 일부는 둘 다 쓰는 구조다. 예를 들어 후리가나는 로컬 provider 값으로 렌더링하면서 동시에 서버로도 업데이트한다.

영향:

- 첫 진입 시 기본값이 잠깐 보였다가 저장값으로 바뀌는 UI 플리커가 생길 수 있다.
- 알림 스케줄이 provider 초기화 타이밍에 의존한다.
- 설정 출처가 명확하지 않아, 디버깅 시 "서버 값이 정답인지, 로컬 값이 정답인지"가 흔들린다.

개선:

- 설정은 `HydratedSettingsRepository` 하나로 모은다.
- `Notifier.build()`에서 fire-and-forget 로딩을 하지 말고 `AsyncNotifier` 또는 명시적 bootstrap로 바꾼다.
- `theme`, `furigana`, `notification`, `haptic`, `sound`의 소스 오브 트루스를 문서로 고정한다.
- "로컬 전용", "서버 전용", "서버 백업형"을 구분해서 저장 전략을 나눈다.

### P2. 프레젠테이션 계층이 비대해지고 있다

관련 코드:

- `apps/mobile/lib/features/study/presentation/lesson_page.dart:1-2034`
- `apps/mobile/lib/features/study/presentation/study_page.dart`
- `apps/mobile/lib/features/home/presentation/widgets/quick_start_card.dart`
- `apps/mobile/lib/features/chat/presentation/voice_call_page.dart`
- `apps/mobile/lib/features/chat/data/gemini_live_service.dart`

문제:

- `lesson_page.dart` 한 파일이 2,000줄을 넘는다.
- `study` 피처는 11,862 lines로 앱 내 최대 규모인데, UI 파일 안에 플로우 제어와 상태 전이가 많이 들어 있다.
- 전체 앱에 `setState(` 호출이 213회 나온다.
- `VoiceCallPage`도 UI 상태, API 호출, 실시간 서비스 생성, 링톤 제어, 타이머, 종료 후 분석 라우팅을 한 화면에서 다 처리한다.

영향:

- 작은 변경에도 회귀 반경이 커진다.
- 특정 페이지를 이해하려면 한 파일을 길게 따라가야 한다.
- UI 테스트가 거의 없기 때문에, 대형 파일일수록 리팩터링 비용이 급격히 커진다.

개선:

- `lesson_page.dart`는 최소한 아래 단위로 쪼개는 것이 좋다.
  - flow controller
  - step state model
  - step widgets
  - submit/use case
- `voice_call_page.dart`는 `CallSessionController`와 `GeminiLiveFacade`로 나누고, 화면은 상태 렌더링만 담당하게 한다.
- 대형 위젯 파일은 "screen / section / interaction controller" 구조로 분리한다.

### P2. 테스트는 통과하지만, 실제 사용자 플로우 방어력이 약하다

관련 근거:

- `make test`: 182 passed
- 테스트 33개 중 데이터 모델 테스트 27개
- `auth` 테스트 0개
- `practice` 테스트 0개
- `voice_call` 관련 테스트 0개
- 프레젠테이션 테스트는 `apps/mobile/test/features/home/presentation/home_page_test.dart` 1건이 대표적

문제:

- 모델 파싱 테스트는 많은데, 라우팅/온보딩/로그인/설정 저장/음성통화/결제 플로우를 지키는 테스트가 부족하다.
- `study_provider_test.dart`도 이름과 달리 provider가 아니라 모델 파싱 테스트 성격이 강하다.

영향:

- API 스키마가 조금 변해도 모델 테스트는 통과할 수 있다.
- 그러나 실제 UI 흐름이나 라우팅 버그는 쉽게 놓친다.
- 운영 중 가장 비싼 버그는 대개 auth, onboarding, payment, realtime인데 이 영역이 가장 덜 보호되어 있다.

개선:

- 우선순위 높은 위젯/통합 테스트를 먼저 추가한다.
  - 로그인 성공/실패
  - 스플래시 → 인증 → 온보딩/홈 분기
  - 설정 변경 후 재시작 시 유지
  - 음성통화 시작/실패/종료
  - 학습 시작 → 퀴즈 → 결과
- "모델 테스트 많이 있음"을 품질 지표로 쓰지 말고, "핵심 플로우 테스트 있음"으로 지표를 바꾼다.

### P2. 런치 토글이 주석과 레거시 경로에 숨겨져 있다

관련 코드:

- `apps/mobile/lib/core/router/app_router.dart:21-36`
- `apps/mobile/lib/core/router/app_router.dart:346-349`
- `apps/mobile/lib/features/home/presentation/home_page.dart:10`
- `apps/mobile/lib/features/my/presentation/my_page.dart:12`

문제:

- 구독/결제/전화 CTA 등의 활성화 여부가 feature flag가 아니라 주석으로 관리된다.
- `legacy` 진입점과 `legacy_study_page`가 여전히 라우터 안에 있다.

영향:

- 실제 런치 상태와 코드 상태가 어긋나기 쉽다.
- 주석 해제/재주석 방식은 배포 단위 관리, QA, 실험 운영에 취약하다.

개선:

- remote config가 아니어도 최소한 compile-time flag 또는 local feature flag 테이블로 옮긴다.
- `legacy` 경로는 sunset 일정이 없다면 감사 문서에 유지 사유를 명시하고, 없다면 제거 후보로 분류한다.

### P3. 오프라인/알림 동작이 앱 부트와 실제 네트워크 상태를 완전히 대표하지 못한다

관련 코드:

- `apps/mobile/lib/core/network/connectivity_service.dart:4-8`
- `apps/mobile/lib/shared/widgets/offline_banner.dart:9-32`
- `apps/mobile/lib/core/services/local_notification_service.dart:38-180`

문제:

- 오프라인 배너는 `onConnectivityChanged` 스트림만 보며 초기 상태 조회가 없다.
- 즉, 앱이 오프라인으로 시작하면 첫 연결 변경 이벤트 전까지 배너가 안 보일 수 있다.
- 알림 timezone이 `Asia/Seoul`로 하드코딩되어 있다.

영향:

- 한국 서비스라는 제품 방향에는 맞지만, 기기 timezone과의 관계가 코드에 명시적으로 설명되어 있지 않다.
- 여행/해외 사용/시뮬레이터/테스트 환경에서 의도와 실제가 달라질 수 있다.

개선:

- `Connectivity().checkConnectivity()`로 초기 상태를 먼저 주입하고, 이후 스트림으로 이어붙인다.
- timezone 정책은 "항상 한국 시간"인지 "기기 현지 시간"인지 제품 결정으로 문서화한다.

## 세부 관찰

### 실시간 음성 통화 영역은 전략적으로 중요하지만 아직 방어가 약하다

관련 코드:

- `apps/mobile/lib/features/chat/data/gemini_live_service.dart`
- `apps/mobile/lib/features/chat/presentation/voice_call_page.dart:77-176`

관찰:

- 재연결, 녹음, PCM 재생, 전사, auto-analysis 연계까지 한 기능에 많은 책임이 모여 있다.
- `VoiceCallPage`는 `profileDetailProvider`가 준비되지 않았을 때 기본값으로 진행한다.
- 이 영역은 기능 복잡도 대비 테스트가 없다.

판단:

- 이 피처는 "기능적으로는 매력적이지만, 장애시 복구 비용이 큰 영역"이다.
- 지금 단계에서는 신규 기능보다 안정화와 책임 분리가 더 중요하다.

### 홈/학습 화면은 UX 투자 대비 구조 정리가 늦다

관련 코드:

- `apps/mobile/lib/features/home/presentation/home_page.dart`
- `apps/mobile/lib/features/home/presentation/widgets/quick_start_card.dart`
- `apps/mobile/lib/features/study/presentation/study_page.dart`

관찰:

- 홈과 학습은 사용자 가치가 높은 만큼 UI 밀도가 높다.
- 반면 state orchestration이 화면과 섹션 위젯 안쪽으로 들어가고 있어, 이후 개선 속도를 떨어뜨릴 가능성이 높다.

판단:

- 이 영역은 "큰 리팩터링"보다 `section controller` 분리부터 시작하는 것이 현실적이다.

## 우선순위별 개선안

### 1주 내 바로 할 것

1. 앱 시작/인증 경로를 상태 기반 bootstrap으로 변경
2. `_RetryInterceptor`와 `AuthInterceptor`의 raw `Dio()` 제거
3. `NotificationSettingsProvider`와 `QuizSettingsProvider`를 `AsyncNotifier` 또는 bootstrap 로더로 전환
4. `practice_page.dart` 미사용 `_QuickActionCard` 정리

### 2주 내 할 것

1. `lesson_page.dart` 분리 시작
2. `voice_call_page.dart`에서 call session controller 분리
3. auth / onboarding / splash 라우팅 테스트 추가
4. settings persistence 테스트 추가

### 1개월 내 할 것

1. feature flag 체계 도입
2. 레거시 경로 정리
3. 설정 저장 정책 문서화
4. 모바일 핵심 플로우 integration test 세트 구축

## 추천 리팩터링 순서

### Phase 1. Startup and Settings

- `AppBootstrapState`
- `AuthStatus`
- `HydratedAppSettingsRepository`
- router auth guard 재작성

### Phase 2. Network Consistency

- shared api client
- retry/auth refresh 경로 일원화
- auth/social sign-in HTTP 경로 통합

### Phase 3. Study and Voice Call

- `LessonFlowController`
- `VoiceCallController`
- step widgets / call widgets 세분화

### Phase 4. Test Upgrade

- auth / onboarding / startup widget tests
- study flow smoke test
- voice call session state tests

## 최종 판단

이 모바일 앱은 "방향은 맞고 제품 감각도 있으나, 복잡도 관리 장치가 아직 부족한 상태"다.

지금 가장 중요한 것은 새 기능을 더 붙이는 것보다 아래 세 가지다.

- 시작 경로 안정화
- 설정/네트워크 책임 정리
- 대형 화면 파일 분해

이 세 가지를 먼저 처리하면 이후 `study`, `chat`, `subscription`, `notifications` 확장이 훨씬 싸진다. 반대로 이 상태에서 기능을 계속 얹으면, 2~4주 뒤부터는 수정 속도보다 회귀 비용이 더 빨리 커질 가능성이 높다.
