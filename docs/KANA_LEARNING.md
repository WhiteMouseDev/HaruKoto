# 가나(かな) 학습 모듈 기능 기획서

> **상태**: 구현 완료 (Status: Implemented)

## 1. 문제 정의

### 1.1 현재 상황

하루코토의 타겟 사용자는 **"일본어를 처음 배우는 완전 초보 ~ JLPT N1을 준비하는 고급 학습자"**(PRD 1.3)이다. 온보딩에서도 레벨 선택의 첫 번째 옵션이 "완전 초보 — 히라가나도 아직 몰라요"로 설정되어 있다.

그러나 현재 앱에는:

- **가나 학습 콘텐츠가 없다** — N5 단어 퀴즈가 최저 난이도이며, 이미 히라가나/가타카나를 읽을 수 있어야 풀 수 있다.
- **DB 스키마에 가나 관련 구조가 없다** — `QuizType` enum에 `KANA`가 없고, 가나 전용 테이블도 없다.
- **가나 데이터 파일이 없다** — `hiragana.json`, `katakana.json` 등 시드 데이터가 존재하지 않는다.
- **라우팅이 없다** — `/study/kana` 경로가 정의되어 있지 않다.

### 1.2 문제

온보딩에서 "히라가나도 아직 몰라요"를 선택한 사용자가 앱에 진입하면, **할 수 있는 학습이 사실상 없다.** N5 단어 퀴즈의 질문 자체가 히라가나/한자로 출제되므로, 가나를 모르는 사용자에게는 의미 없는 화면이 된다. 이는 **첫 세션 이탈(Day 0 Churn)의 직접적인 원인**이 된다.

### 1.3 목표

히라가나/가타카나를 전혀 모르는 사용자가 앱 내에서 **자연스럽게 가나를 익히고, 이후 N5 학습으로 이어지는 학습 경로**를 제공한다.

---

## 2. 학습 구조 설계

### 2.1 학습 경로 (Learning Path)

```
[완전 초보 사용자]
    │
    ▼
┌──────────────────┐
│  히라가나 학습     │  ← Phase 1: 기본 46자 + 탁음/반탁음/요음
│  (약 2~3주)       │
└──────┬───────────┘
       │ 히라가나 마스터 뱃지
       ▼
┌──────────────────┐
│  가타카나 학습     │  ← Phase 2: 기본 46자 + 탁음/반탁음/요음
│  (약 2~3주)       │
└──────┬───────────┘
       │ 가타카나 마스터 뱃지
       ▼
┌──────────────────┐
│  N5 단어/문법     │  ← 기존 JLPT 학습 시스템으로 자연 연결
│  학습 시작        │
└──────────────────┘
```

### 2.2 히라가나 학습 단계 (총 10단계)

| 단계 | 행        | 문자                        | 학습량 |
| ---- | --------- | --------------------------- | ------ |
| 1    | あ행      | あ い う え お              | 5자    |
| 2    | か행      | か き く け こ              | 5자    |
| 3    | さ행      | さ し す せ そ              | 5자    |
| 4    | た행      | た ち つ て と              | 5자    |
| 5    | な행      | な に ぬ ね の              | 5자    |
| 6    | は행      | は ひ ふ へ ほ              | 5자    |
| 7    | ま행      | ま み む め も              | 5자    |
| 8    | や행+ら행 | や ゆ よ + ら り る れ ろ   | 8자    |
| 9    | わ행+ん   | わ を ん                    | 3자    |
| 10   | 탁음/요음 | が ざ だ ば ぱ + きゃ etc. | 확장   |

가타카나도 동일한 구조로 진행 (アイウエオ ~ ン + 탁음/요음).

### 2.3 단계별 학습 플로우

```
각 단계 내부:

[소개] → [반복 학습] → [미니 퀴즈] → [복습] → [단계 완료]

1. 소개 (Learn)
   - 문자 카드: 가나 + 로마자 발음 + 획순 애니메이션
   - 한 글자씩 보여주며, 탭하면 발음 재생

2. 반복 학습 (Practice)
   - 플래시카드 형식으로 가나 ↔ 발음 반복
   - 스와이프: 알겠다 / 모르겠다

3. 미니 퀴즈 (Quiz)
   - 3~5문제, 이전 단계 문자 포함하여 누적 복습
   - 즉시 피드백 (정답/오답)

4. 복습 (Review)
   - 틀린 문자 다시 학습
   - 모두 맞출 때까지 반복

5. 단계 완료 (Complete)
   - XP 획득 + 진도 업데이트
   - 다음 단계 잠금 해제
```

---

## 3. 가나 차트 UI

### 3.1 50음도 인터랙티브 차트

메인 학습 화면에서 접근 가능한 50음도 차트. **학습한 문자는 컬러**, **미학습 문자는 회색 잠금** 표시.

```
┌─────────────────────────────────────────────┐
│  50음도 (ごじゅうおんず)                      │
├─────┬─────┬─────┬─────┬─────┬─────┬────────┤
│     │  a  │  i  │  u  │  e  │  o  │ 상태   │
├─────┼─────┼─────┼─────┼─────┼─────┼────────┤
│ ∅   │ あ  │ い  │ う  │ え  │ お  │ ✅완료 │
│ k   │ か  │ き  │ く  │ け  │ こ  │ ✅완료 │
│ s   │ さ  │ し  │ す  │ せ  │ そ  │ 🔓학습중│
│ t   │ た  │ ち  │ つ  │ て  │ と  │ 🔒잠금 │
│ n   │ な  │ に  │ ぬ  │ ね  │ の  │ 🔒잠금 │
│ h   │ は  │ ひ  │ ふ  │ へ  │ ほ  │ 🔒잠금 │
│ m   │ ま  │ み  │ む  │ め  │ も  │ 🔒잠금 │
│ y   │ や  │     │ ゆ  │     │ よ  │ 🔒잠금 │
│ r   │ ら  │ り  │ る  │ れ  │ ろ  │ 🔒잠금 │
│ w   │ わ  │     │     │     │ を  │ 🔒잠금 │
│ n   │ ん  │     │     │     │     │ 🔒잠금 │
└─────┴─────┴─────┴─────┴─────┴─────┴────────┘

[문자 탭 → 카드 팝업: 발음 + 획순 + 예시 단어]
```

### 3.2 차트 인터랙션

- **학습 완료 문자**: 탭하면 상세 카드 팝업 (발음 재생, 획순, 예시 단어)
- **현재 학습 중 행**: 강조 표시 + "학습하기" CTA
- **잠금 문자**: 반투명 처리, 탭하면 "이전 단계를 완료하세요" 안내
- **히라가나/가타카나 탭 전환**: 상단 탭으로 전환

### 3.3 문자 상세 카드

```
┌──────────────────────────┐
│         あ               │  ← 큰 글자
│        /a/               │  ← 로마자 발음
│                          │
│   [획순 애니메이션]       │  ← SVG 애니메이션
│                          │
│   🔊 발음 듣기           │  ← TTS 또는 오디오 파일
│                          │
│   예시: あめ (비)         │  ← 해당 문자로 시작하는 N5 단어
│   예시: あさ (아침)       │
│                          │
│   유사 가타카나: ア       │  ← 히라가나-가타카나 연결
└──────────────────────────┘
```

---

## 4. 퀴즈 유형

### 4.1 가나 인식 퀴즈 (Kana Recognition)

- **유형**: 가나 문자를 보여주고 올바른 발음(로마자) 선택
- **형식**: 4지선다
- **예시**: `し` → [sa, shi, su, se]

### 4.2 발음 매칭 퀴즈 (Sound Matching)

- **유형**: 로마자/한글 발음을 보여주고 올바른 가나 선택
- **형식**: 4지선다 (가나 문자 옵션)
- **예시**: "shi" → [さ, し, す, せ]

### 4.3 짝 맞추기 퀴즈 (Pair Matching)

- **유형**: 가나와 발음 짝 맞추기 (메모리 게임 스타일)
- **형식**: 3~4쌍, 드래그 또는 탭으로 연결
- **예시**: {か, き, く} ↔ {ka, ki, ku}

### 4.4 히라가나-가타카나 매칭 (Phase 2 이후)

- **유형**: 히라가나를 보여주고 대응하는 가타카나 선택 (또는 반대)
- **형식**: 4지선다
- **예시**: `か` → [カ, キ, ク, ケ]

### 4.5 쓰기 순서 퀴즈 (Stroke Order) — P2

- **유형**: 획순 번호를 올바른 순서로 탭
- **형식**: 분리된 획을 순서대로 선택
- 추후 필기 인식(Canvas) 연동 가능

### 4.6 퀴즈 난이도 조절

| 진행도      | 퀴즈 구성                         |
| ----------- | --------------------------------- |
| 단계 1~3    | 현재 단계 문자만 출제             |
| 단계 4~6    | 현재 + 이전 2단계 혼합            |
| 단계 7~10   | 전체 범위에서 랜덤 + 취약 문자 가중 |
| 마스터 퀴즈 | 46자 전체에서 출제, 90% 이상 통과  |

---

## 5. 게이미피케이션

### 5.1 XP 보상 체계

| 활동                   | XP  |
| ---------------------- | --- |
| 가나 단계 학습 완료    | 30  |
| 미니 퀴즈 전문 정답    | 20  |
| 미니 퀴즈 통과 (80%+)  | 10  |
| 마스터 퀴즈 통과       | 100 |
| 50음도 전체 완료       | 200 |
| 일일 가나 복습 완료    | 15  |

### 5.2 진도율 표시

- **50음도 차트**: 학습 완료 문자 수 / 전체 문자 수 (예: 15/46)
- **단계 진행 바**: 현재 단계 내 진행률
- **홈 화면 위젯**: "히라가나 32% 완료" 형태의 진도 카드

### 5.3 업적/뱃지 연동

| 업적                | 조건                       | 뱃지          |
| ------------------- | -------------------------- | ------------- |
| 첫 글자 배움        | 첫 가나 학습 완료          | 🌱 첫 싹     |
| あ행 마스터         | あ행 전체 학습             | ✨ あ행 클리어 |
| 히라가나 마스터     | 히라가나 46자 + 마스터퀴즈 | 🏆 ひらがな達人 |
| 가타카나 마스터     | 가타카나 46자 + 마스터퀴즈 | 🏆 カタカナ達人 |
| 가나 완전 정복      | 히라가나 + 가타카나 마스터 | 👑 かな王     |
| 가나 스트릭 7일     | 7일 연속 가나 학습         | 🔥 7일 연속   |

### 5.4 스트릭 연계

기존 스트릭 시스템과 통합. 가나 학습도 일일 학습 활동으로 인정하여 `DailyProgress`에 반영.

### 5.5 데일리 미션 연동

```
새 미션 타입:
- KANA_LEARN: "오늘 새로운 가나 5자 배우기"
- KANA_REVIEW: "가나 복습 퀴즈 1회 완료"
```

---

## 6. DB 스키마 변경안

### 6.1 Enum 추가

```prisma
// QuizType에 KANA 추가
enum QuizType {
  VOCABULARY
  GRAMMAR
  KANJI
  LISTENING
  KANA        // 새로 추가
}

// 가나 타입
enum KanaType {
  HIRAGANA
  KATAKANA
}
```

### 6.2 새 테이블: KanaCharacter (가나 문자 마스터 데이터)

```prisma
model KanaCharacter {
  id            String   @id @default(uuid()) @db.Uuid
  kanaType      KanaType @map("kana_type")
  character     String                          // あ, ア
  romaji        String                          // a
  pronunciation String                          // 한글 발음: 아
  row           String                          // 행: a, ka, sa...
  column        String                          // 열: a, i, u, e, o
  strokeCount   Int      @map("stroke_count")   // 획 수
  strokeOrder   Json?    @map("stroke_order")   // SVG 패스 데이터
  audioUrl      String?  @map("audio_url")      // 발음 오디오
  exampleWord   String?  @map("example_word")   // 예시 단어 (あめ)
  exampleReading String? @map("example_reading") // 예시 읽기 (아메)
  exampleMeaning String? @map("example_meaning") // 예시 뜻 (비)
  category      String   @default("basic")      // basic, dakuten, handakuten, combo
  order         Int      @default(0)
  createdAt     DateTime @default(now()) @map("created_at")

  userProgress UserKanaProgress[]

  @@unique([kanaType, character])
  @@index([kanaType, row])
  @@index([kanaType, category])
  @@map("kana_characters")
}
```

### 6.3 새 테이블: UserKanaProgress (사용자별 가나 학습 진도)

```prisma
model UserKanaProgress {
  id             String    @id @default(uuid()) @db.Uuid
  userId         String    @map("user_id") @db.Uuid
  kanaId         String    @map("kana_id") @db.Uuid
  correctCount   Int       @default(0) @map("correct_count")
  incorrectCount Int       @default(0) @map("incorrect_count")
  streak         Int       @default(0)
  mastered       Boolean   @default(false)
  lastReviewedAt DateTime? @map("last_reviewed_at")
  createdAt      DateTime  @default(now()) @map("created_at")
  updatedAt      DateTime  @updatedAt @map("updated_at")

  user User          @relation(fields: [userId], references: [id], onDelete: Cascade)
  kana KanaCharacter @relation(fields: [kanaId], references: [id], onDelete: Cascade)

  @@unique([userId, kanaId])
  @@index([userId, mastered])
  @@map("user_kana_progress")
}
```

### 6.4 새 테이블: KanaLearningStage (학습 단계 관리)

```prisma
model KanaLearningStage {
  id          String   @id @default(uuid()) @db.Uuid
  kanaType    KanaType @map("kana_type")
  stageNumber Int      @map("stage_number")   // 1~10
  title       String                           // "あ행"
  description String                           // "あ い う え お"
  characters  String[]                         // ["あ","い","う","え","お"]
  order       Int      @default(0)
  createdAt   DateTime @default(now()) @map("created_at")

  userStages UserKanaStage[]

  @@unique([kanaType, stageNumber])
  @@map("kana_learning_stages")
}
```

### 6.5 새 테이블: UserKanaStage (사용자별 단계 진행)

```prisma
model UserKanaStage {
  id          String    @id @default(uuid()) @db.Uuid
  userId      String    @map("user_id") @db.Uuid
  stageId     String    @map("stage_id") @db.Uuid
  isUnlocked  Boolean   @default(false) @map("is_unlocked")
  isCompleted Boolean   @default(false) @map("is_completed")
  quizScore   Int?      @map("quiz_score")    // 마지막 퀴즈 점수 (%)
  completedAt DateTime? @map("completed_at")
  createdAt   DateTime  @default(now()) @map("created_at")
  updatedAt   DateTime  @updatedAt @map("updated_at")

  user  User              @relation(fields: [userId], references: [id], onDelete: Cascade)
  stage KanaLearningStage @relation(fields: [stageId], references: [id], onDelete: Cascade)

  @@unique([userId, stageId])
  @@index([userId])
  @@map("user_kana_stages")
}
```

### 6.6 User 모델 확장

```prisma
model User {
  // ... 기존 필드

  kanaProgress UserKanaProgress[]   // 추가
  kanaStages   UserKanaStage[]      // 추가
}
```

### 6.7 기존 테이블 영향

- `QuizSession`: `quizType`에 `KANA` 추가되므로 가나 퀴즈 세션도 기록 가능
- `QuizAnswer`: 기존 구조 그대로 사용 가능
- `DailyProgress`: 기존 `quizzesCompleted` 필드에 가나 퀴즈도 합산
- `DailyMission`: `missionType`에 `KANA_LEARN`, `KANA_REVIEW` 추가

---

## 7. 라우팅 설계

### 7.1 페이지 구조

```
/study/kana                          ← 가나 학습 허브 (히라가나/가타카나 선택)
/study/kana/chart                    ← 50음도 인터랙티브 차트
/study/kana/[type]                   ← 히라가나 or 가타카나 단계 목록
                                       type: "hiragana" | "katakana"
/study/kana/[type]/stage/[number]    ← 특정 단계 학습 화면
                                       number: 1~10
/study/kana/[type]/quiz              ← 가나 퀴즈 (미니 퀴즈 / 마스터 퀴즈)
```

### 7.2 파일 구조

```
apps/web/src/app/(app)/study/kana/
├── page.tsx                         // 가나 학습 허브
├── chart/
│   └── page.tsx                     // 50음도 차트
├── [type]/
│   ├── page.tsx                     // 단계 목록 (히라가나 or 가타카나)
│   ├── stage/
│   │   └── [number]/
│   │       └── page.tsx             // 단계별 학습 화면
│   └── quiz/
│       └── page.tsx                 // 가나 퀴즈
└── layout.tsx                       // 공통 레이아웃 (뒤로가기 등)
```

### 7.3 API 라우트

```
apps/web/src/app/api/v1/kana/
├── characters/route.ts              // GET: 가나 문자 목록
├── stages/route.ts                  // GET: 학습 단계 목록 + 진행 상태
├── progress/route.ts                // GET/POST: 문자별 학습 진도
├── quiz/
│   ├── start/route.ts               // POST: 가나 퀴즈 시작
│   ├── answer/route.ts              // POST: 퀴즈 답안 제출
│   └── complete/route.ts            // POST: 퀴즈 완료
└── stage-complete/route.ts          // POST: 단계 완료 처리
```

### 7.4 네비게이션 연동

학습 허브(`/study`) 페이지에 가나 학습 진입점 추가:

```
JLPT 학습 페이지 상단에:
┌──────────────────────────────────┐
│ 🔤 히라가나/가타카나 배우기       │
│ 일본어의 첫 걸음!                │
│ [히라가나 32% · 가타카나 0%]     │
│                    → 학습하기     │
└──────────────────────────────────┘
```

---

## 8. 온보딩 연동

### 8.1 현재 온보딩 플로우

```
Step 1: 닉네임 입력
Step 2: 레벨 선택 (N5 완전 초보 / N4 기초 / N3 중급 / N2 고급)
Step 3: 목표 선택 (JLPT N5 / N4 / 여행 / 비즈니스 / 취미)
→ 완료 → /home
```

### 8.2 변경안: 레벨에 따른 자동 분기

```
Step 2에서 "완전 초보 (히라가나도 아직 몰라요)" 선택 시:

Step 3 완료 후 → /home이 아닌 /study/kana로 리다이렉트
               또는
               /home에서 "가나 학습 시작" 카드를 최상단에 표시
```

### 8.3 홈 화면 가나 학습 유도

`N5` 레벨 + 가나 미완료 사용자에게 홈 화면에 가나 학습 CTA 카드 표시:

```
┌──────────────────────────────────────────┐
│ 🌸 먼저 히라가나부터 배워볼까요?           │
│                                          │
│ 일본어의 기본! 히라가나 46자를 배우면      │
│ 단어 학습을 시작할 수 있어요.             │
│                                          │
│          [히라가나 배우기 →]              │
└──────────────────────────────────────────┘
```

### 8.4 학습 허브 연동

`/study` 페이지에서:

- 가나 미완료 시: 가나 학습 배너를 JLPT 학습 카드보다 **위에** 표시
- 가나 완료 후: 배너 숨기고, 50음도 차트 바로가기만 하단에 유지

---

## 9. 데이터 설계

### 9.1 시드 데이터 구조

`packages/database/seed/kana/hiragana.json` 예시:

```json
[
  {
    "kanaType": "HIRAGANA",
    "character": "あ",
    "romaji": "a",
    "pronunciation": "아",
    "row": "a",
    "column": "a",
    "strokeCount": 3,
    "category": "basic",
    "exampleWord": "あめ",
    "exampleReading": "아메",
    "exampleMeaning": "비",
    "order": 1
  },
  {
    "kanaType": "HIRAGANA",
    "character": "い",
    "romaji": "i",
    "pronunciation": "이",
    "row": "a",
    "column": "i",
    "strokeCount": 2,
    "category": "basic",
    "exampleWord": "いぬ",
    "exampleReading": "이누",
    "exampleMeaning": "개",
    "order": 2
  }
]
```

### 9.2 데이터 분류

| category   | 설명           | 히라가나 수 | 가타카나 수 |
| ---------- | -------------- | ----------- | ----------- |
| basic      | 기본 청음 46자 | 46          | 46          |
| dakuten    | 탁음 (゛)      | 20          | 20          |
| handakuten | 반탁음 (゜)    | 5           | 5           |
| combo      | 요음 (きゃ등)  | 33          | 33          |

---

## 10. 컴포넌트 설계

### 10.1 주요 컴포넌트

```
components/features/kana/
├── kana-chart.tsx               // 50음도 인터랙티브 차트
├── kana-character-card.tsx      // 문자 상세 카드 (팝업)
├── kana-stage-list.tsx          // 단계 목록
├── kana-stage-card.tsx          // 단계 카드 (잠금/진행중/완료)
├── kana-flashcard.tsx           // 플래시카드 학습
├── kana-quiz.tsx                // 가나 퀴즈 컴포넌트
├── kana-pair-matching.tsx       // 짝 맞추기 퀴즈
├── kana-progress-banner.tsx     // 홈/학습허브 진도 배너
├── kana-hub-header.tsx          // 가나 허브 헤더 (탭 전환)
└── stroke-order-viewer.tsx      // 획순 애니메이션 뷰어 (SVG)
```

### 10.2 Zustand 스토어

```typescript
// stores/kana.ts
type KanaStore = {
  selectedType: 'hiragana' | 'katakana';
  currentStage: number;
  setSelectedType: (type: 'hiragana' | 'katakana') => void;
  setCurrentStage: (stage: number) => void;
};
```

### 10.3 TanStack Query 훅

```typescript
// hooks/use-kana.ts
useKanaCharacters(type: KanaType)        // 문자 목록
useKanaStages(type: KanaType)            // 단계 목록 + 진도
useKanaProgress(type: KanaType)          // 사용자 진행 상태
useUpdateKanaProgress()                  // 진도 업데이트 mutation
useCompleteKanaStage()                   // 단계 완료 mutation
```

---

## 11. 우선순위 및 마일스톤

### P0 — MVP (Week 1~2)

| 항목                        | 설명                                |
| --------------------------- | ----------------------------------- |
| DB 스키마 마이그레이션      | KanaCharacter, UserKanaProgress 등  |
| 시드 데이터                 | 히라가나/가타카나 기본 46자 데이터  |
| 가나 학습 허브 UI           | `/study/kana` 메인 페이지           |
| 50음도 차트                 | 인터랙티브 차트 + 문자 상세 카드    |
| 단계별 학습 화면            | 플래시카드 기반 학습                |
| 가나 인식 퀴즈              | 4지선다 (가나→발음)                 |
| 발음 매칭 퀴즈              | 4지선다 (발음→가나)                 |
| 진도 추적                   | 사용자별 문자/단계 진행 저장        |
| 온보딩 연동                 | N5 초보 → 가나 학습 유도            |
| 학습 허브 연동              | `/study`에 가나 진입 배너 추가      |

### P1 — 개선 (Week 3~4)

| 항목                        | 설명                                |
| --------------------------- | ----------------------------------- |
| 탁음/반탁음/요음 데이터     | 확장 문자 시드 데이터               |
| 짝 맞추기 퀴즈              | 메모리 게임 스타일                  |
| 히라가나-가타카나 매칭      | 두 가나 간 대응 퀴즈               |
| 마스터 퀴즈                 | 46자 전체 종합 테스트               |
| XP/업적 연동                | 가나 전용 업적 + XP 보상            |
| 데일리 미션 연동            | KANA_LEARN, KANA_REVIEW 미션        |
| 홈 화면 CTA                 | 가나 미완료 시 학습 유도 카드       |

### P2 — 고도화 (추후)

| 항목                        | 설명                                |
| --------------------------- | ----------------------------------- |
| 획순 애니메이션             | SVG 기반 필기 순서 시각화           |
| 쓰기 퀴즈                   | Canvas 기반 필기 인식               |
| 발음 오디오                 | TTS 또는 네이티브 녹음 파일         |
| 간격 반복 학습              | SM-2 알고리즘 적용한 복습           |
| 오프라인 지원               | Service Worker 캐싱                 |

---

## 12. PRD 연동 사항

### 12.1 PRD 업데이트 필요

- **3.2 JLPT 학습 시스템**: 가나 학습을 JLPT 학습의 **전단계**로 명시
- **7.1 신규 사용자 온보딩**: 가나 학습 분기 플로우 추가
- **8. 페이지 구조**: `/study/kana` 하위 경로 추가
- **9. 로드맵**: Phase 1 (MVP)에 가나 학습 모듈 포함

### 12.2 기존 시스템과의 일관성

- 퀴즈 UI: 기존 `/study/quiz` 4지선다 UI 패턴 재활용
- XP 보상: 기존 `showGameEvents()` 이벤트 시스템 연동
- 진도 추적: 기존 `DailyProgress` 테이블에 합산
- 스트릭: 가나 학습도 일일 활동으로 인정
- 디자인: 벚꽃 핑크 테마 + 카드 기반 레이아웃 유지

---

## 13. 기술적 고려사항

### 13.1 성능

- 가나 데이터는 정적이므로 **ISR/SSG**로 페이지 빌드 가능
- 50음도 차트는 클라이언트 컴포넌트지만, 데이터는 서버에서 프리패치
- 획순 SVG는 lazy loading으로 필요 시에만 로드

### 13.2 접근성

- 모든 가나 문자에 `aria-label` (로마자 발음) 제공
- 키보드 네비게이션 지원 (차트에서 화살표 키로 이동)
- 색상만으로 상태를 구분하지 않음 (아이콘 + 텍스트 병용)

### 13.3 모바일 최적화

- 50음도 차트: 가로 스크롤 없이 5열 그리드로 표시
- 플래시카드: 스와이프 제스처 지원
- 큰 터치 타겟: 가나 문자 셀 최소 44x44px

---

## 14. 성공 지표

| 지표                     | 목표                              |
| ------------------------ | --------------------------------- |
| 가나 학습 시작율         | N5 초보 선택 사용자의 80% 이상    |
| 히라가나 완료율          | 시작한 사용자의 50% 이상 (2주 내) |
| 가나 → N5 전환율         | 히라가나 완료 사용자의 70% 이상   |
| Day 1 리텐션 (가나 유저) | 50% 이상                          |
| 평균 세션 학습 문자 수   | 5자 이상                          |
