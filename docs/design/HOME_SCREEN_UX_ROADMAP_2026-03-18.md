# 홈 화면 UX 개선 로드맵

> **작성일**: 2026-03-18
> **근거**: `HOME_SCREEN_UX_AUDIT_2026-03-18.md`
> **대상**: `apps/mobile/lib/features/home/presentation/`

---

## Phase 1 — P0 블로커 수정 (다크모드 + 터치 피드백)

사용자 경험을 파괴하는 수준의 문제를 즉시 수정한다.

### 1-1. 다크모드 하드코딩 제거

| 파일 | 변경 |
|------|------|
| `daily_missions_card.dart:40` | `Colors.white` → `theme.colorScheme.surfaceContainerLowest` |
| `daily_missions_card.dart:150` | `AppColors.lightSecondary` → `theme.colorScheme.secondary` |
| `weekly_chart.dart:36` | `Colors.white` → `theme.colorScheme.surfaceContainerLowest` |
| `weekly_chart.dart:38` | `AppColors.lightBorder` → `theme.colorScheme.outline.withValues(alpha: 0.2)` |
| `quick_start_card.dart:60` | `const cardBg = Colors.white` → `theme.colorScheme.surfaceContainerLowest` |
| `streak_daily_card.dart:38` | `AppColors.lightBorder` → `theme.colorScheme.outline.withValues(alpha: 0.2)` |
| `home_header.dart:55` | `AppColors.lightSecondary` → `theme.colorScheme.secondary` |
| `daily_missions_card.dart:42` | `AppColors.lightBorder` → `theme.colorScheme.outline.withValues(alpha: 0.2)` |

### 1-2. GestureDetector → Material + InkWell 전환

| 파일 | 위치 | 설명 |
|------|------|------|
| `home_header.dart:46` | 알림 벨 | 터치 영역 44pt 확보 + 리플 |
| `streak_daily_card.dart:32` | 카드 전체 | 카드 탭 리플 |
| `shortcut_grid.dart:47` | 바로가기 아이콘 | 리플 + 스케일 |
| `weekly_chart.dart:220` | 통계 링크 | 텍스트 버튼 리플 |
| `quick_start_card.dart:137` | 복습 정답률 | 링크 리플 |
| `quick_start_card.dart:198` | 목표 편집 pencil | 터치 영역 확대 |

### 1-3. 터치 영역 44pt 확보

| 파일 | 현재 | 목표 |
|------|------|------|
| `home_header.dart` 알림 벨 | 40x40 | 44x44 |
| `shortcut_grid.dart` 아이콘 | 52x52 (OK) | 유지 |

---

## Phase 2 — P1 품질 향상 (햅틱 + 아이콘 + 인사)

### 2-1. HapticService 연결

| 인터랙션 | 햅틱 레벨 | 파일 |
|----------|-----------|------|
| 카테고리 탭 전환 | `selection()` | `quick_start_card.dart` |
| CTA 버튼 탭 | `light()` | `quick_start_card.dart` |
| 바로가기 탭 | `selection()` | `shortcut_grid.dart` |
| 알림 벨 탭 | `light()` | `home_header.dart` |
| 캘린더 시트 열기 | `light()` | `streak_daily_card.dart` |

### 2-2. Material Icons → Lucide 통일 (DailyMissionsCard)

| 현재 (Material) | 변경 (Lucide) |
|-----------------|---------------|
| `Icons.menu_book` | `LucideIcons.bookOpen` |
| `Icons.gps_fixed` | `LucideIcons.target` |
| `Icons.auto_awesome` | `LucideIcons.sparkles` |
| `Icons.chat_bubble_outline` | `LucideIcons.messageCircle` |
| `Icons.check_circle` | `LucideIcons.checkCircle` |
| `Icons.check` | `LucideIcons.check` |
| `Icons.bolt` | `LucideIcons.zap` |

### 2-3. 시간대별 인사 분기 (HomeHeader)

| 시간 | 일본어 | 한국어 (B안 위트) |
|------|--------|------------------|
| 05:00-11:59 | おはよう! | 오늘도 화이팅, {name}! |
| 12:00-17:59 | こんにちは! | 점심은 먹었어, {name}? |
| 18:00-23:59 | こんばんは! | 오늘 하루 수고했어, {name}! |
| 00:00-04:59 | まだ起きてるの? | 야행성이구나, {name}! |

---

## Phase 3 — 진입 애니메이션 + 로딩 UX

### 3-1. Staggered 진입 애니메이션 (첫 진입 1회만)

- `HomePage` → `ConsumerStatefulWidget` 변환
- `AnimationController` (600ms) + `_hasAnimated` 플래그
- 각 카드 순차적 slide-up(20px) + fade-in
- Interval 간격: 카드당 12%, easeOutCubic
- 재방문/pull-to-refresh 시 즉시 표시

### 3-2. 홈 전용 스켈레톤 (HomeSkeleton)

- `home_skeleton.dart` 신규 생성
- 실제 홈 레이아웃을 반영한 shimmer 플레이스홀더
  - Header (텍스트 2줄 + 알림 원형)
  - Streak 카드 (100px)
  - QuickStart 카드 + 탭 레일 (260px + 52px)
  - Weekly 차트 (200px)
  - Shortcut 그리드 (52px 사각형 x 4)
- 기존 `AppSkeleton` 대체

---

## Phase 4 — 후속 작업 (승인 대기)

- [ ] C-2: ShortcutGrid 아이콘 색상 차등화 (롤백 쉽게 마지막 작업)
- [ ] C-3: 미션 아이템 미니 프로그레스바 (API 확인 후 작업)
- [ ] C-4: 바 차트 진입 애니메이션

---

## 진행 상태

- [x] Phase 1-1: 다크모드 하드코딩 제거
- [x] Phase 1-2: GestureDetector → InkWell 전환
- [x] Phase 1-3: 터치 영역 44pt 확보
- [x] Phase 2-1: HapticService 연결
- [x] Phase 2-2: 아이콘 라이브러리 통일
- [x] Phase 2-3: 시간대별 인사 분기 (B안 위트)
- [x] Phase 3-1: Staggered 진입 애니메이션
- [x] Phase 3-2: 홈 전용 스켈레톤
- [ ] Phase 4: 후속 작업 (C-2, C-3, C-4)
