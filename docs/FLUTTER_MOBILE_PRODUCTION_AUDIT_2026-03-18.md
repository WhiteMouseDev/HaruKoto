# Flutter Mobile Production Audit (2026-03-18)

## 1) 한줄 총평
기능 완성도는 높고 Feature-first 구조도 일관적이지만, "실무 배포 기준"에서는 몇 가지 치명적 운영 리스크(음성 통화 음소거 무효, 결제 플로우 미완성, 비동기 setState 안정성)가 남아 있습니다.

## 2) 점검 범위 및 방법
- 코드베이스: `apps/mobile/lib` 211개 Dart 파일, `apps/mobile/test` 33개 테스트 파일
- 구조 점검: 라우팅, 인증, 홈/학습/퀴즈/회화/마이/통계/구독/알림 전반
- 품질 점검: 아키텍처, 상태관리, 책임 분리, 에러 처리, 성능/안정성, 테스트
- 실행 검증:
  - `flutter analyze` -> info 2건 (`prefer_const_constructors`)
  - `flutter test` -> 178개 중 1개 실패

---

## 3) 핵심 진단 (우선순위 순)

### [P0] 음성 통화 "음소거"가 UI만 바뀌고 실제 오디오 업로드는 계속됨
- 근거:
  - 음소거 토글은 `_isMuted` 상태만 변경 (`apps/mobile/lib/features/chat/presentation/voice_call_page.dart:317`)
  - 실제 마이크 스트림 전송은 mute 상태 체크 없이 항상 실행 (`apps/mobile/lib/features/chat/data/gemini_live_service.dart:288`)
- 리스크:
  - 사용자는 음소거됐다고 믿는데 서버로 음성이 전송될 수 있음 (프라이버시/신뢰 이슈)
- 권고:
  - `GeminiLiveService`에 `setMuted(bool)` 추가 후 전송 분기에서 mute 시 전송 차단

### [P0] 결제 진입 플로우는 열려 있는데 실제 Checkout은 "준비 중" 화면
- 근거:
  - My -> Pricing 진입 가능 (`apps/mobile/lib/features/my/presentation/my_page.dart:66`)
  - Pricing에서 구독 선택 시 Checkout 이동 (`apps/mobile/lib/features/subscription/presentation/pricing_page.dart:33`)
  - Checkout은 결제 미구현 placeholder (`apps/mobile/lib/features/subscription/presentation/checkout_page.dart:47`)
- 리스크:
  - 프로덕션에서 유료 전환 퍼널 단절, 사용자 신뢰 저하, CS 증가
- 권고:
  - 실제 결제 연동 전에는 진입 자체를 feature flag로 숨기거나 "사전 알림/대기" UX로 명확히 분리

### [P1] 비동기 이후 `mounted` 체크 누락으로 `setState() called after dispose` 가능성
- 근거 (대표):
  - `WrongAnswersPage` 데이터 fetch 후 즉시 `setState` (`apps/mobile/lib/features/study/presentation/wrong_answers_page.dart:45`)
  - `QuizResultPage` 오답 로드 후 `setState` (`apps/mobile/lib/features/study/presentation/quiz_result_page.dart:64`)
  - `QuizPage` 초기화 분기들에서 await 후 연속 `setState` (`apps/mobile/lib/features/study/presentation/quiz_page.dart:78`, `101`, `113`, `121`)
  - `KanaStagePage` complete API await 후 `setState` (`apps/mobile/lib/features/kana/presentation/kana_stage_page.dart:351`)
- 리스크:
  - 빠른 화면 전환/백그라운드 전환 시 런타임 예외 가능
- 권고:
  - await 직후 공통 `if (!mounted) return;` 패턴 적용

### [P1] WebView 권한 요청을 무조건 허용
- 근거:
  - `onPermissionRequest`에서 `request.grant()` 즉시 호출 (`apps/mobile/lib/legacy/webview_screen.dart:115`)
- 리스크:
  - WebView 페이지가 요청한 민감 권한을 사용자 의도와 무관하게 허용 가능
- 권고:
  - 요청 권한 타입별 allow-list + 사용자 확인 플로우 추가

### [P1] 테스트가 깨진 상태로 방치
- 근거:
  - 실패 테스트: `home_page_test`가 `'안녕, TestUser!'`를 기대 (`apps/mobile/test/features/home/presentation/home_page_test.dart:115`)
  - 실제 헤더는 시간대 기반 문구 (`apps/mobile/lib/features/home/presentation/widgets/home_header.dart:19`)
- 리스크:
  - CI 신뢰도 하락, 회귀 검출력 약화
- 권고:
  - 테스트 기대값을 시간대 독립적으로 수정하거나 greeting generator를 주입 가능하게 분리

---

## 4) 유저 플로우 평가

### 4.1 앱 시작/인증
- 강점:
  - Splash -> Auth -> Onboarding -> Main 진입 흐름은 라우터에서 명확히 분기됨 (`apps/mobile/lib/core/router/app_router.dart:64`)
- 이슈:
  - Splash 고정 3초 지연 (`apps/mobile/lib/core/router/app_router.dart:370`) + profile fetch까지 추가 대기
  - 앱 시작 즉시 알림 권한 요청 (`apps/mobile/lib/main.dart:31`)으로 초기 진입 UX 방해 가능

### 4.2 학습/퀴즈
- 강점:
  - Stage -> 모드 선택 -> Quiz -> Result 흐름이 일관적이며 재도전/복습 유도 UX가 있음
- 이슈:
  - 레벨 하드코딩 지점 존재:
    - Practice 기본 레벨 고정 N5 (`apps/mobile/lib/features/practice/presentation/practice_page.dart:21`)
    - 오답 복습 퀴즈도 N5 고정 (`apps/mobile/lib/features/study/presentation/wrong_answers_page.dart:153`)

### 4.3 회화(텍스트/음성)
- 강점:
  - 허브 -> 카테고리 -> 시나리오 -> 대화/피드백 흐름이 자연스럽고 전환도 빠름
- 이슈:
  - 음소거 기능 불일치(P0)
  - 회화 히스토리는 provider 기본 limit 5로 짧고 페이징 UI 없음 (`apps/mobile/lib/features/chat/data/chat_repository.dart:27`, `apps/mobile/lib/features/chat/providers/chat_provider.dart:21`)

### 4.4 구독/결제
- 강점:
  - 구독 상태, 결제내역, 취소/재개 동선은 My 화면에 잘 노출
- 이슈:
  - 실제 결제 미완성 상태에서 구매 CTA가 살아있음(P0)

---

## 5) 아키텍처/구조 평가

### 구조 성향
- **Feature-first + data/providers/presentation 혼합형**
- 현재 규모(11개 feature)에서는 현실적으로 유지 가능한 구조

### 강점
- Feature 디렉토리 구조 일관 (`apps/mobile/lib/features/*`)
- Riverpod + Repository 패턴 전반 적용
- 공통 테마/상수/쉘 위젯 분리 (`core`, `shared`)

### 리스크
- 대형 파일 집중(유지보수성 저하):
  - `quick_start_card.dart` 769줄
  - `study_tab_content.dart` 650줄
  - `study_tab.dart` 688줄
  - `quiz_page.dart` 487줄
  - `kana_stage_page.dart` 420줄
- `build()` 내부 부수효과(동기화/탭 재구성):
  - `HomePage` furigana sync (`apps/mobile/lib/features/home/presentation/home_page.dart:112`)
  - `StudyPage` 탭 업데이트 post-frame (`apps/mobile/lib/features/study/presentation/study_page.dart:115`)
  - `MyPage` furigana sync (`apps/mobile/lib/features/my/presentation/my_page.dart:41`)
- 네비게이션 혼용은 의도 가능하지만, 일부는 불필요한 불일치:
  - 전체 호출 58건 중 `Navigator.push` 18건, `context.go/push` 40건
  - 예: pricing->checkout은 Navigator, 라우터엔 `/subscription/checkout`도 존재

---

## 6) 코드 품질 평가

### 강점
- Null safety 활용 양호
- 모델 파싱 기본값 처리 습관이 좋아 런타임 방어에 유리
- `flutter analyze` 경고/에러 수준 이슈 거의 없음

### 개선 필요
- 하드코딩 비즈니스 값(레벨/카운트/카테고리 수)
  - 카테고리 시나리오 수 텍스트 하드코딩 (`apps/mobile/lib/features/chat/presentation/widgets/category_grid.dart:22`)
- 예외 처리 UX 일관성 부족
  - 알림 페이지에서 error를 empty로 표시 (`apps/mobile/lib/features/notifications/presentation/notification_page.dart:39`)
- 문서와 실제 구현 불일치
  - README Widgetbook 설명에 존재하지 않는 컴포넌트명 표기 (`apps/mobile/README.md:46`)

---

## 7) 성능/안정성 평가

### 긍정
- 주요 리스트는 `ListView.builder` 사용 비율이 높아 기본 스크롤 성능은 양호
- Stats 월별 이력 조회는 병렬화되어 기존 병목 개선 (`apps/mobile/lib/features/stats/data/stats_repository.dart:22`)

### 리스크
- `ConversationHistoryList`는 `Column + map` 렌더링 (`apps/mobile/lib/features/chat/presentation/widgets/conversation_history_list.dart:70`)
- `TtsService`에서 재생 완료 리스너를 매번 추가 (`apps/mobile/lib/core/services/tts_service.dart:33`) -> 누적 리스너 가능성
- 무한 반복 애니메이션 위젯 존재 (`apps/mobile/lib/features/home/presentation/widgets/streak_daily_card.dart:377`) -> 저사양 기기 배터리 소모 가능

---

## 8) 네트워크/데이터 레이어 평가

### 강점
- `Dio + AuthInterceptor + ApiException` 공통화
- 기능별 repository 분리로 API 변경 영향 범위 제한

### 개선 필요
- `_RetryInterceptor`가 재시도 시 새로운 Dio 인스턴스 사용 (`apps/mobile/lib/core/network/dio_client.dart:68`) -> 인터셉터 체인/정책 일관성 저하
- 일부 화면은 repository 실패를 fallback 데이터로 숨겨 장애 인지가 늦어질 수 있음 (stats/notifications)

---

## 9) 테스트/협업 평가

### 현재 상태
- 테스트 수량은 나쁘지 않으나(33 파일), 대부분 모델 단위 테스트
- 위젯/플로우 E2E 관점 테스트는 부족
- 현재 테스트 1건 실패 상태

### 협업 관점
- 폴더/네이밍/레이어 컨벤션은 비교적 명확
- 다만 대형 파일은 PR 리뷰 단위가 커져 충돌/리뷰 비용 증가

---

## 10) 디자인/컴포넌트 시스템 평가

### 강점
- `AppTheme`, `AppColors`, `AppSizes`가 있어 기본 디자인 시스템은 존재
- 주요 화면에서 브랜드 톤/모션이 일관적

### 개선 필요
- feature 내부에서 직접 `Color(0x...)` 사용 다수로 토큰 우회
- Widgetbook 커버리지 제한적
  - 등록 컴포넌트 5개/UseCase 5개 (`apps/mobile/lib/widgetbook.dart`)
  - 실제 대형 핵심 위젯(QuickStart, StageCard, Chat 카드 등) 미등록

---

## 11) 종합 점수 (배포 기준)
- 아키텍처: 78/100
- 코드 품질: 74/100
- 성능/안정성: 70/100
- 유지보수성: 72/100
- 테스트 가능성: 63/100
- 협업 적합성: 75/100
- **총점: 72/100**

> 해석: "중상급" 수준 코드베이스. 실서비스 운영은 가능하지만, P0/P1 항목을 정리하지 않으면 장애/신뢰 이슈 가능성이 큼.

---

## 12) 우선순위별 개선 과제

### 즉시 수정 (이번 스프린트)
1. 음성 통화 mute 실제 적용 (전송 차단)
2. 결제 플로우 정책 결정 (구현 or CTA 차단)
3. async `setState` 안전화 (`mounted` 가드 일괄 적용)
4. 깨진 테스트 복구 (`home_page_test`)
5. WebView 권한 자동 grant 제거

### 단기 개선 (1~2주)
1. 대형 Stateful 파일 분해 (View/State/Action 분리)
2. `build()` 내부 부수효과 제거 (provider listener/init 단계로 이동)
3. 히스토리 목록 페이징/지연 로딩 적용
4. 알림/통계 에러 상태를 empty와 분리

### 중장기 개선 (3~6주)
1. 공통 Async 화면 스캐폴드(loading/error/empty) 컴포넌트화
2. Widgetbook 핵심 위젯 등록 확대
3. 테마/학습설정 영속화(ThemeMode 등) 정책 정리
4. 핵심 플로우 통합 테스트(로그인/온보딩/퀴즈 완료/회화 종료) 구축

---

## 13) 결론
- 현재 코드는 "기능 개발력"은 충분히 보이며, 구조도 실무형 Feature-first로 정돈되어 있습니다.
- 다만 프로덕션 신뢰성 관점에서 **P0/P1 5개 항목**은 배포 전 반드시 정리해야 합니다.
- 위 항목 해소 시, 이 프로젝트는 팀 협업/지속 운영에 적합한 중상급 코드베이스로 평가할 수 있습니다.
