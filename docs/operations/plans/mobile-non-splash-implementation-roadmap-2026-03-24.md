# Mobile Non-Splash Implementation Roadmap (2026-03-24)

> 스플래시를 제외한 모바일 구조 개선 실행 로드맵. 설계 문서의 방향을 실제 작업 순서, 의존성, 완료 기준으로 변환한 문서다.

## 목적

이 로드맵은 아래를 해결하기 위한 실행 계획이다.

- 네트워크/인증 경로 일원화
- 설정 상태 소스 오브 트루스 정리
- `study`와 `chat`의 세션 로직 분해
- 플로우 테스트 보강
- 주석 기반 런치 토글/레거시 경로 정리

스플래시 정책은 이 로드맵의 범위에서 제외한다.

- 관련 문서: `docs/operations/mobile/mobile-startup-splash-policy-2026-03-24.md`
- 설계 원문: `docs/operations/plans/mobile-non-splash-improvement-design-2026-03-24.md`

## 핵심 원칙

### 1. 리라이트 금지

- Riverpod 유지
- Dio 유지
- GoRouter 유지
- feature-based 구조 유지

### 2. 순서가 중요하다

아래 순서를 바꾸면 재작업 가능성이 높아진다.

1. 네트워크/인증
2. 설정 상태
3. 세션 분해
4. 플로우 테스트
5. feature flag / legacy 정리

### 3. 각 Phase는 독립 완료 기준이 있어야 한다

중간 상태가 길어지면 구조가 더 혼란스러워진다. 따라서 각 단계는 "머지 가능한 완료 상태"를 가져야 한다.

## 전체 로드맵

```text
Phase 0  Baseline + quick wins
Phase 1  Network/Auth foundation
Phase 2  Settings source-of-truth
Phase 3  Study session extraction
Phase 4  Voice call/session extraction
Phase 5  Flags/legacy cleanup + flow test hardening
```

## Phase 0. Baseline + Quick Wins

> 목표: 구조 리팩터링 전에 작업 기반을 정리한다. 큰 변화는 하지 않고, 측정 가능성과 잡음 제거가 목적이다.

### 작업

1. 모바일 분석/테스트 기준선 문서화
2. `practice_page.dart` 미사용 `_QuickActionCard` 제거
3. mobile CI 상태 확인 또는 최소한 로컬 실행 절차 고정
4. 감사 문서와 설계 문서를 팀 작업 기준으로 연결

### 대상 파일

- `apps/mobile/lib/features/practice/presentation/practice_page.dart`
- `docs/operations/audits/mobile-architecture-audit-2026-03-24.md`
- `docs/operations/plans/mobile-non-splash-improvement-design-2026-03-24.md`

### 완료 기준

- `make analyze` 경고 0
- `make test` 통과
- Phase 1 작업자가 현재 기준선을 오해하지 않도록 문서 링크 정리 완료

### 예상 규모

- 작음

## Phase 1. Network/Auth Foundation

> 목표: 모든 앱 API 요청 경로를 명시적 구조로 통제한다. 이 단계가 이후 설정/세션 분해의 기반이다.

### 핵심 문제

- raw `Dio()` 경로가 3군데 이상 존재
- retry와 auth refresh가 분리되어 동작
- social login exchange가 공통 클라이언트를 우회

### 작업

1. `AppHttpClient` 도입
2. `AuthRefreshClient` 또는 refresh 전용 executor 도입
3. `AuthSessionManager` 도입
4. `AuthInterceptor` 단순화
5. `AuthRepository.signInWithKakao()`의 raw `Dio()` 제거
6. request metadata 설계
7. retry/auth contract test 추가

### 대상 파일

- `apps/mobile/lib/core/network/dio_client.dart`
- `apps/mobile/lib/core/network/auth_interceptor.dart`
- `apps/mobile/lib/core/providers/dio_provider.dart`
- `apps/mobile/lib/features/auth/data/auth_repository.dart`
- 신규:
  - `apps/mobile/lib/core/network/app_http_client.dart`
  - `apps/mobile/lib/core/network/auth_refresh_client.dart`
  - `apps/mobile/lib/core/auth/auth_session_manager.dart`

### 완료 기준

- Repository 직접 `Dio()` 생성 0건
- 401 refresh 처리 경로가 `AuthSessionManager` 기준으로 일원화
- 일반 API와 refresh/exchange 전용 경로가 코드상 분리
- auth/retry 테스트 추가 후 통과

### 리스크

- refresh 루프
- interceptor 순서 변경으로 인한 회귀

### 방어책

- 기존 `auth_interceptor_test.dart` 유지 확장
- refresh 실패/동시 401/쿨다운 케이스를 회귀 테스트로 고정

### 예상 규모

- 중간

## Phase 2. Settings Source-Of-Truth

> 목표: 설정 상태를 `device-scoped`와 `user-scoped`로 나누고, 중복 저장을 제거한다.

### 핵심 문제

- `theme`, `furigana`, `notification`, `callSettings`의 책임이 섞여 있음
- provider `build()`에서 async load + side effect 발생
- local/server 혼합 상태가 디버깅 비용을 올림

### 작업

1. 설정 분류 최종 확정
2. `DeviceSettings` 모델/리포지토리 도입
3. `UserPreferences` 모델/리포지토리 도입
4. `themeProvider` 영속화
5. `quizSettingsProvider`를 `UserPreferences`로 흡수
6. `notificationSettingsProvider`를 hydration 가능한 구조로 개편
7. `my_page`의 설정 업데이트 경로 정리
8. notification schedule apply 시점 명시화

### 대상 파일

- `apps/mobile/lib/core/providers/theme_provider.dart`
- `apps/mobile/lib/core/providers/quiz_settings_provider.dart`
- `apps/mobile/lib/core/providers/notification_settings_provider.dart`
- `apps/mobile/lib/features/my/presentation/my_page.dart`
- `apps/mobile/lib/features/my/presentation/widgets/app_settings_section.dart`
- `apps/mobile/lib/features/my/presentation/widgets/settings_menu.dart`
- `apps/mobile/lib/features/my/data/my_repository.dart`
- 신규:
  - `apps/mobile/lib/core/settings/device_settings.dart`
  - `apps/mobile/lib/core/settings/device_settings_repository.dart`
  - `apps/mobile/lib/core/settings/user_preferences.dart`
  - `apps/mobile/lib/core/settings/user_preferences_repository.dart`
  - `apps/mobile/lib/core/settings/settings_sync_service.dart`

### 완료 기준

- 설정별 소스 오브 트루스 문서화 완료
- `Notifier.build()` 내부 fire-and-forget 로딩 제거
- 앱 재시작 후 theme / notification / furigana 유지 테스트 통과
- `showFurigana` 중복 저장 경로 제거 또는 임시 브리지로 축소

### 리스크

- 다기기 동기화 의미가 바뀔 수 있음
- 사용자 체감상 설정이 잠깐 바뀌는 회귀 가능성

### 방어책

- 설정 변경 후 재마운트 테스트
- 서버값 우선/로컬값 우선 규칙을 문서로 고정

### 예상 규모

- 중간~큼

## Phase 3. Study Session Extraction

> 목표: `study` 피처의 가장 비싼 지점부터 쪼갠다. 우선순위는 `lesson_page`와 `quiz_page`다.

### 핵심 문제

- `lesson_page.dart` 2,000줄 이상
- `quiz_page.dart`가 세션 생명주기를 직접 관리
- 상태 전이와 UI가 한 파일에 결합

### 작업

1. `LessonFlowController` 도입
2. 레슨 step widget 분리
3. lesson submit/use case 분리
4. `QuizSessionController` 도입
5. 퀴즈 세션 초기화/start/resume/complete 분리
6. study flow controller tests 추가

### 대상 파일

- `apps/mobile/lib/features/study/presentation/lesson_page.dart`
- `apps/mobile/lib/features/study/presentation/quiz_page.dart`
- `apps/mobile/lib/features/study/providers/study_provider.dart`
- 신규:
  - `apps/mobile/lib/features/study/application/lesson_flow_controller.dart`
  - `apps/mobile/lib/features/study/application/lesson_submission_service.dart`
  - `apps/mobile/lib/features/study/application/quiz_session_controller.dart`
  - `apps/mobile/lib/features/study/application/quiz_session_state.dart`

### 완료 기준

- `lesson_page.dart` 책임 축소
- step UI와 flow 상태가 분리
- `quiz_page.dart`가 session orchestration을 직접 하지 않음
- lesson/quiz controller 테스트 추가

### 리스크

- study UX 회귀
- back navigation / resume 흐름 회귀

### 방어책

- 단계별 머지
- `study` 관련 smoke widget test 또는 controller test 추가 후 진행

### 예상 규모

- 큼

## Phase 4. Voice Call / Chat Session Extraction

> 목표: 음성 통화 영역을 "매력적인 기능"에서 "운영 가능한 기능"으로 바꾼다.

### 핵심 문제

- `VoiceCallPage`가 UI + bootstrap + timer + end-call decision을 모두 담당
- `GeminiLiveService`와 화면 사이의 경계가 얇음
- 테스트 공백이 큼

### 작업

1. `CallBootstrapService` 도입
2. `VoiceCallController` 도입
3. `VoiceCallState` 정의
4. `VoiceCallPage`를 render shell로 축소
5. 통화 설정 저장 경로와 세션 시작 경로 정리
6. 연결 실패/재연결/종료 테스트 추가

### 대상 파일

- `apps/mobile/lib/features/chat/presentation/voice_call_page.dart`
- `apps/mobile/lib/features/chat/presentation/chat_hub_page.dart`
- `apps/mobile/lib/features/chat/data/gemini_live_service.dart`
- `apps/mobile/lib/features/chat/data/chat_repository.dart`
- 신규:
  - `apps/mobile/lib/features/chat/application/voice_call_controller.dart`
  - `apps/mobile/lib/features/chat/application/voice_call_state.dart`
  - `apps/mobile/lib/features/chat/data/call_bootstrap_service.dart`

### 완료 기준

- `VoiceCallPage`에서 live token / character detail / timer orchestration 제거
- 음성 세션 생명주기를 controller가 관리
- call settings 저장 후 반영 경로 명확화
- voice call 관련 회귀 테스트 추가

### 리스크

- 실시간 통화는 재현이 어려워서 숨은 회귀가 생기기 쉬움

### 방어책

- controller 레벨에서 상태 전이 테스트 우선
- websocket/audio transport는 기존 서비스 유지, orchestration만 먼저 분리

### 예상 규모

- 큼

## Phase 5. Feature Flags / Legacy Cleanup / Flow Tests

> 목표: 주석 기반 상태 관리를 끝내고, 운영 중 비싼 버그를 잡는 테스트로 품질 기준을 올린다.

### 작업

1. compile-time 또는 local feature flag 테이블 도입
2. 주석 처리된 라우트/CTA 정리
3. `legacy` 경로 유지 여부 결정
4. auth/onboarding/settings/practice/voice_call 플로우 테스트 추가
5. 문서와 코드의 launch 상태 일치화

### 대상 파일

- `apps/mobile/lib/core/router/app_router.dart`
- `apps/mobile/lib/features/home/presentation/home_page.dart`
- `apps/mobile/lib/features/my/presentation/my_page.dart`
- 신규:
  - `apps/mobile/lib/core/config/feature_flags.dart`
- 테스트:
  - `apps/mobile/test/features/auth/**`
  - `apps/mobile/test/features/chat/**`
  - `apps/mobile/test/features/study/**`
  - `apps/mobile/test/features/my/**`

### 완료 기준

- 주석으로 끄는 기능/라우트 제거
- feature flag로 launch 상태 제어
- `auth`, `practice`, `voice_call` 테스트 공백 축소
- 운영 문서와 실제 코드 상태 일치

### 예상 규모

- 중간

## 병렬화 전략

### 병렬 가능한 조합

- Phase 1과 Phase 0 일부
- Phase 2의 device settings 정리와 user preferences 모델링
- Phase 3의 lesson flow와 quiz session 분리
- Phase 5의 문서/flag 정리와 일부 테스트 추가

### 병렬 비추천 조합

- Phase 1과 Phase 4 동시 대규모 진행
  - 네트워크/세션 경로가 동시에 바뀌면 원인 분리가 어려움
- Phase 2 완료 전 Phase 4의 call settings 전면 개편
  - 설정 소스 오브 트루스가 안 정해진 상태에서 재작업 가능성 큼

## 권장 실행 순서

### 가장 현실적인 3스프린트안

#### Sprint 1

- Phase 0 완료
- Phase 1 완료
- Phase 2 착수

#### Sprint 2

- Phase 2 완료
- Phase 3 착수

#### Sprint 3

- Phase 3 완료
- Phase 4 완료
- Phase 5 핵심 항목 완료

## 각 스프린트의 종료 기준

### Sprint 1 종료 기준

- raw `Dio()` 제거
- auth/retry 경로 통일
- analyze/test 통과

### Sprint 2 종료 기준

- 설정 소스 오브 트루스 문서화
- 설정 hydration 회귀 테스트 추가
- study session 분리 시작점 안정화

### Sprint 3 종료 기준

- lesson/voice call 세션 분리 완료
- feature flag 최소 도입
- 핵심 플로우 테스트 세트 확보

## 하지 말아야 할 것

- state management 라이브러리 교체
- 전 feature 일괄 리팩터링
- UI 재디자인과 구조 리팩터링 동시 진행
- 테스트 없이 `lesson_page` 대형 분리 강행
- 주석 기반 런치 토글을 임시로 더 늘리는 것

## 최종 판단

이 로드맵은 "예쁘게 정리된 기술 계획"이 아니라, 실제로 가장 비싼 문제부터 잘라내는 순서다.

가장 중요한 것은 아래 두 가지다.

1. 먼저 네트워크와 설정을 정리한다
2. 그 다음에야 `study`와 `voice_call`을 분해한다

이 순서를 지키면 재작업이 줄고, 각 스프린트가 머지 가능한 안정 상태로 끝난다. 이 순서를 어기면 화면만 분해한 뒤 다시 네트워크/설정 때문에 뜯어고치게 될 가능성이 높다.
