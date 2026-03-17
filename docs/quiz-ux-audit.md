# 퀴즈 UX 감사 및 개선 계획

## 1. 아이콘 적합성 검토

| 위치 | 현재 아이콘 | 판정 | 개선안 |
|------|-----------|------|--------|
| 퀴즈 모드 4지선다 | `bookOpen` | 부적합 | `listChecks` — 체크리스트 = 선택 |
| 결과 페이지 오답수 | `trophy` | 부적합 | `circleX` — 오답 의미 명확 |
| 단어장 (practice_page) | `bookmark` | 불일치 | `bookMarked` — study_page와 통일 |
| 퀴즈 모드 매칭 | `link2` | 애매 | `shuffle` — 짝 맞추기 직관적 |

나머지 아이콘은 적합.

---

## 2. 햅틱 피드백 (현재: 전무)

### 추가 지점

| 이벤트 | 햅틱 타입 | 파일 |
|--------|----------|------|
| 정답 선택 | `lightImpact` | quiz_page.dart (_onAnswer) |
| 오답 선택 | `notificationError` | quiz_page.dart (_onAnswer) |
| 연속 정답 3+ | `mediumImpact` | quiz_page.dart (_onAnswer) |
| 매칭 쌍 성공 | `selectionClick` | matching_quiz.dart |
| 퀴즈 완료 | `heavyImpact` | quiz_page.dart (_completeQuiz) |
| CTA 버튼 탭 | `selectionClick` | practice_page.dart |

---

## 3. 효과음 (현재: 퀴즈에서 전무)

### 우선순위

| 순위 | 이벤트 | 효과음 | 길이 |
|------|--------|-------|------|
| P0 | 정답 | 짧은 "딩" | ~0.3초 |
| P0 | 오답 | 낮은 "붕" | ~0.3초 |
| P1 | 퀴즈 완료 80%+ | 팡파레 | ~1초 |
| P1 | 연속 정답 3+ | 콤보 사운드 | ~0.5초 |
| P2 | 매칭 성공 | 클릭음 | ~0.2초 |

설정에서 ON/OFF 토글 필수 (전철 등 공공장소 배려).

---

## 4. 애니메이션 / 시각 피드백

### 현재 있는 것 (유지)
- 진행률 바 TweenAnimation (300ms)
- 결과 원형 차트 AnimationController (1.2s)
- 확장/축소 AnimatedRotation (200ms)
- 퀴즈 전환 zero-duration route (의도적)

### 부족한 것

| 항목 | 현재 | 개선안 | 난이도 |
|------|------|--------|--------|
| 오답 시 피드백 | 색 변경만 | shake 애니메이션 0.3초 | 보통 |
| 정답 시 피드백 | 색 변경만 | scale up (1.05) + 체크 | 쉬움 |
| 오답 시 정답 표시 | 없음 | 정답 선택지 초록 강조 | 쉬움 |
| 퀴즈 완료 축하 | 정적 아이콘 | confetti 파티클 (80%+) | 보통 |
| 스트릭 달성 | 텍스트만 | flame bounce 애니메이션 | 쉬움 |
| 매칭 성공 쌍 | 즉시 사라짐 | fade out + scale down | 보통 |

---

## 5. 실행 로드맵

### P0: 즉시 (체감 효과 최대, 난이도 낮음)

- [ ] **5-1. 햅틱 피드백 추가** — 정답/오답/매칭/완료 시 HapticFeedback 호출
- [ ] **5-2. 오답 shake 애니메이션** — 선택지가 좌우로 흔들리는 0.3초 애니메이션
- [ ] **5-3. 아이콘 4건 수정** — 4지선다, 결과 오답, 단어장, 매칭 아이콘 교체

### P1: 다음 스프린트 (효과음 + 시각 강화)

- [ ] **5-4. 효과음 시스템 구축** — 정답/오답 사운드 + 설정 토글
- [ ] **5-5. 정답 시 scale up 애니메이션** — 선택지 1.05x 확대 + 체크 아이콘
- [ ] **5-6. 오답 시 정답 하이라이트** — 틀렸을 때 정답이 어디였는지 표시

### P2: 이후 (폴리시)

- [ ] **5-7. 퀴즈 완료 confetti** — 80%+ 달성 시 파티클 애니메이션 (confetti 패키지)
- [ ] **5-8. 매칭 성공 fade out** — 맞춘 쌍이 부드럽게 사라지는 전환
- [ ] **5-9. 스트릭 bounce** — 연속 정답 카운터 bounce 효과

---

## 6. 기술 메모

### 햅틱
```dart
import 'package:flutter/services.dart';
HapticFeedback.lightImpact();   // 정답
HapticFeedback.heavyImpact();   // 오답, 완료
HapticFeedback.selectionClick(); // 매칭, 버튼
```
외부 패키지 불필요. Flutter 기본 제공.

### 효과음
`audioplayers` 패키지 추가 필요. 에셋 파일 `assets/sounds/` 디렉토리.
설정은 SharedPreferences (`sound_enabled` 키).

### Confetti
`confetti: ^0.7.0` 패키지. 결과 페이지에서만 사용.

### Shake 애니메이션
AnimationController + Transform.translate로 구현.
외부 패키지 불필요.
