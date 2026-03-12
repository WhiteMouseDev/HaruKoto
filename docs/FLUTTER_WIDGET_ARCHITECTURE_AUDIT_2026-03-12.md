# Flutter Widget 구조 정밀 분석 보고서 (2026-03-12)

## 1) 분석 범위
- 대상: `/apps/mobile/lib`
- 기준: 실무 배포 기준의 위젯 구조/재사용성/분리도/확장성
- 방식: 실제 코드 라인 기반 정적 분석

## 2) 현재 위젯 구성 현황 (팩트)

### 2.1 전체 규모
- Dart 파일 수: **183개**
- Widget 클래스 수: **152개**
  - Public 위젯: **124개**
  - Private 위젯(`_`): **28개**
- 타입 분포
  - `StatelessWidget`: 98
  - `StatefulWidget`: 24
  - `ConsumerWidget`: 12
  - `ConsumerStatefulWidget`: 18

### 2.2 Feature별 위젯/파일 밀도
| Feature | Dart 파일 수 | Widget 클래스 수 | `presentation/widgets` 파일 수 |
|---|---:|---:|---:|
| auth | 18 | 12 | 12 |
| chat | 29 | 28 | 15 |
| home | 13 | 12 | 7 |
| kana | 23 | 22 | 13 |
| my | 14 | 10 | 7 |
| stats | 11 | 10 | 5 |
| study | 42 | 39 | 28 |
| subscription | 9 | 5 | 2 |
| legal | 2 | 2 | 0 |

### 2.3 Shared 위젯 현황
현재 `shared/widgets`는 6개만 존재합니다.
- `app_card.dart`
- `app_error_retry.dart`
- `app_skeleton.dart`
- `bottom_nav.dart`
- `main_shell.dart`
- `offline_banner.dart`

하지만 실제 재사용 밀도는 낮습니다.
- `AppCard`는 사실상 미사용(Widgetbook에서만 사용):
  - `apps/mobile/lib/shared/widgets/app_card.dart:4`
  - `apps/mobile/lib/widgetbook.dart:48`

### 2.4 Widgetbook 커버리지
- Widgetbook 컴포넌트 수: **7개**
- 전체 Public 위젯(124개) 대비 카탈로그화 비율: **약 5.6%**
- 현재 등록: `AppCard`, `AppErrorRetry`, `AppSkeleton`, `BottomNav`, `HomeHeader`, `TabSwitcher`, `QuizProgressBar`
  - 근거: `apps/mobile/lib/widgetbook.dart`

## 3) 잘 되어 있는 점

1. **Feature-first + Presentation/widgets 분리 방향은 명확함**
- 폴더 구조가 기능 단위로 잘 끊겨 있어, 탐색성이 좋습니다.
- 예: `features/study/presentation/widgets/*`, `features/chat/presentation/widgets/*`

2. **복잡한 UI를 서브 위젯으로 분해하려는 시도는 존재**
- 예: `StudyTab` 내부 `_SummaryItem`, `_ProgressCard`, `_LegendDot` (`apps/mobile/lib/features/stats/presentation/widgets/study_tab.dart`)
- 예: `StreakDailyCard` 내부 `_StreakHeader`, `_StreakWeek`, `_StatBox` (`apps/mobile/lib/features/home/presentation/widgets/streak_daily_card.dart`)

3. **공통 토큰(AppSizes/AppColors) 도입은 되어 있음**
- `apps/mobile/lib/core/constants/sizes.dart`
- `apps/mobile/lib/core/constants/colors.dart`

## 4) 부족한 위젯(현재 실무에서 가장 아쉬운 부분)

아래는 “현재 없는 공통 위젯”이라기보다, **중복이 이미 충분히 발생했기 때문에 지금 당장 shared로 끌어올려야 하는 위젯들**입니다.

### 4.1 `AsyncStateView<T>` (loading/error/empty/data 통합)
중복 근거:
- `apps/mobile/lib/features/study/presentation/widgets/learned_words_content.dart:40`
- `apps/mobile/lib/features/study/presentation/widgets/wrong_answers_content.dart:41`
- `apps/mobile/lib/features/study/presentation/wordbook_page.dart:373`
- `apps/mobile/lib/features/chat/presentation/widgets/scenario_list_view.dart:65`
- `apps/mobile/lib/features/my/presentation/my_page.dart:170`

문제:
- 로딩/에러/빈 상태 UI가 화면마다 제각각이라 UX 일관성이 무너지고, 수정 비용이 N배로 증가합니다.

### 4.2 `PaginationFooter` (이전/다음 + 페이지 숫자)
중복 근거:
- `apps/mobile/lib/features/study/presentation/widgets/learned_words_content.dart:122`
- `apps/mobile/lib/features/study/presentation/widgets/wrong_answers_content.dart:148`
- `apps/mobile/lib/features/study/presentation/wordbook_page.dart:459`
- `apps/mobile/lib/features/my/presentation/payments_page.dart:214`

문제:
- 동일한 페이징 로직/레이아웃이 복제되어 버그 수정 시 누락 위험이 큽니다.

### 4.3 `AppPageHeader` (뒤로가기 + 타이틀 + 우측 액션)
중복 근거:
- `apps/mobile/lib/features/study/presentation/wordbook_page.dart:207`
- `apps/mobile/lib/features/study/presentation/learned_words_page.dart:111`
- `apps/mobile/lib/features/study/presentation/wrong_answers_page.dart:90`
- `apps/mobile/lib/features/chat/presentation/conversation_page.dart:310`
- `apps/mobile/lib/features/chat/presentation/widgets/scenario_list_view.dart:42`

문제:
- 헤더마다 터치 영역/정렬/타이포가 달라지고, 접근성 일관성이 깨집니다.

### 4.4 `AppSearchField` + `FilterChipRow`
중복 근거:
- 검색 필드: `apps/mobile/lib/features/study/presentation/learned_words_page.dart:170`, `apps/mobile/lib/features/study/presentation/wordbook_page.dart:242`
- 필터 칩: `apps/mobile/lib/features/study/presentation/learned_words_page.dart:205`, `apps/mobile/lib/features/study/presentation/wordbook_page.dart:260`, `apps/mobile/lib/features/study/presentation/wrong_answers_page.dart:168`

문제:
- 동일한 인터랙션(검색 디바운스 + 필터)인데 컴포넌트로 통일되지 않아 확장 시 비효율적입니다.

### 4.5 `StatusBadge` / `InfoRow` / `SectionCard`
중복 근거:
- 상태 배지: `apps/mobile/lib/features/my/presentation/payments_page.dart:187`
- 통계 카드류: `apps/mobile/lib/features/stats/presentation/widgets/study_tab.dart`, `apps/mobile/lib/features/stats/presentation/widgets/jlpt_tab.dart`, `apps/mobile/lib/features/chat/presentation/conversation_feedback_page.dart`

문제:
- 카드/배지 표현이 feature마다 따로 놀아 디자인 시스템 확장이 어렵습니다.

## 5) 지금 나눠야 하는 파일 (분리 우선순위)

## A. 즉시 분리 (중복 제거 효과 큼)

### 5.1 `LearnedWordsPage` / `WordbookPage` / `WrongAnswersPage`
- 파일:
  - `apps/mobile/lib/features/study/presentation/learned_words_page.dart` (302줄)
  - `apps/mobile/lib/features/study/presentation/wordbook_page.dart` (483줄)
  - `apps/mobile/lib/features/study/presentation/wrong_answers_page.dart` (251줄)
- 이유:
  - 세 화면이 사실상 “검색 + 필터 + 정렬 + 페이징 + 리스트 + 로딩/에러/빈상태” 패턴을 공유합니다.
- 분리 제안:
  - `shared/widgets/async_state_view.dart`
  - `shared/widgets/pagination_footer.dart`
  - `shared/widgets/app_page_header.dart`
  - `shared/widgets/app_search_field.dart`
  - `shared/widgets/filter_chip_row.dart`

### 5.2 `PaymentsPage`
- 파일: `apps/mobile/lib/features/my/presentation/payments_page.dart` (253줄)
- 이유:
  - `List<Map<String, dynamic>>` 기반 UI 조립으로 타입 안정성이 약함 (`:19`, `:34~37`).
  - 페이징/로딩/빈상태가 Study 계열 화면과 동일 패턴.
- 분리 제안:
  - `PaymentItemCard` 위젯 분리
  - `PaginationFooter` 공통화
  - DTO/모델 강타입 전환

## B. 단기 분리 (복잡도/버그 가능성 낮추기)

### 5.3 `QuizPage`
- 파일: `apps/mobile/lib/features/study/presentation/quiz_page.dart` (465줄)
- 문제:
  - 초기화, 타이머, 정답 처리, 모드 분기(cloze/typing/matching/arrange), 네비게이션까지 한 State 클래스에 집중.
- 분리 제안:
  - `QuizSessionController` (상태/타이머/진행 로직)
  - `QuizModeRenderer` (모드별 UI 분기)
  - `QuizFlowScaffold` (공통 레이아웃)

### 5.4 `KanaStagePage`
- 파일: `apps/mobile/lib/features/kana/presentation/kana_stage_page.dart` (430줄)
- 문제:
  - phase state machine + 네트워크 호출 + 단계 이동 + 리뷰 로직이 한 파일에 응집.
- 분리 제안:
  - `KanaStageController` (phase 전이/퀴즈 제출)
  - `KanaStagePhaseView` (intro/practice/quiz/review/complete 렌더)

### 5.5 `ConversationPage`
- 파일: `apps/mobile/lib/features/chat/presentation/conversation_page.dart` (392줄)
- 문제:
  - 메시지 리스트 어댑팅, 시나리오 헤더 렌더, 에러 배너, 입력/종료 제어가 한 클래스에 결합.
- 분리 제안:
  - `ConversationTimeline` (scenario card + messages + typing + error)
  - `ConversationHeader` (제목/난이도/번역 toggle)
  - `ConversationActions` (종료/입력)

## C. 중기 분리 (디자인 시스템 성숙도)

### 5.6 `StudyTab` / `JlptTab` / `ConversationFeedbackPage`의 카드 공통화
- 파일:
  - `apps/mobile/lib/features/stats/presentation/widgets/study_tab.dart` (412줄)
  - `apps/mobile/lib/features/stats/presentation/widgets/jlpt_tab.dart` (373줄)
  - `apps/mobile/lib/features/chat/presentation/conversation_feedback_page.dart` (394줄)
- 문제:
  - “아이콘 + 타이틀 + 지표 + 프로그레스” 카드 패턴이 반복되지만 공통 컴포넌트가 없습니다.
- 분리 제안:
  - `MetricCard`, `SectionListCard`, `ProgressBreakdownCard`

## 6) 구조적 리스크 (실무 관점)

1. **공통 위젯층이 얇고, feature별 복제 구현이 많음**
- UI가 빨리 만들어지는 대신, 수정/QA 비용이 누적됩니다.

2. **화면 State 클래스가 ViewModel 역할까지 흡수**
- `QuizPage`, `KanaStagePage`, `ConversationPage`는 특히 회귀 리스크가 큽니다.

3. **Widgetbook 도입은 했지만 카탈로그 coverage가 낮음**
- 디자인/리뷰 협업에서 “보이는 계약(visual contract)”이 아직 약합니다.

4. **디자인 토큰은 있으나 컴포넌트 토큰화는 미완성**
- `AppSizes`, `AppColors`는 있으나 실제 조합 컴포넌트가 적어서 팀 생산성이 제한됩니다.

## 7) 권장 리팩토링 순서 (현실 적용형)

### 7.1 즉시 (1~2일)
1. `AsyncStateView`, `PaginationFooter`, `AppPageHeader` 생성
2. `LearnedWordsContent`, `WrongAnswersContent`, `WordbookContent`, `PaymentsPage` 적용
3. `AppCard`를 실제 화면에 도입하거나 제거 결정

### 7.2 단기 (3~5일)
1. `QuizPage`, `KanaStagePage`, `ConversationPage`에서 상태 로직을 Controller로 분리
2. 공통 검색/필터 컴포넌트(`AppSearchField`, `FilterChipRow`) 도입
3. `PaymentsPage` 강타입 모델 전환 (`dynamic` 제거)

### 7.3 중기 (1~2주)
1. Stats/Feedback 카드 컴포넌트 계층 정리 (`MetricCard` 군)
2. Widgetbook coverage를 최소 30%까지 확대
   - 우선순위: 반복 사용 위젯 + 상태가 많은 위젯 + 장애 영향 큰 위젯
3. 핵심 공통 위젯에 golden/widget test 추가

## 8) Widgetbook 우선 등록 추천 위젯

현재 7개에서 아래를 우선 추가 권장합니다.

- `AppPageHeader` (신규)
- `AsyncStateView` (신규)
- `PaginationFooter` (신규)
- `AppSearchField` (신규)
- `FilterChipRow` (신규)
- `RecommendationCard` (`apps/mobile/lib/features/study/presentation/widgets/recommendation_card.dart`)
- `WordCard` (`apps/mobile/lib/features/study/presentation/widgets/word_card.dart`)
- `WrongAnswersSummaryCard` (`apps/mobile/lib/features/study/presentation/widgets/wrong_answers_summary_card.dart`)
- `ScenarioCard` (`apps/mobile/lib/features/chat/presentation/widgets/scenario_card.dart`)
- `ProfileHero` (`apps/mobile/lib/features/my/presentation/widgets/profile_hero.dart`)

## 9) 총평

현재 프로젝트는 **feature 기반 분리는 잘 되어 있으나, 공통 위젯화 레이어가 얇아 중복이 빠르게 누적되는 단계**입니다.

즉, “개발 속도는 빠른데 유지보수 비용이 가파르게 증가하기 시작한 시점”이며,
지금 공통 위젯 5~7개만 전략적으로 도입해도 코드량/리뷰 난이도/버그 회귀율을 크게 줄일 수 있습니다.
