# 하루코토 모바일 컬러 시스템

> 관리 파일: `apps/mobile/lib/core/constants/colors.dart`
> 테마 적용: `apps/mobile/lib/core/theme/app_theme.dart`

## 사용 원칙

1. **모든 컬러는 `AppColors`를 통해 참조** — 위젯에 직접 `Color(0xFF...)` 하드코딩 금지
2. **라이트/다크 모드**는 `Brightness` 파라미터를 받는 함수형 컬러 사용
3. **외부 브랜드 로고**(Google, Kakao 로고 painter)만 예외적으로 하드코딩 허용

---

## Brand

| 상수명 | HEX | 미리보기 | 용도 |
|--------|-----|---------|------|
| `primary` | `#F6A5B3` | 🟪 | 메인 브랜드 (소프트 핑크) |
| `brandPink` | `#FFB7C5` | 🟪 | 브랜드 보조 핑크 |

---

## Light Theme

| 상수명 | HEX | 용도 |
|--------|-----|------|
| `lightBackground` | `#FCF6F5` | 배경 (오프화이트) |
| `lightCard` | `#FFFFFF` | 카드 배경 |
| `lightSecondary` | `#FFF0F3` | 보조 배경 (연핑크) |
| `lightBorder` | `#FCE7EC` | 테두리 |
| `lightText` | `#1A1A2E` | 기본 텍스트 (다크 네이비) |
| `lightSubtext` | `#666680` | 보조 텍스트 |

## Dark Theme

| 상수명 | HEX | 용도 |
|--------|-----|------|
| `darkBackground` | `#1A1A2E` | 배경 (다크 네이비) |
| `darkCard` | `#242442` | 카드 배경 |
| `darkSecondary` | `#2A2A4A` | 보조 배경 |
| `darkBorder` | `#1AFFFFFF` | 테두리 (white 10%) |
| `darkText` | `#FFFFFF` | 기본 텍스트 |
| `darkSubtext` | `#B0B0C0` | 보조 텍스트 |

---

## HK 시맨틱 컬러 (밝기별 자동 전환)

| 함수명 | Light | Dark | 용도 |
|--------|-------|------|------|
| `hkBlue()` | `#87CEEB` | `#5BA3C9` | 커스텀 블루 (학습중 상태 등) |
| `hkYellow()` | `#FFD93D` | `#E5C235` | 커스텀 옐로 (XP, 보상 등) |
| `hkRed()` | `#FF6B6B` | `#E05252` | 커스텀 레드 (스트릭 불꽃 등) |

---

## 기능적 시맨틱 컬러 (밝기별 자동 전환)

| 함수명 | Light | Dark | 용도 |
|--------|-------|------|------|
| `success()` | `#2DB08A` | `#26997A` | 성공 (소프트 틸 그린) |
| `error()` | `#E8577D` | `#D14468` | 에러 (워밍 로즈) |
| `warning()` | `#F59E0B` | `#D97706` | 경고 (앰버) |
| `info()` | `#3B82F6` | `#2563EB` | 정보 (블루) |

---

## Auth 그라디언트

| 상수명 | HEX | 용도 |
|--------|-----|------|
| `authGradientTop` | `#FCF6F5` | 그라디언트 상단 |
| `authGradientMid` | `#FFF0F3` | 그라디언트 중간 |
| `authGradientBottom` | `#FFE4EC` | 그라디언트 하단 |
| `authGradient` | — | `LinearGradient` 프리셋 (위 3색) |

**사용법:**
```dart
Container(
  decoration: const BoxDecoration(gradient: AppColors.authGradient),
)
```

---

## Kakao 브랜드

| 상수명 | HEX | 용도 |
|--------|-----|------|
| `kakaoBg` | `#FEE500` | 카카오 버튼 배경 |
| `kakaoText` | `#191919` | 카카오 버튼 텍스트 |

---

## Voice Call (다크 서피스)

| 상수명 | HEX | 용도 |
|--------|-----|------|
| `callBackground` | `#0F172A` | 통화 화면 배경 |
| `callSurface` | `#1E293B` | 통화 화면 서피스 (아바타 배경 등) |
| `callAccent` | `#10B981` | 통화 강조색 (에메랄드) |
| `callAccentLight` | `#34D399` | 통화 밝은 강조색 (웨이브폼 등) |

---

## 난이도 (Difficulty)

| 상수명 | HEX | 용도 |
|--------|-----|------|
| `difficultyBeginner` | `#22C55E` | 초급 (그린) |
| `difficultyIntermediate` | `#EAB308` | 중급 (옐로) |
| `difficultyAdvanced` | `#EF4444` | 고급 (레드) |

---

## 시나리오

| 상수명 | HEX | 용도 |
|--------|-----|------|
| `scenarioPurple` | `#8B5CF6` | 시나리오 전화 버튼 (퍼플) |

---

## 퀴즈 피드백

| 상수명 | HEX | 용도 |
|--------|-----|------|
| `quizCorrect` | `#4CAF50` | 정답 표시 (그린) |

---

## 알림 아이콘 배경

| 상수명 | HEX | 용도 |
|--------|-----|------|
| `notifLevelUp` | `#FFF3E0` | 레벨업 알림 배경 |
| `notifStreak` | `#FBE9E7` | 스트릭 알림 배경 |
| `notifAchievement` | `#FFF8E1` | 업적 알림 배경 |

---

## 점수 (Score)

| 상수명 | HEX | 용도 |
|--------|-----|------|
| `scoreMid` | `#FBBF24` | 중간 점수 별 색상 |

---

## 히트맵 인텐시티

밝기별로 5단계 그라데이션을 제공합니다.

### Light Mode (`heatmapLight`)

| 단계 | HEX | 의미 |
|------|-----|------|
| 0 | `#F0F0F0` | 학습 없음 |
| 1 | `#FCE7EC` | 소량 |
| 2 | `#F6A5B3` | 보통 |
| 3 | `#F494A4` | 많음 |
| 4 | `#E5607A` | 최다 |

### Dark Mode (`heatmapDark`)

| 단계 | HEX | 의미 |
|------|-----|------|
| 0 | `#2A2A4A` | 학습 없음 |
| 1 | `#3D1F2A` | 소량 |
| 2 | `#6B3040` | 보통 |
| 3 | `#994158` | 많음 |
| 4 | `#CC5570` | 최다 |

**사용법:**
```dart
final colors = AppColors.heatmapColors(Theme.of(context).brightness);
```

---

## On Gradient / Overlay

| 상수명 | 값 | 용도 |
|--------|-----|------|
| `onGradient` | `Colors.white` | 그라디언트 위 텍스트/아이콘 |
| `onGradientMuted` | `#B3FFFFFF` (white 70%) | 그라디언트 위 뮤트 텍스트 |
| `overlay(alpha)` | `Colors.black + alpha` | 오버레이 (투명도 지정) |

---

## 새 컬러 추가 가이드

1. `colors.dart`의 `AppColors` 클래스에 상수 추가
2. 라이트/다크 모드가 필요하면 `Brightness` 파라미터를 받는 static 함수로 정의
3. 이 문서에 해당 섹션 업데이트
4. 위젯에서는 반드시 `AppColors.xxx`로 참조

### 금지 사항

- 위젯 파일에 `Color(0xFF...)` 직접 사용 금지
- 예외: Google/Kakao 등 외부 브랜드 로고 painter 내부만 허용
