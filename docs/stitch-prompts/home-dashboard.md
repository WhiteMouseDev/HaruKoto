# Stitch Prompts — HaruKoto Home Dashboard

## Prompt 1: 홈 대시보드 (라이트 모드)

```
Design a premium mobile home dashboard for "HaruKoto", a Japanese language learning app for Korean speakers.

App brand: Spring/cherry blossom theme. Primary color: soft pink (#F6A5B3), strong pink accent (#FA7B95). Warm cream background (#FCF6F5). White cards with subtle shadows.

The screen is a vertically scrolling page with these sections in order:

1. HEADER (top)
   - Left: Japanese greeting "おはよう!" in pink, below it "오늘도 화이팅, 건우!" in bold black
   - Right: Notification bell icon in a soft circle with a red badge showing unread count "3"

2. STREAK CARD
   - Flame icon with text "7일째 연속 학습 중!"
   - Row of 7 day circles (Mon-Sun): completed days show pink circle with white checkmark, today shows outlined circle, future days are gray
   - Subtle card with rounded corners (24px), soft shadow

3. QUICK START CARD (hero card, tallest element)
   - Left side: Large category icon (72px), review accuracy "복습 정답률 85%", title "단어 학습", daily goal "하루 목표 10개", circular progress ring showing 60%
   - Right side: 3 vertical tab icons (vocabulary/grammar/sentence) with organic curved connection to the active tab
   - Bottom: Full-width strong pink CTA button "오늘의 단어 시작하기"
   - This card should feel premium and be the visual anchor of the page

4. DAILY MISSIONS CARD
   - Header: "오늘의 미션" with "2/4" counter
   - List of 4 mission items, each with: circle icon (pink if done, gray if not), mission label, progress "3/5" or "+10 XP" if completed
   - Completed missions have strikethrough text

5. WEEKLY CHART CARD
   - Header: "주간 학습"
   - Bar chart showing 7 days, bars in pink (met goal) or light gray (missed)
   - Dashed goal line at 30% height
   - Summary: "단어 42개 · 150 XP"
   - Link: "학습 통계 자세히 보기 →"

6. SHORTCUT GRID (4 icons in a row)
   - 단어장 (pink), 오답노트 (coral #EF8354), 도전과제 (yellow #EAB308), 가나 차트 (cyan #6DB3CE)
   - Each: colored icon in rounded square + label below

Visual direction: Premium, clean, Duolingo-level polish but more elegant and calm. Strong typography hierarchy. Cards should have depth with subtle shadows. Generous spacing (8px grid). Mobile-first (390px width). Production-ready quality, not prototype.

Font: Use clean sans-serif. Korean text should look natural.
```

## Prompt 2: 홈 대시보드 (다크 모드)

```
Design the same Japanese learning app "HaruKoto" home dashboard, but in DARK MODE.

Dark theme colors: Deep navy background (#1A1A2E), slate cards (#242442), subtle borders (#3A3A5C at 30% opacity). Primary accent: soft pink (#F6A5B3) and strong pink (#FA7B95). Text: white (#FFFFFF) for primary, 60% white for secondary.

Same layout as before with these sections:

1. HEADER: "おはよう!" in pink, "오늘도 화이팅, 건우!" in white bold. Notification bell with pink badge.

2. STREAK CARD: Flame icon, "7일째 연속 학습 중!" in white. 7 day circles: completed = pink with checkmark, today = outlined pink, future = dark gray. Card background: #242442 with subtle border.

3. QUICK START CARD (hero): Same structure. Category icon on soft pink glow background. Progress ring in pink. CTA button in strong pink (#FA7B95). Tab icons on right with organic curve. This should glow subtly against the dark background.

4. DAILY MISSIONS: Same structure on dark card. Completed items in 40% opacity white with strikethrough. XP badges in green accent.

5. WEEKLY CHART: Pink bars on dark background. Gray dashed goal line. Summary text in secondary white.

6. SHORTCUT GRID: 4 icons with colored backgrounds at 15% opacity on dark surface.

Visual direction: Premium dark UI like Apple's dark mode. Not just inverted — carefully tuned for contrast and readability. Cards should float with subtle elevation. Pink accents should pop against the dark navy. Production-ready, elegant, premium feel.
```

## Prompt 3: 퀴즈 결과 화면

```
Design a quiz result screen for "HaruKoto" Japanese learning app.

Show the result after completing a vocabulary quiz with strong gamification elements:

1. TOP AREA: Celebratory header with confetti-like decoration. Large score "8/10" with a grade badge (A+, S rank style). Animated-ready layout.

2. STATS ROW: Three stat cards in a row:
   - 정답률: "80%" with green accent
   - 획득 XP: "+25 XP" with yellow accent
   - 소요 시간: "2분 30초" with blue accent

3. STREAK IMPACT: "🔥 8일째 연속 학습!" banner with flame icon. Show streak contribution.

4. WRONG ANSWERS SECTION: "틀린 문제 복습" header. List 2 items:
   - Japanese word, Korean meaning, correct answer highlighted in green

5. CTA BUTTONS (bottom):
   - Primary (full width, pink): "틀린 문제 다시 풀기"
   - Secondary (outlined): "다음 퀴즈 도전하기"
   - Tertiary (text link): "홈으로 돌아가기"

Colors: Light mode with warm cream background. Pink primary (#F6A5B3). Green for correct (#4CAF50). Coral for wrong (#EF8354). Premium, game-like but not childish. Celebrate achievement while encouraging retry.
```
