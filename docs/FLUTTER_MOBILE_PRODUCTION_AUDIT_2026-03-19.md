# Flutter Mobile Production Audit (2026-03-19)

## 1) 한줄 총평
Feature-first 구조와 Riverpod 기반 설계는 실무형으로 잘 잡혀 있지만, 프로덕션 신뢰성 관점에서 **음성 통화 mute 동작 불일치, 비동기 setState 안정성, 테스트 게이트 실패**가 남아 있어 "지금 당장 안심 배포" 수준은 아닙니다.

## 2) 점검 범위
- 대상: `apps/mobile`
- 코드 규모: `lib` 211개 Dart 파일, `test` 33개
- 실행 검증:
  - `flutter analyze` -> info 2건 (`prefer_const_constructors`)
  - `flutter test` -> 178개 중 1개 실패
- 아키텍처/유저플로우/디자인/성능/테스트/협업 관점으로 재감사

## 3) 핵심 진단 (우선순위)

### [P0] 음성 통화 "음소거"가 UI 상태만 바뀌고 마이크 오디오는 계속 전송됨
- 근거:
  - mute 버튼은 `_isMuted`만 토글: `apps/mobile/lib/features/chat/presentation/voice_call_page.dart:317-323`
  - 실제 PCM 업로드는 mute 분기 없이 지속: `apps/mobile/lib/features/chat/data/gemini_live_service.dart:288-302`
- 리스크:
  - 사용자 기대(음소거)와 실제 동작(전송) 불일치 -> 신뢰/개인정보 이슈

### [P1] 비동기 이후 mounted 가드 누락으로 `setState() called after dispose` 가능
- 대표 근거:
  - `apps/mobile/lib/features/study/presentation/wrong_answers_page.dart:45-54`
  - `apps/mobile/lib/features/study/presentation/quiz_result_page.dart:64-72`
  - `apps/mobile/lib/features/study/presentation/quiz_page.dart:78-121`
  - `apps/mobile/lib/features/kana/presentation/kana_stage_page.dart:351-355`
- 리스크:
  - 빠른 뒤로가기/탭 전환 시 간헐적 런타임 오류

### [P1] 테스트 게이트가 깨진 상태
- 근거:
  - 실패 테스트: `apps/mobile/test/features/home/presentation/home_page_test.dart:115`
  - 기대값 `'안녕, TestUser!'` vs 실제 시간대 인사 문구 로직: `apps/mobile/lib/features/home/presentation/widgets/home_header.dart:17-22`
- 리스크:
  - CI 신뢰도 저하, 회귀 탐지력 약화

### [P1] 시작 구간 UX 비용이 큼 (고정 지연 + 선권한 요청)
- 근거:
  - 스플래시 고정 3초 지연: `apps/mobile/lib/core/router/app_router.dart:370`
  - 앱 시작 직후 알림 권한 요청: `apps/mobile/lib/main.dart:31-33`
- 리스크:
  - 첫 진입 이탈 증가 가능, 실제 필요 맥락 전 권한 요청

### [P1] 결제 퍼널은 진입 가능하지만 Checkout은 placeholder
- 근거:
  - 구독 선택 시 checkout 이동: `apps/mobile/lib/features/subscription/presentation/pricing_page.dart:33-38`
  - checkout 화면이 "준비 중": `apps/mobile/lib/features/subscription/presentation/checkout_page.dart:47`
- 리스크:
  - 유료 전환 동선 단절, 사용자 신뢰 저하

### [P2] 보안/안정성 보완 필요: WebView 권한 자동 허용
- 근거:
  - `request.grant()` 즉시 호출: `apps/mobile/lib/legacy/webview_screen.dart:115-117`
- 리스크:
  - WebView 경로 활성화 시 과권한 허용 여지

---

## 4) 유저 플로우 평가

### 4.1 전체 플로우 구조
- 강점:
  - Splash -> Login/Onboarding -> MainShell(홈/학습/퀴즈/회화/MY) 흐름이 라우터에 명시적
  - 근거: `apps/mobile/lib/core/router/app_router.dart:61-337`
  - 탭 내 상태 보존형 구조(`StatefulShellRoute.indexedStack`) 채택은 UX에 유리: `.../app_router.dart:101-292`

### 4.2 인증/온보딩 플로우
- 강점:
  - 온보딩 완료 시 분기(가나 학습 여부 기반) 명확
  - 근거: `apps/mobile/lib/features/auth/presentation/onboarding_page.dart:48-53`
- 개선점:
  - `onboarding`의 catch 블록 setState에 mounted 가드가 없음: `.../onboarding_page.dart:55-60`

### 4.3 학습/퀴즈 플로우
- 강점:
  - Stage -> 모드 선택 -> Quiz -> Result 흐름은 일관적
  - 근거: `apps/mobile/lib/features/study/presentation/widgets/study_tab_content.dart:63-77`
- 개선점:
  - 일부 레벨/파라미터 하드코딩 잔존
    - `practice` 고정 N5: `apps/mobile/lib/features/practice/presentation/practice_page.dart:21`
    - voice call jlptLevel TODO: `apps/mobile/lib/features/chat/presentation/voice_call_page.dart:88`
    - wrong answers에서 review quiz N5 고정: `apps/mobile/lib/features/study/presentation/wrong_answers_page.dart:151-154`

### 4.4 회화 플로우
- 강점:
  - 텍스트/음성 허브 분리, 시나리오/캐릭터 흐름 직관적
  - 근거: `apps/mobile/lib/features/chat/presentation/chat_hub_page.dart:130-220`
- 개선점:
  - 히스토리 로딩 기본 limit 5 + UI 페이징 부재
  - 근거: `apps/mobile/lib/features/chat/data/chat_repository.dart:27-33`, `apps/mobile/lib/features/chat/presentation/widgets/conversation_history_list.dart:70-72`

## 5) 아키텍처/구조 평가

### 5.1 구조 성향
- **Feature-first + data/providers/presentation 레이어 분리**
- 근거: `apps/mobile/lib/features/*/(data|providers|presentation)` 디렉토리 일관

### 5.2 장점
- Riverpod + Repository 조합이 기능별로 통일됨
  - 예: `apps/mobile/lib/features/chat/providers/chat_provider.dart:8-23`
- 라우팅 중앙집중으로 진입 경로 추적이 쉬움
  - `apps/mobile/lib/core/router/app_router.dart`

### 5.3 리스크
- 대형 파일 다수(변경 영향도/리뷰 비용 상승)
  - `quick_start_card.dart` 769줄
  - `study_tab.dart` 688줄
  - `study_tab_content.dart` 650줄
  - `quiz_page.dart` 487줄
  - `voice_call_page.dart` 399줄
- `build`에서 post-frame 동기화 수행(부수효과 위치 부적절)
  - `home_page.dart:112-122`
  - `study_page.dart:115-123`
  - `my_page.dart:40-50`

## 6) 코드 품질 평가

### 6.1 긍정
- 정적 분석상 에러/워닝급 이슈가 거의 없음 (`analyze` info 2건)
- 모델 파싱 기본값 처리 습관이 좋아 null 안전성 양호

### 6.2 개선 필요
- 네비게이션 스타일 혼용
  - `context.go/push` 40건 vs `Navigator.push*` 18건
  - 실제 예: pricing에서 `Navigator.push` 사용 (`pricing_page.dart:33-38`), 동시에 go_router route도 존재(`app_router.dart:320-329`)
- 예외 처리 일관성 부족
  - 알림 페이지는 error를 empty UI로 처리: `apps/mobile/lib/features/notifications/presentation/notification_page.dart:37-43`
  - 반면 네트워크 레이어는 Sentry 캡처 + fallback 반환 패턴 혼재: `apps/mobile/lib/features/stats/data/stats_repository.dart:33-35`, `52-55`
- catch `_` 패턴 자체는 즉시 문제는 아니지만, 일부는 관측 가능성(로깅/분류) 손실
  - 예: `apps/mobile/lib/core/services/sound_service.dart:35-37`

## 7) 성능/안정성 평가

### 7.1 긍정
- 주요 화면에서 `ListView.builder` 전환/적용이 진행됨
  - 예: `apps/mobile/lib/features/chat/presentation/conversation_page.dart:186`
- 통계 월별 호출은 병렬화(`Future.wait`)로 개선됨
  - `apps/mobile/lib/features/stats/data/stats_repository.dart:22-40`

### 7.2 잠재 병목
- 히스토리 리스트를 `Column + map`으로 렌더링
  - `apps/mobile/lib/features/chat/presentation/widgets/conversation_history_list.dart:70-72`
  - 아이템 증가 시 build 비용 급증 가능
- TTS 완료 리스너를 재생마다 누적 등록
  - `apps/mobile/lib/core/services/tts_service.dart:33-35`
- 앱 시작 초기화 비용이 한 번에 몰림
  - `main.dart:26-34` (Supabase + 알림 + 사운드 + 햅틱)

## 8) 네트워크/데이터 레이어 평가

### 8.1 장점
- 공통 `Dio` 설정 + 타임아웃/재시도/에러 매핑 존재
  - `apps/mobile/lib/core/network/dio_client.dart:8-33`
- 기능별 repository 분리가 명확해 API 변경 영향 반경이 제한됨

### 8.2 개선점
- 재시도 시 새 Dio 인스턴스를 만들어 기존 인터셉터 체인이 유지되지 않음
  - `apps/mobile/lib/core/network/dio_client.dart:68-74`
- DTO/Entity를 억지로 분리할 필요는 없지만, 현재는 API model이 화면 요구를 직접 반영해 backend 스키마 변화에 민감

## 9) 테스트/유지보수/협업 평가

### 9.1 테스트
- 테스트 분포가 모델 중심으로 치우침
  - model test 27개, presentation test 1개
- 핵심 플로우(라우팅 redirect, 온보딩 완료, 결제, 음성통화)는 위젯/통합 테스트 공백

### 9.2 유지보수/협업
- 장점:
  - 네이밍, feature 분리, provider/repository 패턴이 팀 온보딩에 유리
- 리스크:
  - 대형 파일 + 혼합 네비게이션으로 PR 단위가 커지고 리뷰 난이도 상승

## 10) 디자인 시스템/컴포넌트 평가

### 10.1 장점
- 테마/컬러/사이즈 토큰 체계는 분명함
  - `apps/mobile/lib/core/theme/app_theme.dart`
  - `apps/mobile/lib/core/constants/colors.dart`
  - `apps/mobile/lib/core/constants/sizes.dart`
- 타이포그래피도 GoogleFonts 기반으로 통일
  - `apps/mobile/lib/core/theme/text_theme.dart:5-74`

### 10.2 개선점
- feature 레벨 하드코딩 색상이 아직 많음
  - `Color(0x...)` 사용: lib 전체 102건, features 하위 32건
  - 예: `apps/mobile/lib/features/practice/presentation/practice_page.dart:217-348`
- Widgetbook 커버리지가 작음(컴포넌트 5개)
  - `apps/mobile/lib/widgetbook.dart:34-166`
  - 핵심 위젯(QuickStartCard, StageCard, Voice/Chat 카드) 미등록

## 11) 보안/안정성 평가

- 환경변수 관리 자체는 양호 (`String.fromEnvironment`)
  - `apps/mobile/lib/core/constants/app_config.dart:2-10`
- `.env` git ignore 처리 확인
  - `apps/mobile/.gitignore:48`
- Google OAuth client id 하드코딩은 일반적으로 secret이 아님
  - `apps/mobile/lib/core/constants/app_config.dart:12-13`
- 다만 WebView 권한 자동 허용은 별도 리스크(P2)

## 12) 우선순위별 개선 과제

### 즉시 수정 (이번 스프린트)
1. 음성통화 mute를 전송 레이어에 실제 반영 (`GeminiLiveService` mute 분기)
2. `mounted` 가드 누락 화면 일괄 보강
3. 깨진 홈 위젯 테스트 복구 및 CI 게이트 재활성
4. 시작 권한 요청을 기능 진입 시점으로 이동(알림 opt-in)
5. 결제 CTA 정책 정리(실결제 전까지 진입 제한 or 명확한 베타 라벨)

### 단기 개선 (1~2주)
1. `Column + map` 리스트를 `ListView.builder`/paginated list로 전환
2. TTS complete listener 등록 구조 개선(중복 구독 방지)
3. `build` 내부 post-frame 동기화를 provider listener/init 흐름으로 이동
4. 알림의 error/empty 상태 분리

### 중장기 개선 (3~6주)
1. 대형 파일 분해(뷰/상태/액션 단위)
2. Widgetbook 핵심 위젯 커버리지 확대
3. 핵심 유저 플로우 위젯/통합 테스트 추가(로그인, 온보딩, 퀴즈 완료, 통화 종료)
4. 디자인 토큰 강제 규칙(리뷰 체크리스트 + lint/custom rule) 도입

## 13) 점수 (프로덕션 관점)
- 아키텍처: 79/100
- 유저 플로우: 72/100
- 코드 품질: 74/100
- 성능/안정성: 69/100
- 디자인 시스템 성숙도: 72/100
- 테스트 가능성: 61/100
- 협업 적합성: 75/100
- **총점: 72/100**

## 14) 결론
- 현재 코드는 **중상급 실무형**에 가깝고, 구조 방향은 맞습니다.
- 다만 배포 신뢰성 기준에서 **P0/P1 항목(특히 음성 mute, async setState, 테스트 실패)**을 먼저 정리해야 합니다.
- 위 즉시 수정 5개를 마치면, 운영 안정성과 팀 협업 효율이 눈에 띄게 올라갑니다.
