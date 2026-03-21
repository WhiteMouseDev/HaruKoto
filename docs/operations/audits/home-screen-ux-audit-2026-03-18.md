# 홈 화면 UI/UX 심층 분석 리포트

> **작성일**: 2026-03-18
> **대상**: `apps/mobile/lib/features/home/`
> **관점**: 시니어 UI/UX 디자이너 (대기업 20년차 기준)
> **종합 점수**: **62/100**

---

## 목차

1. [총평](#총평)
2. [섹션별 분석](#섹션별-분석)
   - [HomeHeader](#1-homeheader)
   - [KanaCtaCard](#2-kanactacard)
   - [StreakDailyCard](#3-streakdailycard)
   - [DailyMissionsCard](#4-dailymissionscard)
   - [QuickStartCard](#5-quickstartcard)
   - [WeeklyChart](#6-weeklychart)
   - [ShortcutGrid](#7-shortcutgrid)
   - [전체 HomePage 구조](#8-전체-homepage-구조)
3. [크로스커팅 이슈](#크로스커팅-이슈)
4. [점수 요약](#점수-요약)
5. [우선 개선 사항](#우선-개선-사항)
6. [결론](#결론)

---

## 총평

전체적으로 학습 앱의 기본기는 갖춘 상태이지만, "좋은 앱"과 "훌륭한 앱"의 차이를 만드는 디테일에서 상당히 많은 개선점이 보인다.
Duolingo를 벤치마크한 흔적이 있으나, 마감 수준에서 격차가 느껴진다.

---

## 섹션별 분석

### 1. HomeHeader

**파일**: `widgets/home_header.dart`
**역할**: 인사말 + 알림 벨
**점수**: **58/100**

| 항목 | 평가 | 점수 |
|------|------|------|
| 레이아웃 | 좌측 텍스트 + 우측 알림벨 구조는 표준적이고 적절 | 7/10 |
| 타이포그래피 | 일본어 인사 + 한국어 이름의 2줄 구조는 좋으나, 시간대별 인사 분기가 없음 (`おはよう!`가 하드코딩) | 5/10 |
| 아이콘 | Lucide bell 아이콘은 깔끔하나, 알림 아이콘 배경이 `AppColors.lightSecondary`로 다크모드에서도 라이트 컬러 하드코딩 | 4/10 |
| 터치 영역 | 알림 버튼이 `GestureDetector`에 40x40 — iOS HIG 최소 44pt 미달. InkWell도 아닌 GestureDetector라 리플 이펙트 없음 | 3/10 |
| 햅틱 | 알림 탭 시 햅틱 피드백 없음 | 2/10 |
| 배지 | unread badge 구현 적절 (9+ 처리 포함). 다만 badge에 애니메이션이 없어 눈에 잘 안 띔 | 6/10 |

**치명적 문제점:**

- 다크모드 미지원 (`AppColors.lightSecondary` 하드코딩)
- 터치 영역 44pt 미달 + 터치 피드백 제로
- 시간대별 인사 분기 없음 (아침/낮/저녁 관계없이 `おはよう`)

---

### 2. KanaCtaCard

**파일**: `widgets/kana_cta_card.dart`
**역할**: 가나 학습 진행률
**점수**: **75/100**

| 항목 | 평가 | 점수 |
|------|------|------|
| 레이아웃 | 아이콘 + 텍스트 + 프로그레스바 + chevron 구조. 정보 밀도가 적절 | 8/10 |
| 터치 피드백 | `Material` + `InkWell` 사용 — 홈 화면에서 유일하게 제대로 된 리플 이펙트 | 9/10 |
| 색감 | `theme.colorScheme` 활용으로 다크모드 대응 양호 | 8/10 |
| 프로그레스바 | `LinearProgressIndicator` 기본 위젯 사용. 커스텀 디자인 없이 기본형 — 밋밋함 | 5/10 |
| 햅틱 | 탭 시 햅틱 피드백 없음 | 2/10 |
| 조건부 표시 | 완료 시 숨김 처리 — 좋은 UX 판단 | 8/10 |

> 이 카드가 다른 카드들의 롤모델이 되어야 함. `Material` + `InkWell` 패턴을 다른 카드에도 적용 필요.

---

### 3. StreakDailyCard

**파일**: `widgets/streak_daily_card.dart`
**역할**: 연속 학습 + 7일 현황
**점수**: **65/100**

| 항목 | 평가 | 점수 |
|------|------|------|
| 마이크로 애니메이션 | 불꽃 아이콘 ScaleTransition (1.0→1.2, 1.2초) — 유일한 생동감 있는 요소 | 8/10 |
| 레이아웃 | 상단 스트릭 + 하단 7일 서클. 깔끔하나 정보량이 적음 (학습 수치가 없음) | 6/10 |
| 색감 | `AppColors.lightBorder` 하드코딩 — 다크모드 깨짐 | 4/10 |
| 터치 피드백 | `GestureDetector` 사용 — 리플/시각적 피드백 없음. 탭하면 캘린더 시트가 뜨는데 사용자가 탭 가능함을 인지 못할 수 있음 | 3/10 |
| 7일 서클 | 28x28 원형. 완료=primary, 미학습=대시(-)로 시각적 구분 양호 | 7/10 |
| 접근성 | `Semantics` 라벨 적용 — 홈 화면에서 유일하게 접근성 고려 | 9/10 |
| 그림자 | `BoxShadow(alpha: 0.04, blur: 8)` — 매우 미세. 카드 분리감 약함 | 5/10 |
| 햅틱 | 없음 | 2/10 |

**문제점:**

- `chevronRight` 아이콘이 alpha 0.3으로 거의 안 보임 — 탭 가능함을 인지 못함
- 캘린더 바텀시트 전환 시 트랜지션 효과 없음

---

### 4. DailyMissionsCard

**파일**: `widgets/daily_missions_card.dart`
**역할**: 일일 미션
**점수**: **60/100**

| 항목 | 평가 | 점수 |
|------|------|------|
| 레이아웃 | 미션 리스트형 구조는 게임화에 적절 | 7/10 |
| 아이콘 혼합 | Lucide와 Material Icons 혼용 (`Icons.check_circle`, `Icons.bolt`, `Icons.menu_book` 등). 아이콘 일관성 파괴 | 3/10 |
| 색감 | `Colors.white` 하드코딩 — 다크모드 완전 깨짐 | 2/10 |
| 터치 피드백 | 미션 아이템에 탭 자체가 없음. 완료/미완료 상태만 보여줄 뿐 인터랙션 불가 | 4/10 |
| 완료 배너 | 모든 미션 완료 시 배너 표시는 좋으나, 축하 애니메이션 부재 (confetti 등) | 5/10 |
| 진행률 시각화 | `currentCount/targetCount` 텍스트만 — 프로그레스바가 없어 진행감이 약함 | 4/10 |
| 취소선 | 완료 미션에 `lineThrough` — 할 일 목록 느낌으로 적절 | 7/10 |
| XP 표시 | bolt 아이콘 + XP 수치. Duolingo 스타일이나 bolt 아이콘 크기(14)가 작음 | 6/10 |

**치명적 문제점:**

- `Colors.white` 하드코딩으로 다크모드에서 눈부신 흰 카드 출현
- 아이콘 라이브러리 불일치 (Material vs Lucide)
- 미션 아이템에 탭 인터랙션이 없어서 "게임화"의 핵심인 즉각적 보상감 부재

---

### 5. QuickStartCard

**파일**: `widgets/quick_start_card.dart`
**역할**: 학습 시작 + 카테고리 탭 레일
**점수**: **70/100**

| 항목 | 평가 | 점수 |
|------|------|------|
| 레이아웃 | 메인 카드 + 우측 탭 레일 구조 — 독창적이고 공간 활용 우수 | 8/10 |
| 탭 전환 | `AnimatedSwitcher(250ms)` — 부드러운 전환 | 7/10 |
| 원형 프로그레스 | `CustomPaint`로 직접 구현. `strokeCap: StrokeCap.round`로 마감 깔끔 | 8/10 |
| CTA 버튼 | `Material` + `InkWell` 조합으로 리플 이펙트 있음. `primaryStrong` 색상으로 시선 집중 | 8/10 |
| 정보 칩 | 복습/새 단어 카운트 칩 디자인 깔끔 | 7/10 |
| 색감 | `Colors.white` 하드코딩 (`const cardBg = Colors.white`) — 다크모드 깨짐 | 2/10 |
| 탭 레일 | 선택/비선택 탭의 elevation 차이로 깊이감 연출 시도. 다만 폰트 10px는 너무 작음 | 6/10 |
| 아이콘 | 카테고리별 아이콘 분류 적절 (bookOpen, languages, arrowUpDown) | 7/10 |
| 햅틱 | 탭 전환 시 햅틱 없음. 카테고리 변경 같은 중요 인터랙션에 selection 햅틱 필요 | 3/10 |

**문제점:**

- 일일 목표 편집 아이콘(pencil, 14px, alpha 0.4)이 거의 보이지 않음
- 탭 레일 52px 너비가 iOS에서 터치하기 빡빡함
- `문장` 카테고리의 `arrowUpDown` 아이콘이 직관적이지 않음 (문장 배열 = 정렬이라는 메타포가 약함)

---

### 6. WeeklyChart

**파일**: `widgets/weekly_chart.dart`
**역할**: 주간 학습 바 차트
**점수**: **55/100**

| 항목 | 평가 | 점수 |
|------|------|------|
| 시각화 | 바 차트 직접 구현. `sqrt` 스케일링으로 극단값 완화 시도 — 수학적으로 합리적 | 7/10 |
| 목표선 | 대시드 라인(CustomPaint)으로 목표 표시. 깔끔 | 7/10 |
| 색감 | `Colors.white` 하드코딩 — 다크모드 깨짐 | 2/10 |
| 인터랙션 | 바를 탭하면 상세 보이는 기능 없음. 정적 차트에 불과 | 3/10 |
| 애니메이션 | 차트 등장/변화 애니메이션 전무. 바가 아래서 올라오는 등의 진입 애니메이션 필요 | 2/10 |
| 바 모서리 | 상단만 둥근 처리 (`topLeft: 6, topRight: 6`). 적절 | 7/10 |
| 통계 링크 | `학습 통계 자세히 보기 →` — GestureDetector로 리플 없음, 터치 영역 텍스트 크기뿐 | 3/10 |
| 레이블 | 10px 폰트는 가독성 우려. 최소 11-12px 권장 | 4/10 |

**문제점:**

- 데이터가 없을 때 `데이터 없음` 텍스트만 — empty state 디자인 부재
- 바 차트의 하단 모서리가 각진 채로 끝남 (카드 바닥과 이어져 어색)
- 체크마크(12px)가 바 위에 떠있어 시각적으로 불안정

---

### 7. ShortcutGrid

**파일**: `widgets/shortcut_grid.dart`
**역할**: 바로가기 그리드 (단어장, 오답노트, 도전과제, 가나 차트)
**점수**: **50/100**

| 항목 | 평가 | 점수 |
|------|------|------|
| 레이아웃 | 4열 1행 그리드. 간결하나 섹션 헤더가 없어 맥락 부족 | 5/10 |
| 아이콘 | Lucide 아이콘 통일 — 일관성 좋음 | 8/10 |
| 터치 피드백 | `GestureDetector` — 리플 이펙트 없음. 바로가기는 빈번히 사용하는 영역인데 피드백 부재는 치명적 | 2/10 |
| 아이콘 배경 | `primary.withAlpha(0.1)` + `borderRadius: 16`. 둥근 사각형은 현대적이나 변별력 부족 | 5/10 |
| 라벨 | `bodySmall` + `w600` — 크기가 작을 수 있으나 bold로 보완 | 6/10 |
| 그림자/테두리 | 아이콘 박스에 그림자/테두리 없음. 플로팅 느낌 없이 밋밋 | 4/10 |
| 햅틱 | 없음 | 2/10 |
| 스케일 애니메이션 | 누를 때 축소/확대 없음. 버튼인지 장식인지 구분 불가 | 2/10 |

**치명적 문제점:**

- 4개 아이콘이 모두 같은 핑크 톤 → 시각적 구별이 안 됨. 각 기능별 시맨틱 컬러 활용 필요
- `fileX` 아이콘이 "오답노트"를 직관적으로 표현하지 못함

---

### 8. 전체 HomePage 구조

**파일**: `presentation/home_page.dart`
**점수**: **60/100**

| 항목 | 평가 | 점수 |
|------|------|------|
| 스크롤 | `ListView` 기반 수직 스크롤. 표준적 | 6/10 |
| Pull-to-Refresh | `RefreshIndicator` 적용 | 7/10 |
| 섹션 간격 | 모두 `SizedBox(height: AppSizes.md)` (16px) — 단조로움. 섹션 중요도에 따른 간격 차등이 없음 | 4/10 |
| 로딩 상태 | `AppSkeleton` 스켈레톤 UI | 7/10 |
| 에러 상태 | `AppErrorRetry` — 기본적 에러 처리 있음 | 6/10 |
| 스크롤 물리 | 기본 Flutter 물리. iOS bouncing은 자동 적용되나 커스텀 스크롤 효과 없음 | 5/10 |
| 페이지 패딩 | `top: 12, bottom: 32` — 상단 여백이 좁고 하단은 적절 | 5/10 |

---

## 크로스커팅 이슈

### 다크모드 지원 — 20/100 (치명적)

- `Colors.white` 하드코딩이 최소 3개 카드에 존재 (DailyMissions, QuickStart, WeeklyChart)
- `AppColors.lightBorder`, `AppColors.lightSecondary` 직접 참조 다수
- 다크모드를 켜면 흰색 카드가 눈부시게 떠있는 상태가 됨

**해결 방향**: 모든 `Colors.white` → `theme.colorScheme.surfaceContainerLowest`, 모든 `AppColors.light*` → `theme.colorScheme` 매핑

### 햅틱 피드백 — 15/100 (극심한 부족)

- `HapticService`가 구현되어 있으나 홈 화면에서 단 한 번도 호출되지 않음
- 카테고리 전환, 바로가기 탭, 캘린더 열기 등 모든 인터랙션에 햅틱 부재
- 학습 앱에서 햅틱은 "성취감"을 강화하는 핵심 요소인데 완전 미활용

**적용 가이드:**

| 인터랙션 | 햅틱 레벨 |
|----------|-----------|
| 카테고리 탭 전환 | `selection()` |
| CTA 버튼 탭 | `light()` |
| 바로가기 탭 | `selection()` |
| 알림 벨 탭 | `light()` |
| 미션 완료 | `medium()` |
| 모든 미션 완료 | `heavy()` |
| 캘린더 시트 열기 | `light()` |

### 터치 피드백 (리플/스케일) — 25/100

- `GestureDetector` 남용: HomeHeader bell, StreakDailyCard, ShortcutGrid, WeeklyChart link 전부
- `Material` + `InkWell` 사용: KanaCtaCard, QuickStart CTA 버튼뿐
- 탭해도 시각적 반응이 없어 "먹통인가?" 느낌을 줄 수 있음

**해결 방향**: 모든 `GestureDetector` → `Material(color: transparent) + InkWell` 또는 `AnimatedScale` 래핑

### 아이콘 일관성 — 50/100

- 기본 Lucide 아이콘 통일 방침이 있으나, DailyMissionsCard에서 Material Icons 혼용
- `Icons.check_circle`, `Icons.bolt`, `Icons.menu_book` 등 Material
- `LucideIcons.check`, `LucideIcons.bookOpen` 등 Lucide
- 같은 의미의 아이콘이 다른 라이브러리에서 오는 것은 시각적 통일성을 깨뜨림

**해결 방향**: 앱 전체에서 Lucide 아이콘 통일. Material Icons 사용처 전수 조사 및 교체.

### 애니메이션 — 35/100

- 스트릭 불꽃 ScaleTransition — 유일한 상시 애니메이션
- AnimatedSwitcher — 탭 전환 시만 동작
- 진입 애니메이션 전무: 카드가 스크롤에 따라 나타나는 staggered 애니메이션 없음
- 상태 변화 애니메이션 부재: 프로그레스, 숫자 변화 등이 즉시 표시

**해결 방향**: `AnimatedSlide` / `FadeTransition` 기반 staggered 진입 효과, `TweenAnimationBuilder`로 숫자/프로그레스 애니메이션

### 테두리/그림자 일관성 — 55/100

- 카드 그림자: `alpha: 0.04, blur: 8` — 너무 미세해서 depth 표현 약함
- border: `AppColors.lightBorder` — 다크모드 미대응
- 카드 radius: `24px`로 통일 — 이것은 좋음
- QuickStart 카드만 좌측만 둥금 (탭 레일 때문) — 패턴 예외

---

## 점수 요약

### 섹션별

| 섹션 | 점수 | 등급 |
|------|------|------|
| HomeHeader | 58 | D+ |
| KanaCtaCard | 75 | B |
| StreakDailyCard | 65 | C+ |
| DailyMissionsCard | 60 | C |
| QuickStartCard | 70 | B- |
| WeeklyChart | 55 | D+ |
| ShortcutGrid | 50 | D |
| 전체 구조 | 60 | C |

### 크로스커팅

| 항목 | 점수 | 등급 |
|------|------|------|
| 다크모드 | 20 | F |
| 햅틱 | 15 | F |
| 터치 피드백 | 25 | F |
| 아이콘 일관성 | 50 | D |
| 애니메이션 | 35 | D- |
| 테두리/그림자 | 55 | D+ |

---

## 우선 개선 사항

### P0 — 즉시 수정 (사용자 경험 파괴 수준)

| # | 항목 | 대상 파일 |
|---|------|-----------|
| 1 | 다크모드 하드코딩 제거: `Colors.white` → `theme.colorScheme.surfaceContainerLowest` | `daily_missions_card.dart`, `quick_start_card.dart`, `weekly_chart.dart` |
| 2 | `GestureDetector` → `Material` + `InkWell` 전환: 모든 탭 가능 요소에 리플 추가 | `home_header.dart`, `streak_daily_card.dart`, `shortcut_grid.dart`, `weekly_chart.dart` |
| 3 | 터치 영역 44pt 확보 | `home_header.dart` (알림 벨), `shortcut_grid.dart` |

### P1 — 1주 내 (체감 품질 대폭 향상)

| # | 항목 | 대상 파일 |
|---|------|-----------|
| 4 | HapticService 연결: 카테고리 전환 → `selection()`, CTA → `light()`, 미션 완료 → `medium()` | 전체 위젯 |
| 5 | 아이콘 라이브러리 통일: Material Icons → Lucide로 교체 | `daily_missions_card.dart`, `quick_start_card.dart`, `weekly_chart.dart` |
| 6 | 진입 애니메이션 추가: 스크롤 진입 시 카드 fade-in + slide-up (staggered) | `home_page.dart` |

### P2 — 2주 내 (앱 완성도)

| # | 항목 | 대상 파일 |
|---|------|-----------|
| 7 | 차트 애니메이션: 바 차트 진입 시 아래서 올라오는 애니메이션 | `weekly_chart.dart` |
| 8 | ShortcutGrid 아이콘 색상 차등화: 기능별 시맨틱 컬러 적용 | `shortcut_grid.dart` |
| 9 | 미션 아이템 프로그레스바 추가: 텍스트 → 미니 프로그레스바 | `daily_missions_card.dart` |
| 10 | 시간대별 인사 분기: 아침/낮/저녁/밤 인사 변경 | `home_header.dart` |

---

## 결론

기능적으로는 학습 앱의 핵심 요소를 잘 갖추고 있으나, **"만져서 기분 좋은 앱"**이 되려면 터치 피드백, 햅틱, 애니메이션 3가지 축에서 대대적인 보강이 필요하다.

다크모드 하드코딩은 출시 전 반드시 수정해야 할 블로커이며, `KanaCtaCard`의 `Material` + `InkWell` 패턴을 다른 카드에도 일괄 적용하는 것이 가장 빠른 품질 개선 경로이다.
