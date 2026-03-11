# 이미지/에셋 교체 가이드

> 현재 이모지로 대체 중인 시각 요소 목록. 포토샵/일러스트로 실제 에셋 제작 시 참고.

## 에셋 저장 위치

```
apps/web/public/images/
├── mascot/          # 마스코트 캐릭터
├── icons/           # 커스텀 아이콘 (카테고리, 레벨 등)
├── badges/          # 배지, 성과 아이콘
└── illustrations/   # 일러스트레이션 (빈 상태, 결과 등)
```

코드에서 사용: `<Image src="/images/mascot/greeting.png" />`

---

## 1. 마스코트 (🦊 → 캐릭터 일러스트)

앱 전체에서 사용되는 메인 캐릭터. 여우 컨셉 또는 새 캐릭터로 교체.

| # | 파일 | 라인 | 현재 | 용도 | 권장 에셋 | 사이즈 |
|---|------|------|------|------|-----------|--------|
| 1 | `app/(auth)/onboarding/page.tsx` | 106 | 🦊 text-4xl | 온보딩 1단계 인사 | `mascot/greeting.png` | 80x80 |
| 2 | `app/(auth)/onboarding/page.tsx` | 136 | 🦊 text-4xl | 온보딩 2단계 질문 | `mascot/thinking.png` | 80x80 |
| 3 | `app/(auth)/onboarding/page.tsx` | 185 | 🦊 text-4xl | 온보딩 3단계 목표 | `mascot/excited.png` | 80x80 |
| 4 | `app/(app)/chat/page.tsx` | 254 | 🦊 (원형 배경) | 하루와 자유 대화 CTA | `mascot/chat.png` | 48x48 |
| 5 | `components/features/chat/feedback-scores.tsx` | 48 | 🦊 text-5xl (애니메이션) | 피드백 점수 상단 | `mascot/feedback.png` | 96x96 |
| 6 | `app/(app)/chat/[conversationId]/feedback/page.tsx` | 92 | 🦊 text-4xl | 피드백 에러 상태 | `mascot/sad.png` | 80x80 |

**디자인 노트:** 마스코트 표정별 변형 필요 (인사, 생각, 흥분, 대화, 평가, 슬픔). 최소 6종.

---

## 2. 브랜드 심볼 (🌸 → 로고/아이콘)

벚꽃 모티프. 앱 로고나 커스텀 아이콘으로 교체.

| # | 파일 | 라인 | 현재 | 용도 | 권장 에셋 |
|---|------|------|------|------|-----------|
| 7 | `app/(auth)/onboarding/page.tsx` | 222 | 🌸 (버튼 텍스트) | "시작하기 🌸" 버튼 | 텍스트에서 제거하거나 작은 아이콘 |
| 8 | `app/(app)/study/page.tsx` | 109 | 🌸 (버튼 텍스트) | "학습 시작하기 🌸" 버튼 | 동일 |
| 9 | `components/features/dashboard/quick-start-card.tsx` | 18 | 🌸 text-2xl (원형 배지) | 대시보드 퀵스타트 | `icons/brand-icon.svg` 48x48 |

---

## 3. JLPT 레벨 아이콘 (🌱🌿🌳🌲 → 커스텀 아이콘)

성장 단계를 나타내는 식물 아이콘. 일관된 스타일의 커스텀 일러스트 추천.

| # | 파일 | 라인 | 현재 | 용도 | 권장 에셋 |
|---|------|------|------|------|-----------|
| 10 | `app/(auth)/onboarding/page.tsx` | 13 | 🌱 | N5 완전 초보 | `icons/level-n5.png` 40x40 |
| 11 | `app/(auth)/onboarding/page.tsx` | 19 | 🌿 | N4 기초 | `icons/level-n4.png` 40x40 |
| 12 | `app/(auth)/onboarding/page.tsx` | 25 | 🌳 | N3 중급 | `icons/level-n3.png` 40x40 |
| 13 | `app/(auth)/onboarding/page.tsx` | 31 | 🌲 | N2 고급 | `icons/level-n2.png` 40x40 |

**디자인 노트:** 나무 성장 4단계 (새싹→풀→나무→큰나무) 또는 벚꽃 개화 단계로 통일.

---

## 4. 학습 목표 아이콘 (🎯✈️💼🎌 → 커스텀 아이콘)

| # | 파일 | 라인 | 현재 | 용도 | 권장 에셋 |
|---|------|------|------|------|-----------|
| 14 | `app/(auth)/onboarding/page.tsx` | 38-40 | 🎯 x3 | JLPT N5/N4/N3 목표 | `icons/goal-jlpt.png` 40x40 |
| 15 | `app/(auth)/onboarding/page.tsx` | 41 | ✈️ | 여행 일본어 | `icons/goal-travel.png` 40x40 |
| 16 | `app/(auth)/onboarding/page.tsx` | 42 | 💼 | 비즈니스 일본어 | `icons/goal-business.png` 40x40 |
| 17 | `app/(auth)/onboarding/page.tsx` | 43 | 🎌 | 취미/문화 | `icons/goal-hobby.png` 40x40 |

---

## 5. 회화 카테고리 아이콘 (→ 커스텀 일러스트)

채팅 시나리오 선택 화면. 두 곳에서 같은 이모지 사용.

| # | 파일 | 라인 | 현재 | 용도 | 권장 에셋 |
|---|------|------|------|------|-----------|
| 18 | `app/(app)/chat/page.tsx` | 54-57 | ✈️ | 여행 시나리오 | `icons/scenario-travel.png` 48x48 |
| 19 | `app/(app)/chat/page.tsx` | 54-57 | 🏪 | 일상 시나리오 | `icons/scenario-daily.png` 48x48 |
| 20 | `app/(app)/chat/page.tsx` | 54-57 | 💼 | 비즈니스 시나리오 | `icons/scenario-business.png` 48x48 |
| 21 | `app/(app)/chat/page.tsx` | 54-57 | 🗣️ | 자유 시나리오 | `icons/scenario-free.png` 48x48 |
| - | `components/features/chat/category-grid.tsx` | 14-22 | 동일 | 재사용 컴포넌트 | 위와 동일 에셋 공유 |

**디자인 노트:** chat/page.tsx의 CATEGORY_META와 category-grid.tsx의 CATEGORIES 양쪽 모두 교체 필요.

---

## 6. 피드백 지표 아이콘

| # | 파일 | 라인 | 현재 | 용도 | 권장 에셋 |
|---|------|------|------|------|-----------|
| 22 | `components/features/chat/feedback-scores.tsx` | 17 | 🗣️ | 유창성 점수 | `icons/metric-fluency.svg` 24x24 |
| 23 | `components/features/chat/feedback-scores.tsx` | 18 | 🎯 | 정확성 점수 | `icons/metric-accuracy.svg` 24x24 |
| 24 | `components/features/chat/feedback-scores.tsx` | 19 | 📚 | 어휘 다양성 | `icons/metric-vocabulary.svg` 24x24 |
| 25 | `components/features/chat/feedback-scores.tsx` | 20 | 🌿 | 자연스러움 | `icons/metric-naturalness.svg` 24x24 |

---

## 7. 퀴즈 결과 일러스트

| # | 파일 | 라인 | 현재 | 용도 | 권장 에셋 |
|---|------|------|------|------|-----------|
| 26 | `app/(app)/study/result/page.tsx` | 29 | 🎉 text-6xl | 정답률 80%+ | `illustrations/result-excellent.png` 120x120 |
| 27 | `app/(app)/study/result/page.tsx` | 29 | 👍 text-6xl | 정답률 50-79% | `illustrations/result-good.png` 120x120 |
| 28 | `app/(app)/study/result/page.tsx` | 29 | 💪 text-6xl | 정답률 50% 미만 | `illustrations/result-tryagain.png` 120x120 |
| 29 | `app/(app)/study/quiz/page.tsx` | 164 | 🎉 text-5xl | 복습 완료 빈 상태 | `illustrations/review-complete.png` 96x96 |
| 30 | `app/(app)/study/quiz/page.tsx` | 164 | 😢 text-5xl | 문제 없음 빈 상태 | `illustrations/empty-quiz.png` 96x96 |
| 31 | `app/(app)/study/quiz/page.tsx` | 314 | ✅ / ❌ | 정답/오답 피드백 | Lucide 아이콘으로 대체 가능 (CheckCircle/XCircle) |

---

## 8. 섹션 헤더

| # | 파일 | 라인 | 현재 | 용도 | 권장 |
|---|------|------|------|------|------|
| 32 | `app/(app)/chat/page.tsx` | 270 | 🗂️ | "상황별 시나리오" 헤더 | Lucide `FolderOpen` 아이콘 또는 제거 |

---

## 제작 우선순위

1. **P0 - 마스코트** (6종): 앱 정체성. 가장 눈에 띄고 AI스러움이 강함
2. **P1 - 퀴즈 결과 일러스트** (5종): 사용 빈도 높음
3. **P1 - 카테고리/시나리오 아이콘** (4종): 메인 화면 노출
4. **P2 - 레벨/목표 아이콘** (8종): 온보딩에서만 사용
5. **P3 - 지표/기타** (5종): Lucide 아이콘으로 임시 대체 가능

## 에셋 사양

| 종류 | 포맷 | 사이즈 | 비고 |
|------|------|--------|------|
| 마스코트 | PNG (@2x) | 160x160, 96x96 | 투명 배경, 표정별 변형 |
| 아이콘 | SVG 또는 PNG | 48x48, 40x40 | 단색 또는 2색, 심플 |
| 일러스트 | PNG (@2x) | 240x240 | 투명 배경 |
| 지표 아이콘 | SVG | 24x24 | 단색, 라인 스타일 |

> **총 교체 대상: 32곳, 약 20종의 에셋 필요**
