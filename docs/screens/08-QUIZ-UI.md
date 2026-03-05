# 퀴즈 UI 상세 — Quiz Components

> 앱 전체에서 사용되는 퀴즈 컴포넌트 3종의 레이아웃, 인터랙션, 애니메이션 상세.
> JLPT 학습과 가나 학습에서 각각 다른 조합으로 사용된다.

---

## 퀴즈 타입 요약

| 타입 | 레이아웃 | 선택지 | 진행 방식 | 사용처 |
|------|---------|--------|----------|--------|
| JLPT 4지선다 | 세로 1열 | 4개 | 수동 (버튼) | `/study/quiz` |
| 가나 2×2 | 2×2 그리드 | 4개 | 자동 (1초) | 가나 스테이지/퀴즈 |
| 매칭 페어 (공용) | 좌우 2열 | 5쌍 | 자동 (매칭 시 사라짐) | JLPT 매칭모드, 가나 퀴즈 매칭모드 |
| 가나 페어 매칭 | 좌우 2열 | 4쌍 | 자동 (매칭 시 잔존) | 가나 스테이지 Phase 3 |

---

## 1. JLPT 4지선다 퀴즈

### 파일 위치

- **페이지**: `apps/web/src/app/(app)/study/quiz/page.tsx`
- **훅**: `hooks/use-quiz.ts` (useStartQuiz, useResumeQuiz, useAnswerQuestion, useCompleteQuiz)

### 와이어프레임

```
┌─────────────────────────────────┐
│  ← 뒤로   N5 단어 퀴즈   7/20  │  ← 헤더
│  ████████████░░░░░░░░░░░░░░░░  │  ← 프로그레스 바 (motion 애니메이션)
├─────────────────────────────────┤
│                                 │
│                                 │
│         「 食べる 」            │  ← questionText (text-4xl bold, font-jp)
│          たべる                 │  ← questionSubText (text-lg)
│     이 단어의 뜻은?             │  ← 안내 텍스트
│                                 │
│                                 │
│  ┌─[①]─────────────────────┐  │
│  │  먹다                    │  │  ← 옵션 카드 (세로 리스트)
│  └──────────────────────────┘  │    flex-col gap-2.5
│  ┌─[②]─────────────────────┐  │    각 카드: rounded-xl border-2
│  │  마시다                  │  │    px-4 py-3.5
│  └──────────────────────────┘  │
│  ┌─[③]─────────────────────┐  │    좌측: 번호 원형 뱃지
│  │  보다                    │  │    (size-7, bg-secondary,
│  └──────────────────────────┘  │     rounded-full, text-xs bold)
│  ┌─[④]─────────────────────┐  │
│  │  듣다                    │  │    순차 fade-in
│  └──────────────────────────┘  │    (delay: index × 0.06s)
│                                 │
│           [💡 힌트 보기]        │  ← 힌트 토글 (접기/펼치기)
│                                 │
└─────────────────────────────────┘
```

### 답 선택 후 상태

```
┌─────────────────────────────────┐
│  ← 뒤로   N5 단어 퀴즈   7/20  │
│  ████████████░░░░░░░░░░░░░░░░  │
├─────────────────────────────────┤
│                                 │
│         「 食べる 」            │
│          たべる                 │
│                                 │
│  ┌─[①]─────────────────────┐  │  ← 정답 옵션
│  │  ✅ 먹다                 │  │    border-hk-success
│  └──────────────────────────┘  │    bg-hk-success/10
│  ┌─[②]─────────────────────┐  │    scale pulse 1→1.04→1
│  │  ❌ 마시다 (내가 선택)   │  │
│  └──────────────────────────┘  │  ← 오답 선택 옵션
│  ┌─[③]─────────────────────┐  │    border-hk-error
│  │  보다          opacity 40%│  │    bg-hk-error/10
│  └──────────────────────────┘  │    shake x:[0,-8,8,-6,6,-3,3,0]
│  ┌─[④]─────────────────────┐  │
│  │  듣다          opacity 40%│  │  ← 미선택 옵션
│  └──────────────────────────┘  │    opacity-40
│                                 │
│  ┌──── 피드백 패널 ────────────┐│
│  │                             ││  ← 하단 슬라이드업 (spring)
│  │  ✅ 정답이에요!             ││    damping: 25, stiffness: 300
│  │                             ││    rounded-t-2xl border-t
│  │  또는                       ││
│  │                             ││    정답: bg-hk-success/5
│  │  ❌ 아쉬워요!               ││         border-hk-success/30
│  │  정답: 먹다                 ││    오답: bg-hk-error/5
│  │           [📕 단어장에 추가]││         border-hk-error/30
│  │                             ││
│  │  (힌트 텍스트 표시)         ││    오답 시 단어장 저장 버튼
│  │                             ││    (VOCABULARY 퀴즈만 표시)
│  │  [다음 문제 →]              ││
│  │  또는 마지막이면 [결과 보기]││
│  │                             ││
│  └─────────────────────────────┘│
└─────────────────────────────────┘
```

### 인터랙션 흐름

```
문제 표시 (fade-in y:20→0)
    │
    ├── 옵션 순차 등장 (delay: i × 0.06s)
    │
    ├── [💡 힌트 보기] 토글 가능
    │
    ▼
사용자 옵션 선택 (tap → scale 0.98)
    │
    ├── 정답 옵션: 초록 + pulse 애니메이션
    ├── 오답 선택: 빨강 + shake 애니메이션
    ├── 나머지: opacity 40%
    │
    ▼
피드백 패널 슬라이드업 (y: 100% → 0)
    │
    ├── 정답: "정답이에요!" + CircleCheck 아이콘
    ├── 오답: "아쉬워요!" + CircleX 아이콘
    │         정답 텍스트 표시
    │         [📕 단어장에 추가] 버튼 (단어 퀴즈만)
    ├── 힌트 텍스트 항상 표시
    │
    ▼
[다음 문제 →] 클릭
    │
    ├── 현재 문제 exit (opacity→0, y→-20)
    ├── 다음 문제 enter (opacity→0→1, y→20→0)
    │
    ▼
마지막 문제 → [결과 보기] → /study/result 이동
```

### 특수 모드

| 모드 | query param | 설명 |
|------|-------------|------|
| 기본 | `?type=VOCABULARY&level=N5&count=10` | 일반 퀴즈 |
| 오답 복습 | `?mode=review` | 이전 오답만 출제. 빈 문제 시 PartyPopper + "복습할 문제가 없어요!" |
| 매칭 | `?mode=matching` | MatchingPairQuiz 컴포넌트로 렌더링 전환 |
| 이어풀기 | `?resume=세션ID` | 이전 진행 위치부터 재개 |

---

## 2. 가나 2×2 퀴즈 (KanaQuiz)

### 파일 위치

- **컴포넌트**: `apps/web/src/components/features/kana/kana-quiz.tsx`
- **사용처**:
  - 가나 스테이지 학습 Phase 4 (`/study/kana/[type]/stage/[number]`)
  - 가나 퀴즈 페이지 (`/study/kana/[type]/quiz`)
- **훅**: `hooks/use-kana-quiz.ts`

### 와이어프레임

```
┌─────────────────────────────────┐
│  문제 풀기                3/5   │
│  ██████░░░░░░░░░░░░░░░░░░░░░  │  ← Progress 컴포넌트
├─────────────────────────────────┤
│                                 │
│                                 │
│              あ                 │  ← 가나 문자일 때:
│                                 │    font-jp text-5xl bold
│           (subText)             │
│                                 │  ← 로마자일 때:
│                                 │    text-3xl bold
│                                 │
│  ┌────────────┬────────────┐   │
│  │            │            │   │  ← 2×2 그리드
│  │     a      │     i      │   │    grid-cols-2 gap-3
│  │            │            │   │    min-h-[56px]
│  ├────────────┼────────────┤   │    rounded-xl, border
│  │            │            │   │    text-center font-medium
│  │     u      │     e      │   │
│  │            │            │   │
│  └────────────┴────────────┘   │
│                                 │
└─────────────────────────────────┘
```

### 답 선택 후 상태 (1초간 표시 → 자동 진행)

```
┌────────────┬────────────┐
│ ✅ a       │     i      │  ← 정답: border-hk-success
│ 초록 배경   │            │          bg-hk-success/10
├────────────┼────────────┤          text-hk-success
│     u      │ ❌ e       │
│            │ 빨강 배경   │  ← 오답 선택: border-destructive
└────────────┴────────────┘          bg-destructive/10
  나머지: opacity 50%                text-destructive

  → 1초 후 자동으로 다음 문제
  → 마지막 문제 후 onComplete 콜백
```

### 인터랙션 흐름

```
문제 표시 (슬라이드: x:20→0)
    │
    ▼
사용자 2×2 중 택 1 (tap → scale 0.96)
    │
    ├── 정답: 초록 하이라이트
    ├── 오답 선택: 빨강 하이라이트
    ├── 나머지: opacity 50%
    │
    ▼
1초 자동 대기 (setTimeout 1000ms)
    │
    ├── 다음 문제 있음 → 슬라이드 전환 (x:-20 exit → x:20 enter)
    ├── 마지막 문제 → onComplete({ correct, total, wrongQuestionIds })
    │
    ▼
(페이지에 따라 결과 처리)
  ├── 가나 스테이지: Phase 5 복습 또는 Phase 6 완료
  ├── 가나 퀴즈: /study/result 이동
  └── 마스터 퀴즈: 합격/불합격 결과 화면
```

### JLPT 퀴즈와 차이점

| 항목 | JLPT 4지선다 | 가나 2×2 |
|------|-------------|----------|
| 레이아웃 | 세로 1열 (flex-col) | 2×2 그리드 (grid-cols-2) |
| 번호 뱃지 | ①②③④ 원형 뱃지 있음 | 없음 |
| 진행 방식 | "다음" 버튼 수동 | 1초 자동 진행 |
| 피드백 패널 | 하단 슬라이드업 패널 | 없음 (색상만) |
| 힌트 | 💡 힌트 보기 버튼 | 없음 |
| 단어장 저장 | 오답 시 저장 가능 | 없음 |
| 문제 전환 | y축 (y:20→0→-20) | x축 (x:20→0→-20) |
| 최소 높이 | py-3.5 | min-h-[56px] |

---

## 3. 매칭 페어 퀴즈 (MatchingPairQuiz) — 공용

### 파일 위치

- **컴포넌트**: `apps/web/src/components/features/quiz/matching-pair.tsx`
- **사용처**:
  - JLPT 퀴즈 매칭 모드 (`/study/quiz?mode=matching`)
  - 가나 퀴즈 매칭 모드 (`/study/kana/[type]/quiz?mode=kana_matching`)

### 와이어프레임

```
┌─────────────────────────────────┐
│                                 │
│  ┌─── 좌측 (문제) ──┬─── 우측 (답, 셔플) ──┐
│  │                  │                      │
│  │  ┌────────────┐  │  ┌────────────┐      │  ← 좌우 2열 (flex gap-3)
│  │  │   食べる   │  │  │   보다     │      │    각 열: flex-1 flex-col gap-2.5
│  │  │            │  │  │            │      │
│  │  └────────────┘  │  └────────────┘      │    각 카드:
│  │  ┌────────────┐  │  ┌────────────┐      │    min-h-[52px]
│  │  │    飲む    │  │  │   먹다     │      │    rounded-xl border-2
│  │  │  [선택됨]  │  │  │            │      │    px-3 py-2.5
│  │  │ primary色  │  │  │            │      │    text-center font-medium
│  │  └────────────┘  │  └────────────┘      │
│  │  ┌────────────┐  │  ┌────────────┐      │    일본어 텍스트:
│  │  │    見る    │  │  │   마시다   │      │    font-jp text-xl
│  │  └────────────┘  │  └────────────┘      │
│  │  ┌────────────┐  │  ┌────────────┐      │
│  │  │   聞く    │  │  │   듣다     │      │
│  │  └────────────┘  │  └────────────┘      │
│  │  ┌────────────┐  │  ┌────────────┐      │
│  │  │   書く    │  │  │   쓰다     │      │
│  │  └────────────┘  │  └────────────┘      │
│  │                  │                      │
│  └──────────────────┴──────────────────────┘
│                                 │
│           3/5 매칭 완료          │  ← 하단 진행 텍스트
│                                 │
└─────────────────────────────────┘
```

### 매칭 인터랙션 (정답)

```
Step 1: 좌측 카드 선택
┌────────────┐     ┌────────────┐
│   食べる   │     │   보다     │
│ [선택됨]   │     │            │
│ primary색  │     │            │
│ bg-primary/5│    │ hover 활성 │
└────────────┘     └────────────┘

Step 2: 우측에서 정답 선택
┌────────────┐     ┌────────────┐
│   食べる   │     │   먹다     │
│  초록 배경  │     │  초록 배경  │   ← 정답! 양쪽 모두 초록
│  scale      │     │  scale     │      scale [1, 1.04, 1]
│  [1→1.04→1]│     │  [1→1.04→1]│
└────────────┘     └────────────┘

Step 3: 400ms 후 fade out 시작
┌────────────┐     ┌────────────┐
│   食べる   │     │   먹다     │   ← opacity: 0, scale: 0.95
│ (사라지는중)│     │(사라지는중) │      duration: 400ms
└────────────┘     └────────────┘

Step 4: 800ms 후 완전 제거 (AnimatePresence exit)
     (빈 공간)           (빈 공간)      ← layout 애니메이션으로
                                          나머지 카드 자연스럽게 이동
```

### 매칭 인터랙션 (오답)

```
좌측 선택 후 → 우측에서 오답 선택
┌────────────┐     ┌────────────┐
│   食べる   │     │   보다     │
│  shake     │     │            │   ← 좌측만 shake
│ x:[0,-8,   │     │            │      x:[0,-8,8,-6,6,-3,3,0]
│  8,-6,6,   │     │            │      duration: 400ms
│  -3,3,0]   │     │            │
└────────────┘     └────────────┘

600ms 후 → 선택 해제 (feedback → idle)
  첫 오답 시 wrongPairs에 기록
```

### 라운드 시스템

```
전체 문제: 10쌍
    │
    ├── 라운드 1: 쌍 1~5 (PAIRS_PER_ROUND = 5)
    │   └── 5쌍 모두 매칭 → 결과 누적
    │
    ├── 라운드 2: 쌍 6~10
    │   └── 5쌍 모두 매칭 → 결과 누적
    │
    └── 모든 라운드 완료
        └── onComplete({ correct, total, wrongPairIds })
            └── 퀴즈 완료 처리 → /study/result
```

---

## 4. 가나 페어 매칭 (KanaPairMatching) — 가나 스테이지 전용

### 파일 위치

- **컴포넌트**: `apps/web/src/components/features/kana/kana-pair-matching.tsx`
- **사용처**: 가나 스테이지 학습 Phase 3 (`/study/kana/[type]/stage/[number]`)

### 와이어프레임

```
┌─────────────────────────────────┐
│  짝 맞추기   라운드 1/3    2/4  │
│  ████████░░░░░░░░░░░░░░░░░░░  │  ← Progress 컴포넌트
│                                 │
│  왼쪽 가나와 오른쪽 로마지를     │  ← 안내 텍스트
│  짝지어 주세요                   │
│                                 │
│  ┌─── 가나 (좌) ──┬─── 로마지 (우, 셔플) ──┐
│  │                │                        │
│  │  ┌──────────┐  │  ┌──────────┐          │  ← grid-cols-2 gap-3
│  │  │    あ    │  │  │    e     │          │    각 카드:
│  │  │ text-2xl │  │  │  text-lg │          │    min-h-[60px]
│  │  │ font-jp  │  │  │          │          │    rounded-xl, border
│  │  └──────────┘  │  └──────────┘          │
│  │  ┌──────────┐  │  ┌──────────┐          │
│  │  │    い    │  │  │    a     │          │
│  │  │ [선택됨] │  │  │          │          │    선택 상태:
│  │  │ ring-2   │  │  │          │          │    ring-2 ring-primary/30
│  │  │primary/30│  │  │          │          │    border-primary
│  │  └──────────┘  │  └──────────┘          │
│  │  ┌──────────┐  │  ┌──────────┐          │
│  │  │  う ✓   │  │  │  u  ✓   │          │    매칭 완료:
│  │  │ 초록     │  │  │ 초록     │          │    border-hk-success
│  │  │ opacity  │  │  │ opacity  │          │    bg-hk-success/20
│  │  │ 60%      │  │  │ 60%      │          │    opacity-60
│  │  └──────────┘  │  └──────────┘          │    ✓ 체크 아이콘 (우상단)
│  │  ┌──────────┐  │  ┌──────────┐          │
│  │  │    え    │  │  │    i     │          │
│  │  └──────────┘  │  └──────────┘          │
│  │                │                        │
│  └────────────────┴────────────────────────┘
│                                 │
└─────────────────────────────────┘
```

### MatchingPairQuiz(공용)와 차이점

| 항목 | MatchingPairQuiz (공용) | KanaPairMatching (가나 전용) |
|------|------------------------|---------------------------|
| 파일 | `quiz/matching-pair.tsx` | `kana/kana-pair-matching.tsx` |
| 쌍 수/라운드 | 5쌍 | 4쌍 |
| 선택 순서 | 좌측 먼저 → 우측 | 양쪽 어디서든 자유 |
| 선택 표시 | border-primary, bg-primary/5 | ring-2 ring-primary/30 |
| 정답 처리 | 초록 → fade out → **완전 제거** | 초록 + ✓ 체크 → **opacity 60% 잔존** |
| 정답 타이밍 | 400ms 하이라이트 → 800ms 제거 | 즉시 매칭 상태 전환 |
| 오답 처리 | 좌측만 shake, 600ms | 양쪽 shake, 500ms |
| 카드 높이 | min-h-[52px] | min-h-[60px] |
| 텍스트 크기 | 일본어: text-xl | 가나: text-2xl / 로마지: text-lg |
| 안내 텍스트 | 없음 | "왼쪽 가나와 오른쪽 로마지를 짝지어 주세요" |
| 라운드 표시 | 하단 "n/n 매칭 완료" | 상단 Badge "라운드 n/n" + Progress |

---

## 공통 애니메이션 패턴

### 정답 피드백

```
pulse (정답 옵션 강조)
─────────────────────
  scale: [1, 1.04, 1]
  duration: 0.3s

  사용: JLPT 4지선다 정답 옵션
       MatchingPairQuiz 정답 매칭
       KanaPairMatching 정답 매칭
```

### 오답 피드백

```
shake (오답 옵션 흔들림)
─────────────────────
  x: [0, -8, 8, -6, 6, -3, 3, 0]
  duration: 0.4s

  사용: JLPT 4지선다 오답 선택
       MatchingPairQuiz 오답 매칭 (좌측)
       KanaPairMatching 오답 매칭 (양쪽)
```

### 문제 전환

```
JLPT 4지선다:
  exit:  { opacity: 0, y: -20 }
  enter: { opacity: 0→1, y: 20→0 }

가나 2×2:
  exit:  { opacity: 0, x: -20 }
  enter: { opacity: 0→1, x: 20→0 }
  duration: 0.2s
```

### 카드 제거 (MatchingPairQuiz)

```
fade out → exit:
  animate: { opacity: 0, scale: 0.95 }  (400ms 후 시작)
  exit:    { opacity: 0, scale: 0.9 }   (800ms 후 DOM 제거)
  나머지 카드: layout 애니메이션으로 자연스럽게 재배치
```

---

## 색상 시스템

| 상태 | 색상 토큰 | 용도 |
|------|----------|------|
| 정답 | `hk-success` | border, bg/10, text |
| 오답 | `hk-error` 또는 `destructive` | border, bg/10, text |
| 선택 | `primary` | border, bg/5, text, ring |
| 비활성 | `border` | 기본 border |
| 미선택 (답변 후) | `opacity-40` ~ `opacity-50` | 나머지 옵션 |
| 매칭 완료 (잔존) | `hk-success` + `opacity-60` | KanaPairMatching |

---

## 데이터 흐름

```
퀴즈 시작
    │
    ├── JLPT: useStartQuiz({ quizType, jlptLevel, count, mode })
    ├── 가나: useStartKanaQuiz({ kanaType, stageNumber, quizMode, count })
    │
    ▼
서버 응답: { sessionId, questions[] }
    │
    ├── questions[]: { questionId, questionText, questionSubText,
    │                  options[{ id, text }], correctOptionId, hint? }
    │
    ▼
매 문제 답변
    │
    ├── JLPT: useAnswerQuestion({ sessionId, questionId, selectedOptionId,
    │                              isCorrect, timeSpentSeconds, questionType })
    ├── 가나: useAnswerKanaQuestion({ sessionId, questionId, selectedOptionId })
    │
    ▼
퀴즈 완료
    │
    ├── JLPT: useCompleteQuiz({ sessionId })
    │         → { correctCount, totalQuestions, xpEarned, accuracy, events }
    │         → /study/result 이동
    │
    ├── 가나: useCompleteKanaQuiz({ sessionId })
    │         → { accuracy, xpEarned, currentXp, xpForNext }
    │         → /study/result 이동 또는 마스터 결과 화면
    │
    └── 매칭: 라운드별 결과 누적 → 전체 완료 시 동일 흐름
```
