# Flutter Widget 구조 재분석 보고서 (3차, 2026-03-13)

## 1) 총평
직전 피드백의 P0 항목 3건은 모두 해결되었습니다. 현재 상태는 **실무 기준 중상급(안정화 단계)**이며, 다음 병목은 “대형 Stateful 분해”와 “Async UI 표준화”입니다.

## 2) 재분석 스냅샷
- 대상: `apps/mobile/lib`, `apps/mobile/test`
- Dart 파일: **192개**
- Widget 클래스: **155개**
  - Public: 125
  - Private: 30
- Shared widgets: 6개
- Widgetbook components: 6개
- `flutter analyze`: 통과
- `flutter test`: 통과 (**155 tests passed**)

## 3) 직전 보고서 지적사항 추적

| 항목 | 직전 상태 | 현재 상태 | 근거 |
|---|---|---|---|
| `RecommendTab` 타입 미정 (`AsyncValue`/`dynamic`) | 미해결 | **해결** | `apps/mobile/lib/features/study/presentation/widgets/recommend_tab.dart:10`, `:50` |
| Home raw error 문자열 노출 | 미해결 | **해결** | `apps/mobile/lib/features/home/presentation/home_page.dart:50-55` |
| MyPage 바텀시트 controller dispose 누락 | 미해결 | **해결** | `apps/mobile/lib/features/my/presentation/my_page.dart:305` |

## 4) 이번에 확인된 추가 개선

### 4.1 Notifications feature 신설
- `apps/mobile/lib/features/notifications/*`
- 홈 헤더와 라우팅 연결 완료
  - `apps/mobile/lib/features/home/presentation/widgets/home_header.dart:15`, `:46`
  - `apps/mobile/lib/core/router/app_router.dart:289`

### 4.2 에러 UI 재사용 증가
- `AppErrorRetry` 사용 지점: 7곳
- 공통화된 `PaginationFooter` 사용 유지: 4곳

## 5) 현재 남은 핵심 리스크

## P1

### 5.1 대형 Stateful 화면 응집도 여전히 높음
- `quiz_page.dart` 469줄
- `kana_stage_page.dart` 433줄
- `conversation_page.dart` 396줄

리스크:
- 상태 전이 + 네트워크 + 렌더링 + 내비게이션이 한 클래스에 집중되어 회귀 테스트 비용이 큼.

권장:
- `Controller (flow/state)` + `View (render)`로 단계 분리.

### 5.2 Async 상태 UI 표준 컴포넌트 부재
중복 위치 예시:
- `learned_words_content.dart:41`
- `wrong_answers_content.dart:42`
- `wordbook_page.dart:291`
- `notification_page.dart:37-41`

리스크:
- 로딩/에러/빈상태 표현 불일치, 정책 변경 시 수정 포인트 분산.

권장:
- `AsyncStateView<T>`를 shared로 도입.

## P2

### 5.3 침묵 예외(`catch (_)`) 잔존 5건
- `apps/mobile/lib/features/auth/presentation/login_page.dart:138`
- `apps/mobile/lib/features/auth/presentation/onboarding_page.dart:63`
- `apps/mobile/lib/features/home/presentation/widgets/weekly_chart.dart:17`
- `apps/mobile/lib/features/chat/presentation/widgets/conversation_history_list.dart:202`
- `apps/mobile/lib/features/chat/presentation/widgets/feedback_transcript.dart:30`

권장:
- 최소 `debugPrint` 또는 Sentry 로깅 추가.

### 5.4 Widgetbook 커버리지 정체
- 현재 6개 컴포넌트(`widgetbook.dart`)로, 공통 위젯 증가 대비 카탈로그화가 따라오지 못함.

권장:
- `PaginationFooter`, `NotificationTile`, `RecommendationCard` 우선 등록.

## 6) 평가 점수 (이번 재분석)

| 항목 | 점수(100) | 코멘트 |
|---|---:|---|
| 아키텍처/분리도 | 79 | 직전 P0 해결, 대형 Stateful는 잔존 |
| 코드 품질 | 81 | 타입 안정성 개선, 침묵 catch 일부 잔존 |
| 성능/렌더링 구조 | 73 | 큰 화면 구조상 잠재 병목 여전 |
| 유지보수성 | 82 | 공통화 흐름은 명확, Async 표준화 필요 |
| 테스트 가능성 | 70 | 테스트 양/범위 확대는 뚜렷 |
| 협업 적합성 | 82 | 규칙이 코드로 반영되는 단계 |
| 총점 | **78** | 실무 투입 신뢰도 높아진 상태 |

## 7) 다음 추천 작업 (우선순위)

1. `AsyncStateView<T>` 도입 후 `wordbook/learned/wrong/notification` 화면 치환
2. `quiz_page`, `kana_stage_page`, `conversation_page`를 flow/controller 분리
3. `catch (_)` 5건 제거 + 로깅 통일
4. Widgetbook에 신규 공통 위젯 3개 이상 추가

## 8) 결론
현재 수정은 방향이 매우 정확했고, 직전 핵심 리스크를 실제로 해소했습니다.

이제부터는 “대형 화면 구조 분해”만 진행하면, 유지보수성/테스트성에서 시니어 레벨 코드베이스에 훨씬 가까워집니다.
