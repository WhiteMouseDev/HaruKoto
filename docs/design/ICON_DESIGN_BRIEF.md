# 하루코토 아이콘 디자인 브리프

> **목적**: 디자이너가 커스텀 디자인해야 할 아이콘 목록
> **현재**: Lucide Icons 107개 사용 중
> **커스텀 필요**: 아래 목록만 (나머지는 시스템 아이콘으로 유지)

---

## 1. 커스텀 디자인이 필요한 아이콘 (~35개)

시스템 아이콘(chevron, arrow, check 등)은 Lucide 그대로 써도 됩니다.
**앱의 브랜드 아이덴티티를 담아야 하는 아이콘**만 커스텀 디자인 대상입니다.

### 하단 탭바 (5개)

| 용도 | 현재 Lucide | 비고 |
|------|------------|------|
| 홈 | home | 탭바 핵심 — 브랜드 느낌 필요 |
| 학습 | bookOpen | |
| 퀴즈 | dumbbell 또는 별도 | 현재 퀴즈 아이콘 불명확 |
| 실전회화 | messageCircle | |
| MY | user | |

### 학습 카테고리 (4개)

| 용도 | 현재 Lucide | 비고 |
|------|------------|------|
| 단어 학습 | bookOpen | 홈 QuickStart 탭 |
| 문법 학습 | braces | 홈 QuickStart 탭 |
| 문장배열 | alignLeft | 홈 QuickStart 탭 |
| 가나 문자 | languages | 가나 학습 카드 |

### 실전회화 카테고리 (4개)

| 용도 | 현재 Lucide | 비고 |
|------|------------|------|
| 여행 | plane | |
| 일상 | store | |
| 비즈니스 | briefcase | |
| 자유대화 | messageSquare | 텍스트 탭 전용 |

### 게임화/성취 (8개)

| 용도 | 현재 Lucide | 비고 |
|------|------------|------|
| 스트릭/연속학습 | flame | 홈 화면 핵심 |
| XP/경험치 | zap | |
| 도전과제/트로피 | trophy | |
| 별점/별 | star | 피드백 점수 |
| 왕관/프리미엄 | crown | 구독 상태 |
| 축하 | partyPopper | 완료 화면 |
| 타겟/정확성 | target | 피드백 점수 |
| 업적/메달 | award | 도전과제 |

### 홈 바로가기 (4개)

| 용도 | 현재 Lucide | 비고 |
|------|------------|------|
| 단어장 | bookMarked | ShortcutGrid |
| 오답노트 | fileX | ShortcutGrid |
| 도전과제 | trophy | ShortcutGrid (위와 중복) |
| 가나 차트 | grid | ShortcutGrid |

### 통화/채팅 (6개)

| 용도 | 현재 Lucide | 비고 |
|------|------------|------|
| 전화 걸기 | phone | 음성통화 |
| 전화 끊기 | phoneOff | 통화 종료 |
| 마이크 | mic | 통화 중 |
| 마이크 끔 | micOff | 음소거 |
| 메시지 전송 | send | 채팅 입력 |
| 힌트 | lightbulb | 채팅 힌트 |

### 설정 (4개)

| 용도 | 현재 Lucide | 비고 |
|------|------------|------|
| 알림 | bell | 홈 헤더 + 설정 |
| JLPT 레벨 | graduationCap | 학습 설정 |
| 테마 | palette | 앱 설정 |
| 설정 | settings | 통화 설정 |

---

## 2. 시스템 아이콘 — 커스텀 불필요 (~72개)

이 아이콘들은 Lucide 그대로 사용합니다. 범용 UI 아이콘이라 커스텀하면 오히려 인지 혼란.

### 네비게이션/액션
chevronRight, chevronLeft, chevronUp, chevronDown, arrowLeft, arrowRight, arrowUpDown, arrowLeftRight, x, check, checkCircle, checkCircle2, xCircle, plus, search, refreshCw, rotateCw, rotateCcw

### 토글/상태
eye, eyeOff, lock, heart, thumbsUp, thumbsDown, alertCircle, alertTriangle, cloudOff, wifiOff, construction

### 미디어
play, playCircle, volume2, headphones, subtitles

### 텍스트/편집
pencil, edit, penTool, textCursorInput, clipboardList, clipboardCheck, listChecks, shuffle

### 기타 UI
clock, timer, calendar, circle, checkCheck, logOut, trash2, mail, shield, fileText, creditCard, folderOpen, barChart, barChart3, trendingUp, map, mapPin

### 테마
sun, moon, smartphone, vibrate

### 장식/메타
sparkles, flower2, leaf, sprout, treeDeciduous, brain, baby, flaskConical, badgeDollarSign, tv, library, messagesSquare, bookmarkPlus

---

## 3. Material Icons 잔존 (교체 또는 커스텀)

| 현재 | 파일 | 처리 |
|------|------|------|
| Icons.apple | login_view.dart | Apple 로고 — 유지 (브랜드 가이드라인) |
| Icons.email_outlined | login_view.dart | LucideIcons.mail로 교체 |
| Icons.celebration | quiz_page.dart | 커스텀 축하 아이콘 또는 LucideIcons.partyPopper |
| Icons.sentiment_dissatisfied | quiz_page.dart | 커스텀 실패 아이콘 또는 LucideIcons.frown |
| Icons.arrow_back | kana_quiz_page.dart | LucideIcons.arrowLeft로 교체 |

---

## 4. 디자인 가이드

### 크기 규격
- **16px**: 인라인 텍스트 옆 (라벨, 배지)
- **20px**: 리스트 아이템, 설정 메뉴 (가장 많이 사용)
- **24px**: 바로가기 그리드, 주요 액션
- **32px**: 빈 상태 일러스트

### 스타일 방향
- **현재**: Lucide (선형, 2px stroke, 둥근 cap)
- **권장**: 같은 선형 스타일 유지하되, 브랜드 컬러/곡률을 반영
- **참고**: Duolingo는 채움형(filled), 토스는 선형(outlined) — 우리 앱 톤에 맞게 결정

### 색상
- 브랜드 핑크: `#F6A5B3` / `#FA7B95`
- 성공(초록): `#2DB08A`
- 경고(주황): `#F59E0B`
- 에러(빨강): `#E8577D`
- 중립(회색): `onSurface` with alpha 0.3~0.6
