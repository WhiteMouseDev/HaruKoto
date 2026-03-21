# 학습 고도화 UI 설계서 — Quiz V2 Components

> 08-QUIZ-UI.md의 기존 4종(4지선다, 2×2, 매칭 페어, 가나 페어)에 더해,
> STUDY_SYSTEM_V2.md Phase 2~6에서 추가할 **새로운 퀴즈 컴포넌트 4종**과
> **기존 화면 개편 2종**의 UI/UX 상세.

---

## 목차

1. [빈칸 채우기 (ClozeQuiz)](#1-빈칸-채우기-clozequiz) — Phase 2
2. [어순 배열 (SentenceArrangeQuiz)](#2-어순-배열-sentencearrangequiz) — Phase 3
3. [글자 입력 3단계 (CharacterInput)](#3-글자-입력-characterinput) — Phase 4
4. [합성 퀴즈 세션 래퍼 (QuizSession)](#4-합성-퀴즈-세션-래퍼-quizsession) — 아키텍처
5. [퀴즈 결과 화면 개편](#5-퀴즈-결과-화면-개편) — Phase 6
6. [학습 메인 페이지 개편](#6-학습-메인-페이지-개편) — Phase 6
7. [마이크로 인터랙션 고도화](#7-마이크로-인터랙션-고도화) — 전체 적용
8. [새로운 퀴즈 타입 요약표](#8-새로운-퀴즈-타입-요약표)

---

## 1. 빈칸 채우기 (ClozeQuiz)

### 파일 위치

- **컴포넌트**: `apps/web/src/components/features/quiz/cloze-quiz.tsx`
- **사용처**: `/study/quiz?mode=cloze` (JLPT 문법/단어)
- **훅**: `hooks/use-quiz.ts` 확장

### 와이어프레임 — 문제 표시

```
┌─────────────────────────────────┐
│  ← 뒤로   N5 문법 퀴즈   3/10  │  ← 공용 헤더
│  ██████████░░░░░░░░░░░░░░░░░░  │  ← 프로그레스 바
├─────────────────────────────────┤
│                                 │
│                                 │
│   わたし _____ がくせいです。    │  ← 문장 (font-jp text-xl)
│                                 │     빈칸: border-b-2 border-dashed
│   (나는 학생입니다)              │  ← 한국어 번역 (text-muted-foreground)
│                                 │
│   이 문장의 빈칸에 들어갈 말은?  │  ← 안내 텍스트 (text-sm)
│                                 │
│                                 │
│  ┌──────┐  ┌──────┐  ┌──────┐ │
│  │  は   │  │  が   │  │  を   │ │  ← 보기 칩 (가로 나열)
│  └──────┘  └──────┘  └──────┘ │    flex-wrap gap-2
│                                 │    rounded-xl border-2
│  ┌──────┐                      │    min-w-[56px] py-3
│  │  に   │                      │    text-center font-jp
│  └──────┘                      │    font-medium text-lg
│                                 │
└─────────────────────────────────┘
```

### 빈칸 렌더링 세부

```
빈칸 미선택 상태:
  わたし _______ がくせいです。
          ↑
  inline-block min-w-[48px]
  border-b-2 border-dashed border-primary/40
  animate-pulse (미약한 깜빡임)

빈칸 선택 후 (채워진 상태):
  わたし  は  がくせいです。
          ↑
  inline-block px-2 py-0.5
  bg-primary/10 border-b-2 border-primary
  font-bold text-primary
  scale-in 애니메이션 (0 → 1, duration: 0.2s)
```

### 답 선택 후 상태 — 정답

```
┌─────────────────────────────────┐
│                                 │
│   わたし  は  がくせいです。    │  ← 빈칸에 정답 채워짐
│                                 │     bg-hk-success/10
│   (나는 학생입니다)              │     border-hk-success
│                                 │
│  ┌──────┐  ┌──────┐  ┌──────┐ │
│  │ ✅ は │  │  が   │  │  を   │ │  ← 정답 칩: hk-success + pulse
│  │ 초록  │  │ 40%  │  │ 40%  │ │    나머지: opacity-40
│  └──────┘  └──────┘  └──────┘ │
│                                 │
│  ┌──── 피드백 패널 ────────────┐│
│  │                             ││  ← 하단 슬라이드업 (기존 패턴)
│  │  ✅ 정답이에요!             ││
│  │                             ││
│  │  📝 は는 주제를 나타내는    ││  ← 문법 해설
│  │  조사예요. "~은/는"에       ││    bg-secondary rounded-xl p-3
│  │  해당합니다.                ││    text-sm text-muted-foreground
│  │                             ││
│  │  [다음 문제 →]              ││
│  │                             ││
│  └─────────────────────────────┘│
└─────────────────────────────────┘
```

### 답 선택 후 상태 — 오답

```
┌─────────────────────────────────┐
│                                 │
│   わたし  が  がくせいです。    │  ← 빈칸에 오답 채워짐
│                  ↑              │     bg-hk-error/10
│   (나는 학생입니다)              │     border-hk-error
│                                 │     + shake 애니메이션
│  ┌──── 피드백 패널 ────────────┐│
│  │                             ││
│  │  ❌ 아쉬워요!               ││
│  │                             ││
│  │  정답:  は                  ││
│  │                             ││
│  │  📝 は는 주제를 나타내는    ││  ← 해설은 정답/오답 모두 표시
│  │  조사예요. が는 주어를      ││
│  │  나타냅니다. 이 문장에서는  ││
│  │  주제 표시가 적절합니다.    ││
│  │                             ││
│  │  [다음 문제 →]              ││
│  └─────────────────────────────┘│
└─────────────────────────────────┘
```

### 인터랙션 흐름

```
문제 표시 (문장 fade-in y:20→0)
    │
    ├── 빈칸: border-dashed + 미약 pulse
    ├── 보기 칩: 순차 등장 (delay: i × 0.05s)
    │
    ▼
사용자 보기 칩 탭 (tap → scale 0.95)
    │
    ├── 빈칸에 선택 텍스트 scale-in 채움
    ├── 0.3s 판정 대기
    │
    ▼
판정
    │
    ├── 정답:
    │   ├── 빈칸 bg-hk-success/10 + pulse
    │   ├── 칩 border-hk-success + pulse
    │   └── 나머지 칩 opacity-40
    │
    ├── 오답:
    │   ├── 빈칸 bg-hk-error/10 + shake
    │   ├── 칩 border-hk-error + shake
    │   └── 정답 칩 border-hk-success (표시만)
    │
    ▼
피드백 패널 슬라이드업
    │
    ├── 해설 텍스트 표시
    ├── [다음 문제 →] / [결과 보기]
    │
    ▼
다음 문제 또는 퀴즈 완료
```

### 보기 칩 스타일

| 상태 | 스타일 |
|------|--------|
| 기본 | `border-border bg-card hover:bg-accent` |
| 선택 | `border-primary bg-primary/5` |
| 정답 | `border-hk-success bg-hk-success/10 text-hk-success` + pulse |
| 오답 선택 | `border-hk-error bg-hk-error/10 text-hk-error` + shake |
| 미선택 (판정 후) | `opacity-40` |

### Props 인터페이스

```typescript
type ClozeQuestion = {
  questionId: string;
  sentence: string;          // "{blank}" 마커 포함 문장
  translation: string;       // 한국어 번역
  options: { id: string; text: string }[];
  correctOptionId: string;
  explanation: string;       // 문법 해설
  grammarPoint?: string;     // 문법 포인트 라벨
};

type ClozeQuizProps = {
  questions: ClozeQuestion[];
  sessionId: string;
  onComplete: (result: QuizResult) => void;
};
```

---

## 2. 어순 배열 (SentenceArrangeQuiz)

### 파일 위치

- **컴포넌트**: `apps/web/src/components/features/quiz/sentence-arrange.tsx`
- **사용처**: `/study/quiz?mode=arrange` (JLPT 문법)
- **훅**: `hooks/use-quiz.ts` 확장

### 와이어프레임 — 문제 표시

```
┌─────────────────────────────────┐
│  ← 뒤로   N5 문법 퀴즈   2/10  │
│  ████████░░░░░░░░░░░░░░░░░░░░  │
├─────────────────────────────────┤
│                                 │
│  "나는 학생입니다"를             │  ← 한국어 문장
│  일본어로 만드세요              │    text-lg font-bold
│                                 │
│  ┌─── 정답 영역 ─────────────┐ │
│  │                            │ │  ← drop zone
│  │  [    ] [    ] [    ] [   ]│ │    min-h-[56px]
│  │                            │ │    bg-secondary/30 rounded-2xl
│  │  비어있는 슬롯              │ │    border-2 border-dashed
│  │                            │ │    border-muted-foreground/20
│  └────────────────────────────┘ │
│                                 │
│  ┌─── 보기 카드 영역 ─────────┐ │
│  │                            │ │  ← 카드 풀 (셔플된 순서)
│  │  ┌──────┐ ┌──┐ ┌──────┐  │ │    flex-wrap gap-2 justify-center
│  │  │ です  │ │は│ │がくせい│  │ │
│  │  └──────┘ └──┘ └──────┘  │ │    각 카드:
│  │        ┌────┐             │ │    rounded-xl border-2
│  │        │わたし│             │ │    px-4 py-3
│  │        └────┘             │ │    font-jp font-medium
│  │                            │ │    bg-card shadow-sm
│  └────────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
```

### 카드 배치 중 상태

```
┌─────────────────────────────────┐
│                                 │
│  "나는 학생입니다"를             │
│  일본어로 만드세요              │
│                                 │
│  ┌─── 정답 영역 ─────────────┐ │
│  │                            │ │
│  │  ┌────┐ ┌──┐ [    ] [   ] │ │  ← 배치된 카드 + 빈 슬롯
│  │  │わたし│ │は│              │ │
│  │  └────┘ └──┘              │ │    배치된 카드:
│  │                            │ │    bg-primary/5 border-primary/50
│  └────────────────────────────┘ │    탭하면 다시 카드 풀로 이동
│                                 │
│  ┌─── 보기 카드 영역 ─────────┐ │
│  │                            │ │
│  │  ┌──────┐     ┌──────┐    │ │  ← 사용한 카드는 사라짐
│  │  │ です  │     │がくせい│    │ │    (AnimatePresence exit)
│  │  └──────┘     └──────┘    │ │
│  │                            │ │
│  └────────────────────────────┘ │
│                                 │
│           [확인하기]            │  ← 모든 슬롯 채워지면 활성화
│                                 │    비활성: opacity-50
└─────────────────────────────────┘
```

### 토큰 카드 컬러 매핑 (품사별)

```
  명사      조사      동사      형용사    부사      접미사
┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐
│がくせい│  │  は  │  │ 食べ │  │ 美しい│  │ とても│  │ ます │
│       │  │      │  │      │  │       │  │       │  │      │
│ 파란  │  │ 보라 │  │ 초록 │  │ 주황  │  │ 민트  │  │ 회색 │
└──────┘  └──────┘  └──────┘  └──────┘  └──────┘  └──────┘

색상 토큰 (좌측 세로 바):
  noun:      bg-hk-blue         (border-l-4 border-hk-blue)
  particle:  bg-violet-500      (border-l-4 border-violet-500)
  verb:      bg-hk-success      (border-l-4 border-hk-success)
  adjective: bg-hk-yellow       (border-l-4 border-hk-yellow)
  adverb:    bg-teal-500        (border-l-4 border-teal-500)
  suffix:    bg-muted-foreground (border-l-4 border-muted-foreground)
  copula:    bg-muted-foreground (border-l-4 border-muted-foreground)
```

### 정답/오답 판정 후 상태

```
정답:
┌─── 정답 영역 ─────────────┐
│                            │
│  ┌────┐ ┌──┐ ┌──────┐ ┌──┐│  ← 전체 영역 초록 하이라이트
│  │わたし│ │は│ │がくせい│ │です││    bg-hk-success/5
│  └────┘ └──┘ └──────┘ └──┘│    border-hk-success
│                            │    각 카드 순차 pulse
│  わたしはがくせいです ✓      │    (delay: i × 0.1s)
│                            │
└────────────────────────────┘

오답:
┌─── 정답 영역 ─────────────┐
│                            │
│  ┌──┐ ┌────┐ ┌──────┐ ┌──┐│  ← 전체 영역 빨강 하이라이트
│  │は│ │わたし│ │がくせい│ │です││    bg-hk-error/5
│  └──┘ └────┘ └──────┘ └──┘│    border-hk-error
│                            │    전체 shake
│  はわたしがくせいです ✗      │
│                            │
└────────────────────────────┘

피드백 패널 (오답 시):
┌─────────────────────────────┐
│  ❌ 아쉬워요!                │
│                              │
│  정답: わたしはがくせいです    │
│                              │
│  📝 일본어 어순은 주어+조사    │  ← 문법 해설
│  +술어 순서예요.              │
│  "わたし(나)は(는)            │
│   がくせい(학생)です(입니다)"  │
│                              │
│  [다음 문제 →]               │
└─────────────────────────────┘
```

### 인터랙션 흐름

```
문제 표시 (한국어 문장 fade-in)
    │
    ├── 정답 영역: 빈 슬롯 표시
    ├── 보기 카드: 순차 등장 (delay: i × 0.06s)
    │
    ▼
사용자 보기 카드 탭
    │
    ├── 카드가 보기 영역 → 정답 영역으로 이동
    │   (scale 0.95 → 슬롯 위치로 layoutId 전환)
    ├── 보기 영역에서 해당 카드 사라짐
    │
    ▼
정답 영역의 카드 탭 (되돌리기)
    │
    ├── 카드가 정답 영역 → 보기 영역으로 복귀
    ├── 해당 슬롯 다시 비워짐
    │
    ▼
모든 슬롯 채워짐 → [확인하기] 버튼 활성화
    │
    ▼
[확인하기] 클릭
    │
    ├── 정답:
    │   ├── 정답 영역 bg-hk-success/5 + border-hk-success
    │   ├── 각 카드 순차 pulse (delay: i × 0.1s)
    │   └── "わたしはがくせいです ✓" 텍스트 fade-in
    │
    ├── 오답:
    │   ├── 정답 영역 bg-hk-error/5 + border-hk-error
    │   ├── 전체 shake 애니메이션
    │   └── 잘못된 위치의 카드만 border-hk-error 강조
    │
    ▼
피드백 패널 슬라이드업 (기존 spring 패턴)
    │
    ├── 정답 어순 표시
    ├── 문법 해설
    └── [다음 문제 →]
```

### 레벨별 난이도 시각 차이

```
N5 초급 (beginner) — 의미 단위 묶음:
  ┌──────────┐  ┌──────────────┐
  │ わたしは  │  │ がくせいです  │    ← 2~3 카드, 큰 덩어리
  └──────────┘  └──────────────┘

N5 중급 (intermediate) — 명사/조사 분리:
  ┌────┐ ┌──┐ ┌──────┐ ┌────┐
  │わたし│ │は│ │がくせい│ │です│     ← 4~5 카드
  └────┘ └──┘ └──────┘ └────┘

N4 (advanced) — 동사/형용사 분리:
  ┌────┐ ┌──┐ ┌──┐ ┌──┐ ┌──────┐
  │きのう│ │は│ │あめ│ │が│ │ふりました│  ← 5~7 카드
  └────┘ └──┘ └──┘ └──┘ └──────┘
```

### Props 인터페이스

```typescript
type SentenceToken = {
  id: string;
  text: string;
  type: 'noun' | 'particle' | 'verb' | 'adjective' | 'copula' | 'adverb' | 'suffix';
  meaning: string;
  order: number;       // 정답 순서 (0-based)
};

type SentenceArrangeQuestion = {
  questionId: string;
  koreanSentence: string;
  tokens: SentenceToken[];
  explanation: string;
  grammarPoint?: string;
};

type SentenceArrangeQuizProps = {
  questions: SentenceArrangeQuestion[];
  sessionId: string;
  onComplete: (result: QuizResult) => void;
};
```

---

## 3. 글자 입력 (CharacterInput)

### 파일 위치

```
apps/web/src/components/features/quiz/
├── character-bank-input.tsx    # Stage 1: 글자 뱅크
├── kana-keyboard.tsx           # Stage 2: 인앱 키보드
└── romaji-input.tsx            # Stage 3: 로마자 입력
```

- **사용처**: `/study/quiz?mode=typing` (가나/단어 쓰기 연습)
- **자동 단계 전환**: SRS mastery 기반

### Stage 1: 글자 뱅크 (CharacterBankInput) — 초급

```
┌─────────────────────────────────┐
│  ← 뒤로   단어 쓰기   3/10     │
│  ████████░░░░░░░░░░░░░░░░░░░░  │
├─────────────────────────────────┤
│                                 │
│        "먹다"를 쓰세요          │  ← 안내 (text-lg font-bold)
│                                 │
│  ┌─── 입력 영역 ─────────────┐ │
│  │                            │ │
│  │    [た] [べ] [  ]          │ │  ← 채워진 칸 + 빈 칸
│  │                            │ │    각 칸: size-12
│  │           ⌫                │ │    rounded-lg border-2
│  └────────────────────────────┘ │    font-jp text-2xl
│                                 │    채워진: bg-primary/10
│                                 │           border-primary
│  ┌─── 글자 뱅크 ──────────────┐ │    빈: border-dashed
│  │                            │ │        border-muted-foreground/30
│  │  ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐│ │
│  │  │べ│ │た│ │る│ │か│ │め││ │  ← 정답 글자 + 오답 글자
│  │  └──┘ └──┘ └──┘ └──┘ └──┘│ │    flex-wrap gap-2
│  │                            │ │    각 칸: size-11
│  └────────────────────────────┘ │    rounded-lg border-2
│                                 │    bg-card font-jp text-xl
│                                 │
└─────────────────────────────────┘

탭 순서: た → べ → る
결과:    たべる ✓

입력 칸 피드백:
  글자 배치 시: scale 0→1 (0.15s) + 가벼운 바운스
  백스페이스: scale 1→0 (0.1s) exit

글자 뱅크 카드 상태:
  사용됨:  opacity-30, pointer-events-none
  미사용:  bg-card hover:bg-accent
  탭:      whileTap scale 0.9
```

### Stage 2: 인앱 가나 키보드 (KanaKeyboard) — 중급

```
┌─────────────────────────────────┐
│  ← 뒤로   단어 쓰기   3/10     │
│  ████████░░░░░░░░░░░░░░░░░░░░  │
├─────────────────────────────────┤
│                                 │
│        "먹다"를 쓰세요          │
│                                 │
│  ┌─── 입력 영역 ─────────────┐ │
│  │                            │ │
│  │    た べ _                 │ │  ← 인라인 입력 표시
│  │                            │ │    밑줄 커서 깜빡임
│  └────────────────────────────┘ │    font-jp text-3xl
│                                 │    text-center
│  ┌─── 가나 키보드 ────────────┐ │
│  │                            │ │  ← 50음도 기반 그리드
│  │  あ  か  さ  た  な        │ │    grid-cols-5 gap-1
│  │  い  き  し  ち  に        │ │    각 키: size-11
│  │  う  く  す  つ  ぬ        │ │    rounded-lg
│  │  え  け  せ  て  ね        │ │    font-jp text-base
│  │  お  こ  そ  と  の        │ │    bg-secondary hover:bg-accent
│  │                            │ │
│  │  は  ま  や  ら  わ        │ │
│  │  ひ  み      り            │ │    탭 → 입력 영역에 추가
│  │  ふ  む  ゆ  る  を        │ │    + 미약한 진동 피드백
│  │  へ  め      れ            │ │
│  │  ほ  も  よ  ろ  ん        │ │
│  │                            │ │
│  │  [゛ 탁음] [゜ 반탁음]     │ │  ← 토글 버튼
│  │  [小 소문자] [ー 장음]     │ │
│  │                            │ │
│  │       [⌫]    [확인]        │ │
│  │                            │ │
│  └────────────────────────────┘ │
└─────────────────────────────────┘

탁음 토글 시 키보드 변환:
  あ → が  / か → が  / さ → ざ  / た → だ  / は → ば
  (활성 시 토글 버튼: bg-primary text-primary-foreground)

키보드 키 인터랙션:
  탭:     whileTap scale 0.92, bg-accent
  입력됨: 입력 영역에 문자 추가 (scale-in 0.15s)
  진동:   navigator.vibrate?.(10)
```

### Stage 3: 로마자 입력 (RomajiInput) — 고급

```
┌─────────────────────────────────┐
│  ← 뒤로   단어 쓰기   3/10     │
│  ████████░░░░░░░░░░░░░░░░░░░░  │
├─────────────────────────────────┤
│                                 │
│        "먹다"를 쓰세요          │
│                                 │
│  ┌─── 변환 결과 ──────────────┐ │
│  │                            │ │
│  │        た べ               │ │  ← 변환된 가나 표시
│  │                            │ │    font-jp text-3xl
│  └────────────────────────────┘ │    text-center
│                                 │
│  ┌─── 로마자 입력창 ──────────┐ │
│  │                            │ │  ← 시스템 키보드 사용
│  │    tabe|                   │ │    text-xl font-mono
│  │                            │ │    border-2 border-primary
│  └────────────────────────────┘ │    rounded-xl px-4 py-3
│                                 │    autoFocus, autoCapitalize="off"
│                                 │
│  💡 "ru"를 입력해보세요         │  ← 힌트 (다음 글자)
│                                 │    text-sm text-muted-foreground
│                                 │    처음 2초만 표시 후 fade-out
│  ┌─── 변환 규칙 안내 ─────────┐ │
│  │                            │ │  ← 접기/펼치기 가능
│  │  ta→た  be→べ  ru→る      │ │    초급자 도움용
│  │  shi→し  chi→ち  tsu→つ   │ │    text-xs text-muted-foreground
│  │                            │ │
│  └────────────────────────────┘ │
│                                 │
│          [확인하기]             │  ← 입력 완료 후 활성화
│                                 │
└─────────────────────────────────┘

실시간 변환 인터랙션:
  1. 사용자 "t" 입력  → 대기 (미완성 로마자)
  2. 사용자 "a" 입력  → "た" 변환 + 변환 결과에 추가
     변환 순간: scale-in 0.2s + bg-primary/10 flash (0.3s)
  3. 사용자 "b" 입력  → 대기
  4. 사용자 "e" 입력  → "べ" 변환
  5. ...

변환 규칙 (헵번식):
  a→あ  ka→か  sa→さ  ta→た  na→な
  i→い  ki→き  shi→し chi→ち ni→に
  u→う  ku→く  su→す  tsu→つ nu→ぬ
  ...
  nn→ん  (n + 자음 or n + n)
```

### 3단계 공통 판정 피드백

```
정답 판정 (모든 Stage 공통):
┌─── 입력 영역 ─────────────┐
│                            │
│    た べ る  ✓             │  ← bg-hk-success/10
│                            │    border-hk-success
│    (각 글자 순차 pulse)     │    scale [1, 1.04, 1]
│                            │    delay: i × 0.1s
└────────────────────────────┘

오답 판정:
┌─── 입력 영역 ─────────────┐
│                            │
│    た で る  ✗             │  ← bg-hk-error/10
│         ↑                  │    border-hk-error
│    틀린 글자 빨강 강조      │    전체 shake
│                            │    틀린 위치: text-hk-error
└────────────────────────────┘
    │
    ▼
피드백 패널:
  정답: たべる (먹다)
  [다음 문제 →]
```

### Props 인터페이스

```typescript
type TypingQuestion = {
  questionId: string;
  prompt: string;           // "먹다" (한국어 뜻 또는 힌트)
  answer: string;           // "たべる" (정답 가나)
  answerRomaji: string;     // "taberu" (Stage 3용)
  stage: 1 | 2 | 3;        // 입력 단계
  hint?: string;            // 추가 힌트
  distractors?: string[];   // Stage 1 오답 글자들
};

type CharacterInputProps = {
  questions: TypingQuestion[];
  sessionId: string;
  onComplete: (result: QuizResult) => void;
};
```

---

## 4. 합성 퀴즈 세션 래퍼 (QuizSession)

### 파일 위치

- **컴포넌트**: `apps/web/src/components/features/quiz/quiz-session.tsx`
- **역할**: 퀴즈 타입에 따라 적절한 Body 컴포넌트를 갈아 끼우는 래퍼

### 아키텍처 개요

```
<QuizSession>
├── <Quiz.Header>           ← 공용: 뒤로 가기, 타이틀, 카운터
├── <Quiz.Progress>         ← 공용: 프로그레스 바
├── <Quiz.Body>             ← 퀴즈 타입별 교체
│   ├── type="multiple_choice" → 4지선다
│   ├── type="matching"        → 매칭 페어
│   ├── type="cloze"           → 빈칸 채우기
│   ├── type="arrange"         → 어순 배열
│   └── type="typing"          → 글자 입력
├── <Quiz.Feedback>         ← 공용: 하단 슬라이드업 피드백 패널
└── <Quiz.Actions>          ← 공용: 다음 문제 / 결과 보기 버튼
```

### 와이어프레임

```
┌─────────────────────────────────┐
│  ← 뒤로   퀴즈 제목    n/N     │  ← Quiz.Header (공용)
│  ██████████░░░░░░░░░░░░░░░░░░  │  ← Quiz.Progress (공용)
├─────────────────────────────────┤
│                                 │
│                                 │
│     ┌───────────────────┐      │
│     │                   │      │  ← Quiz.Body (타입별 교체)
│     │   퀴즈 타입별      │      │
│     │   컴포넌트가       │      │     이 영역만 타입에 따라
│     │   여기에 렌더링     │      │     다른 컴포넌트가 들어감
│     │                   │      │
│     └───────────────────┘      │
│                                 │
│                                 │
│  ┌──── 피드백 패널 ────────────┐│  ← Quiz.Feedback (공용)
│  │  ✅/❌ + 해설 + 부가 기능  ││
│  │  [다음 문제 →]              ││  ← Quiz.Actions (공용)
│  └─────────────────────────────┘│
└─────────────────────────────────┘
```

### 공유 상태 관리

```typescript
// 모든 퀴즈 타입이 공유하는 세션 상태
type QuizSessionState = {
  sessionId: string;
  questions: unknown[];              // 타입별 질문 배열
  currentIndex: number;
  answerState: 'idle' | 'correct' | 'incorrect';
  results: { questionId: string; isCorrect: boolean }[];
};

// 타입별 Body가 호출하는 콜백
type QuizBodyCallbacks = {
  onAnswer: (questionId: string, isCorrect: boolean) => void;
  onNext: () => void;
};
```

### 공용 컴포넌트 이점

| 영역 | 중복 제거 효과 |
|------|---------------|
| Header | 뒤로 가기 + 이탈 경고 로직 1곳에서 관리 |
| Progress | 프로그레스 바 애니메이션 통일 |
| Feedback | 슬라이드업 패널 + 해설 + 단어장 저장 통일 |
| Timer | 문제당 소요 시간 추적 통일 |
| BeforeUnload | 이탈 경고 1곳에서 관리 |
| 서버 통신 | answer/complete mutation 호출 통일 |

---

## 5. 퀴즈 결과 화면 개편

### 파일 위치

- **페이지**: `apps/web/src/app/(app)/study/result/page.tsx` (기존 수정)

### 현재 → 개편 비교

```
현재:                              개편:
┌──────────────┐                  ┌──────────────┐
│  점수 원형    │                  │  점수 원형    │  ← 유지
│  XP 바       │                  │  XP 바       │  ← 유지
│              │                  │              │
│  틀린 단어    │                  │  ▼ 틀린 단어  │  ← 아코디언으로 변경
│  (단순 나열)  │                  │    예문+해설  │     + 예문/해설 추가
│              │                  │              │
│  [홈] [다시]  │                  │  📌 추천 학습 │  ← NEW: SRS 기반 CTA
│              │                  │  [홈] [다시]  │
└──────────────┘                  └──────────────┘
```

### 개편 와이어프레임 — 오답 아코디언 섹션

```
┌─────────────────────────────────┐
│                                 │
│  ▼ 틀린 단어 2개                │  ← 탭하면 펼침/접음
│                                 │    ChevronDown 아이콘 회전
│  ┌─── 오답 카드 ──────────────┐ │
│  │                            │ │
│  │  食べる  たべる             │ │  ← 단어 + 읽기
│  │  뜻: 먹다                  │ │     font-jp text-lg bold
│  │                            │ │
│  │  📝 예문                   │ │  ← 예문 (bg-secondary rounded-lg p-3)
│  │  朝ごはんを食べる。         │ │     font-jp text-sm
│  │  아침밥을 먹다.             │ │     한국어 번역 병기
│  │                            │ │
│  │  💡 해설                   │ │  ← 문법/단어 해설
│  │  五段動詞(5단 동사).        │ │     text-xs text-muted-foreground
│  │  て형: 食べて               │ │
│  │                            │ │
│  │  [📕 단어장에 추가]         │ │  ← 개별 저장 버튼
│  │                            │ │
│  └────────────────────────────┘ │
│  ┌─── 오답 카드 ──────────────┐ │
│  │  ...                       │ │  ← 다음 오답 카드
│  └────────────────────────────┘ │
│                                 │
│  [📕 틀린 단어 모두 단어장에 저장]│  ← 일괄 저장 (기존 유지)
│                                 │
└─────────────────────────────────┘
```

### 추천 학습 CTA 섹션 (NEW)

```
┌─────────────────────────────────┐
│                                 │
│  📌 다음에 이걸 해보세요         │  ← section title
│                                 │
│  ┌────────────────────────────┐ │
│  │  🔄 잊어버리기 쉬운 단어     │ │  ← SRS 기반 추천
│  │  복습할 단어 5개             │ │    복습이 필요한 항목 수
│  │                             │ │
│  │  [바로 시작 →]              │ │    rounded-2xl
│  └────────────────────────────┘ │    border-primary/30
│                                 │    bg-primary/5
│  ┌────────────────────────────┐ │
│  │  📝 이번에 틀린 단어 복습    │ │  ← 오답 복습
│  │  {wrongCount}개 단어         │ │
│  │                             │ │    → ?mode=review로 이동
│  │  [오답 복습 →]              │ │
│  └────────────────────────────┘ │
│                                 │
│  ┌──────────┐ ┌──────────────┐ │
│  │ 한 번 더  │ │   홈으로     │ │  ← 기존 액션 버튼
│  │  도전     │ │              │ │
│  └──────────┘ └──────────────┘ │
│                                 │
└─────────────────────────────────┘
```

### 아코디언 애니메이션

```
접힌 상태:
  ▶ 틀린 단어 2개     ← ChevronDown rotate(0)

펼침 트리거 (탭):
  1. ChevronDown rotate(-180) (0.2s)
  2. height: 0 → auto (AnimatePresence)
  3. 카드 순차 등장 (delay: i × 0.08s, y: 10→0)

접힘 트리거 (재탭):
  1. ChevronDown rotate(0) (0.2s)
  2. height: auto → 0 + opacity fade-out
```

---

## 6. 학습 메인 페이지 개편

### 파일 위치

- **페이지**: `apps/web/src/app/(app)/study/page.tsx` (기존 수정)

### 현재 → 개편 비교

```
현재:                              개편:
┌──────────────┐                  ┌──────────────┐
│ 이어풀기 배너 │                  │ 이어풀기 배너 │  ← 유지
│ 가나 진도     │                  │ 가나 진도     │  ← 유지
│              │                  │              │
│ JLPT 학습    │                  │ [추천|자율] 탭│  ← NEW: 2탭 전환
│  레벨 선택   │                  │              │
│  유형 탭     │                  │  추천 탭:     │
│  스터디 카드  │                  │   복습 CTA    │
│  (4지선다/   │                  │   새 단어 CTA │
│   매칭 토글) │                  │              │
│              │                  │  자율 탭:     │
│ 내 학습 데이터│                  │   레벨+유형   │
│              │                  │   퀴즈 모드   │
│              │                  │   선택 그리드  │
│              │                  │              │
│              │                  │ 내 학습 데이터│  ← 유지
└──────────────┘                  └──────────────┘
```

### 개편 와이어프레임 — 추천 탭 (기본)

```
┌─────────────────────────────────┐
│  이어풀기 배너 (조건부)          │  ← 기존 유지
│  가나 진도 배너 (조건부)         │  ← 기존 유지
├─────────────────────────────────┤
│                                 │
│  ┌───────────┬───────────┐     │  ← 탭 전환
│  │ 🔥 추천   │ 📚 자율    │     │    bg-secondary rounded-2xl p-1
│  │ (활성)    │            │     │    활성: bg-card shadow-sm
│  └───────────┴───────────┘     │
│                                 │
│  ┌────────────────────────────┐ │
│  │  🔄 복습할 단어              │ │  ← SRS 기반 추천 카드
│  │                             │ │    가장 눈에 띄는 CTA
│  │  오늘 복습이 필요한          │ │    rounded-3xl
│  │  단어 12개가 있어요          │ │    border-primary/30
│  │                             │ │    bg-gradient-to-r
│  │  마지막 복습: 2일 전          │ │    from-primary/5 to-primary/10
│  │                             │ │
│  │  [지금 복습하기 →]           │ │    Button h-12
│  └────────────────────────────┘ │
│                                 │
│  ┌────────────────────────────┐ │
│  │  📖 새로운 N5 단어           │ │  ← 새 학습 카드
│  │                             │ │    rounded-3xl border
│  │  아직 안 본 단어 48개         │ │
│  │                             │ │
│  │  [학습 시작 →]              │ │
│  └────────────────────────────┘ │
│                                 │
│  ┌────────────────────────────┐ │
│  │  📝 오답 노트               │ │  ← 오답 복습 카드
│  │  최근 틀린 단어 8개          │ │    (오답이 있을 때만 표시)
│  │                             │ │
│  │  [오답 복습 →]              │ │
│  └────────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
```

### 개편 와이어프레임 — 자율 탭

```
┌─────────────────────────────────┐
│                                 │
│  ┌───────────┬───────────┐     │
│  │ 🔥 추천   │ 📚 자율    │     │
│  │            │ (활성)    │     │
│  └───────────┴───────────┘     │
│                                 │
│  JLPT 학습                      │  ← section title
│                                 │
│  [N5] [N4] [N3] [N2] [N1]      │  ← 레벨 선택 (기존 유지)
│                                 │
│  [단어 | 문법 | 한자 | 청해]     │  ← 유형 탭 (기존 유지)
│                                 │
│  ┌────────────────────────────┐ │
│  │  N5 단어 학습               │ │
│  │  150개 단어 · 진행률 32%    │ │
│  │                             │ │
│  │  ┌─── 퀴즈 모드 ─────────┐ │ │
│  │  │                        │ │ │  ← 퀴즈 유형 선택 그리드
│  │  │ ┌────────┐ ┌────────┐ │ │ │    grid-cols-2 gap-2
│  │  │ │ 📝     │ │ 🔗     │ │ │ │
│  │  │ │ 4지선다 │ │ 매칭   │ │ │ │    각 카드:
│  │  │ │ (활성) │ │        │ │ │ │    rounded-xl border-2 p-3
│  │  │ └────────┘ └────────┘ │ │ │    아이콘 + 라벨
│  │  │ ┌────────┐ ┌────────┐ │ │ │
│  │  │ │ 📋     │ │ 🧩     │ │ │ │    활성: border-primary
│  │  │ │ 빈칸   │ │ 어순   │ │ │ │           bg-primary/10
│  │  │ │ 채우기 │ │ 배열   │ │ │ │
│  │  │ └────────┘ └────────┘ │ │ │    비활성 (준비 중):
│  │  │ ┌────────┐ ┌────────┐ │ │ │    opacity-40
│  │  │ │ ⌨️     │ │ 🔄     │ │ │ │    Badge "준비 중"
│  │  │ │ 글자   │ │ 오답   │ │ │ │
│  │  │ │ 입력   │ │ 복습   │ │ │ │
│  │  │ └────────┘ └────────┘ │ │ │
│  │  └────────────────────────┘ │ │
│  │                             │ │
│  │  [10문제 시작하기 🌸]        │ │  ← 기존 시작 버튼
│  └────────────────────────────┘ │
│                                 │
│  내 학습 데이터                  │  ← 기존 유지
│  ...                            │
└─────────────────────────────────┘
```

### 퀴즈 모드 카드 상세

```
활성 카드:
┌─────────────────┐
│  📝              │  ← 아이콘 (size-5)
│                  │
│  4지선다          │  ← 라벨 (text-sm font-medium)
│  뜻 맞추기        │  ← 설명 (text-xs text-muted-foreground)
│                  │
│  border-primary   │
│  bg-primary/10    │
└─────────────────┘

비활성 카드 (준비 중):
┌─────────────────┐
│  ⌨️   [준비 중]  │  ← Badge variant="outline"
│                  │     text-[10px]
│  글자 입력        │
│  직접 써보기      │
│                  │
│  opacity-40       │
│  pointer-events-  │
│  none             │
└─────────────────┘
```

### 모드 → 라우트 매핑

| 모드 | query param | 컴포넌트 |
|------|-------------|----------|
| 4지선다 | `(기본, mode 없음)` | 기존 QuizContent |
| 매칭 | `?mode=matching` | MatchingPairQuiz |
| 빈칸 채우기 | `?mode=cloze` | ClozeQuiz |
| 어순 배열 | `?mode=arrange` | SentenceArrangeQuiz |
| 글자 입력 | `?mode=typing` | CharacterInput |
| 오답 복습 | `?mode=review` | 기존 QuizContent (오답만) |

---

## 7. 마이크로 인터랙션 고도화

### 전체 퀴즈 공통 적용

기존 시각적 애니메이션에 **감각 피드백 레이어**를 추가하여 타격감 극대화.

#### 햅틱 피드백 (Web Vibration API)

```
적용 위치        진동 패턴                    조건

카드/칩 탭       navigator.vibrate(10)        모든 선택 인터랙션
정답 확인        navigator.vibrate(50)        정답 판정 시
오답 확인        navigator.vibrate([30,20,30]) 오답 판정 시 (짧은 더블 진동)
매칭 성공        navigator.vibrate(50)        MatchingPairQuiz 정답 매칭
퀴즈 완료        navigator.vibrate(100)       모든 문제 완료 시
레벨 업          navigator.vibrate([50,30,50,30,100]) 축하 진동

구현: lib/haptic.ts
  export function haptic(type: 'tap' | 'success' | 'error' | 'complete' | 'celebrate') {
    if (!navigator.vibrate) return;
    const patterns = { tap: 10, success: 50, error: [30,20,30], ... };
    navigator.vibrate(patterns[type]);
  }
```

#### 사운드 이펙트

```
이벤트           효과음              볼륨    파일

카드 선택        "틱" (click)        0.3     /sounds/tap.mp3
정답             "띵동" (ding)       0.5     /sounds/correct.mp3
오답             "띡" (buzz)         0.4     /sounds/wrong.mp3
매칭 성공        "팝" (pop)          0.4     /sounds/match.mp3
퀴즈 완료        "팡파레" (fanfare)  0.6     /sounds/complete.mp3
레벨 업          "축하" (celebrate)  0.7     /sounds/levelup.mp3

구현: lib/sound.ts
  const audioCache = new Map<string, HTMLAudioElement>();
  export function playSound(name: SoundName) {
    if (!userPreferences.soundEnabled) return;
    // Audio pool 패턴으로 중복 재생 지원
  }

설정: /my (마이페이지) → 사운드 ON/OFF 토글
```

#### 키보드 단축키

```
키               동작                    적용 범위

1, 2, 3, 4      보기 선택 (4지선다)     JLPT 퀴즈, 빈칸 채우기
Enter / Space    확인 / 다음 문제        모든 퀴즈
Backspace        되돌리기               어순 배열, 글자 뱅크
Escape           나가기 확인 다이얼로그   모든 퀴즈

구현: useQuizKeyboard(options) 커스텀 훅
  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) { ... }
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [dependencies]);
```

---

## 8. 새로운 퀴즈 타입 요약표

### 전체 퀴즈 타입 (기존 + 신규)

| # | 타입 | 레이아웃 | 인지 유형 | Phase | 파일 |
|---|------|---------|----------|-------|------|
| 1 | JLPT 4지선다 | 세로 1열 | 인식 (Recognition) | 기존 | `study/quiz/page.tsx` |
| 2 | 가나 2×2 | 2×2 그리드 | 인식 | 기존 | `kana/kana-quiz.tsx` |
| 3 | 매칭 페어 (공용) | 좌우 2열 | 인식 | Phase 1 ✅ | `quiz/matching-pair.tsx` |
| 4 | 가나 페어 매칭 | 좌우 2열 | 인식 | 기존 | `kana/kana-pair-matching.tsx` |
| 5 | **빈칸 채우기** | 문장+칩 | **문맥 인식** | Phase 2 | `quiz/cloze-quiz.tsx` |
| 6 | **어순 배열** | 드래그/탭 | **생산 (Production)** | Phase 3 | `quiz/sentence-arrange.tsx` |
| 7 | **글자 뱅크** | 글자 선택 | **생산** | Phase 4 | `quiz/character-bank-input.tsx` |
| 8 | **가나 키보드** | 커스텀 KB | **생산** | Phase 4 | `quiz/kana-keyboard.tsx` |
| 9 | **로마자 입력** | 텍스트 입력 | **생산** | Phase 4 | `quiz/romaji-input.tsx` |

### 학습 깊이 피라미드

```
                ┌─────────┐
                │ 생산    │  ← Phase 4: 글자 입력
                │ (쓰기)  │     직접 타이핑/선택하여 생산
                ├─────────┤
                │ 생산    │  ← Phase 3: 어순 배열
                │ (조립)  │     토큰을 조합하여 문장 생산
                ├─────────┤
              │ 문맥 인식  │  ← Phase 2: 빈칸 채우기
              │ (이해)    │     문장 속에서 맥락 파악
              ├───────────┤
            │   인식       │  ← Phase 1: 매칭 페어
            │ (매칭/연결)  │     좌우를 연결하여 인식 강화
            ├─────────────┤
          │     인식        │  ← 기존: 4지선다
          │   (선택/판단)   │     보기 중 정답 선택
          └─────────────────┘
```

### 구현 일정 (Phase별)

| Phase | 내용 | 신규 파일 | 수정 파일 |
|-------|------|----------|----------|
| Phase 1 ✅ | 매칭 페어 | `quiz/matching-pair.tsx` | `kana quiz page`, `study quiz page`, `study page` |
| Phase 2 | 빈칸 채우기 | `quiz/cloze-quiz.tsx` | `study quiz page`, `study page` |
| Phase 3 | 어순 배열 | `quiz/sentence-arrange.tsx` | `study quiz page`, `study page` |
| Phase 4 | 글자 입력 3종 | `quiz/character-bank-input.tsx`, `quiz/kana-keyboard.tsx`, `quiz/romaji-input.tsx` | `study quiz page`, `study page` |
| Phase 5 | FSRS + 추천 | `lib/fsrs.ts` | DB 마이그레이션, API routes |
| Phase 6 | 결과/메인 개편 | — | `study/result/page.tsx`, `study/page.tsx` |

### 공통 색상/애니메이션 토큰 (08-QUIZ-UI.md 확장)

| 상태 | 색상 토큰 | 애니메이션 | 적용 |
|------|----------|-----------|------|
| 정답 | `hk-success` | pulse `scale: [1, 1.04, 1]` 0.3s | 전체 |
| 오답 | `hk-error` | shake `x: [0,-8,8,-6,6,-3,3,0]` 0.4s | 전체 |
| 선택 | `primary` | whileTap `scale: 0.95~0.98` | 전체 |
| 빈칸 | `primary/40` | pulse (미약 깜빡임) | 빈칸 채우기 |
| 슬롯 (빈) | `muted-foreground/20` | border-dashed | 어순 배열 |
| 슬롯 (채움) | `primary/5` | scale-in 0.15s | 어순 배열, 글자 뱅크 |
| 카드 이동 | — | layoutId 전환 | 어순 배열 |
| 글자 변환 | `primary/10` | flash 0.3s | 로마자 입력 |

---

## 데이터 흐름 (통합)

```
학습 메인 (/study)
    │
    ├── 추천 탭: SRS 기반 추천 카드
    │   └── [지금 복습하기] → /study/quiz?mode=review
    │
    ├── 자율 탭: 레벨 + 유형 + 모드 선택
    │   └── [시작하기] → /study/quiz?type=X&level=X&count=X&mode=X
    │
    ▼
퀴즈 페이지 (/study/quiz)
    │
    ├── mode 파라미터에 따라 컴포넌트 분기
    │   ├── (없음)    → QuizContent (기존 4지선다)
    │   ├── matching  → MatchingPairQuiz
    │   ├── cloze     → ClozeQuiz
    │   ├── arrange   → SentenceArrangeQuiz
    │   ├── typing    → CharacterInput (stage별)
    │   └── review    → QuizContent (오답만)
    │
    ├── 매 문제 답변 → useAnswerQuestion mutation
    ├── 햅틱/사운드 피드백
    │
    ▼
퀴즈 완료 → useCompleteQuiz mutation
    │
    ├── showGameEvents (레벨업, 업적)
    │
    ▼
결과 페이지 (/study/result)
    │
    ├── 점수 + XP + 레벨 바 (기존)
    ├── 오답 아코디언 (예문 + 해설) (개편)
    ├── 추천 학습 CTA (NEW)
    └── 액션 버튼 (다시/홈)
```
