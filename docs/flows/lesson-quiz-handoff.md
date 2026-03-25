# Lesson → SRS → Quiz → Gamification 연결

> **Canonical**: Mobile | **Source**: `srs-engine.md`, `lesson-flow-design.md` (Frozen)

---

## 전체 연결 다이어그램

```mermaid
flowchart TD
    subgraph Lesson["레슨 학습"]
        L1[레슨 시작] --> L2[6단계 진행]
        L2 --> L3["POST /lessons/{id}/submit"]
        L3 --> L4[채점 + SRS 등록]
    end

    subgraph SRS["SRS 엔진"]
        S1[UNSEEN 항목] --> S2{출처?}
        S2 -->|Lesson| S3["LEARNING (PROVISIONAL 스킵)"]
        S2 -->|Quiz 첫 답변| S4[PROVISIONAL]
        S4 -->|2연속 정답| S3
        S3 -->|step ≥ 2| S5[REVIEW]
        S5 -->|interval ≥ 21일| S6[MASTERED]
        S5 -->|오답| S7[RELEARNING]
        S7 -->|정답| S5
    end

    subgraph Quiz["퀴즈"]
        Q1[Smart Quiz 세션 빌드] --> Q2[due cards 우선]
        Q2 --> Q3[new cards 20% 이내]
        Q3 --> Q4[문제 풀이]
        Q4 --> Q5["POST /quiz/answer"]
        Q5 --> Q6[SRS 상태 업데이트]
        Q6 --> Q7["POST /quiz/complete"]
    end

    subgraph Gamification["게이미피케이션"]
        G1[XP 지급] --> G2[레벨 업데이트]
        G2 --> G3[스트릭 업데이트]
        G3 --> G4[업적 체크]
        G4 --> G5[캐릭터 해금]
        G5 --> G6[DailyProgress]
        G6 --> G7[데일리 미션 자동 완료]
    end

    L4 --> S1
    S3 --> Q1
    S5 --> Q1
    S7 --> Q1
    Q7 --> G1
```

---

## 1. Lesson → SRS 등록

### 레슨 완료 시 SRS 등록 규칙

```mermaid
sequenceDiagram
    participant User as 사용자
    participant App as 모바일 앱
    participant API as FastAPI
    participant SRS as SRS 엔진

    User->>App: 레슨 답안 제출
    App->>API: POST /lessons/{id}/submit
    API->>API: 답안 채점

    loop 각 문제별
        API->>SRS: process_answer(item, isCorrect)
        SRS->>SRS: SRS 상태 업데이트
        SRS->>SRS: review_event 로깅
    end

    API->>SRS: register_items_from_lesson()
    Note over SRS: UNSEEN → LEARNING (PROVISIONAL 스킵)
    Note over SRS: introduced_by = "LESSON"
    Note over SRS: 이미 등록된 항목은 스킵

    API-->>App: { scoreCorrect, srsItemsRegistered }
    App-->>User: 결과 + "N개 복습 예약됨"
```

### 핵심 규칙
- 레슨 항목은 **PROVISIONAL을 건너뛰고 바로 LEARNING**
- 이유: 레슨은 큐레이팅된 콘텐츠 → 찍기(guessing) 위험 없음
- `introduced_by = "LESSON"` 기록 (분석용)
- 이미 SRS에 등록된 항목은 중복 등록하지 않음

---

## 2. SRS → Quiz 세션 빌드

### Smart Quiz 세션 구성 알고리즘

`_calculate_smart_distribution()` + `/quiz/smart-start` 기반:

```mermaid
flowchart TD
    A["Smart Quiz 요청<br/>(POST /quiz/smart-start)"] --> B["_calculate_smart_distribution()"]
    B --> C["daily_goal 기반 비율 계산"]
    C --> D["New items: 최소 10%"]
    C --> E["Retry items: 오답/RELEARNING 우선"]
    C --> F["Review items: due cards 배분"]
    D --> G[세션 구성]
    E --> G
    F --> G
    G --> H[문제 생성 + 셔플]
    H --> I[세션 반환]
```

### 세션 구성 규칙
- **New items**: 최소 10% (학습 진행 보장)
- **Retry items**: 오답/RELEARNING 우선 배정
- **Review items**: due cards 비율 배분
- **daily_goal 기반**: 유저별 목표에 따라 분배 비율 조정

---

## 3. Quiz → SRS 업데이트

### 답변별 SRS 상태 전이

| 현재 상태 | 정답 | 오답 |
|----------|------|------|
| UNSEEN | → PROVISIONAL (step 0) | → PROVISIONAL (step 0) |
| PROVISIONAL (step 0) | → step 1 (1일 후 복습) | → step 0 리셋 (1일 후) |
| PROVISIONAL (step 1) | → LEARNING (3일 후) | → step 0 리셋 (1일 후) |
| LEARNING (step 0) | → step 1 (1일 후) | → step 0 리셋 (1일 후) |
| LEARNING (step 1) | → REVIEW (interval × EF일 후) | → step 0 리셋 (1일 후) |
| REVIEW | → interval 증가 (EF 적용) | → RELEARNING |
| MASTERED | (유지) | → RELEARNING |
| RELEARNING | → REVIEW | → RELEARNING (리셋) |

---

## 4. Quiz → Gamification

### XP 지급 체인

```mermaid
sequenceDiagram
    participant Quiz as 퀴즈 완료
    participant XP as XP 시스템
    participant Level as 레벨 시스템
    participant Streak as 스트릭
    participant Achievement as 업적
    participant Mission as 데일리 미션

    Quiz->>XP: correctCount × XP_PER_CORRECT
    XP->>Level: totalXP → level = floor(sqrt(XP/100)) + 1
    Level-->>Quiz: new_level vs old_level

    Quiz->>Streak: 날짜 계산
    Note over Streak: 같은 날=유지, 다음 날=+1, 2일+=리셋

    Quiz->>Achievement: 컨텍스트 전달
    Note over Achievement: quiz_count, streak, perfect, level, xp
    Achievement-->>Quiz: GameEvent[] (업적/레벨업/해금)

    Quiz->>Mission: DailyProgress 업데이트
    Note over Mission: 다음 /today 호출 시 자동 완료 체크
```

### 업적 트리거 조건

| 업적 | 조건 | 트리거 시점 |
|------|------|-----------|
| first_quiz | quiz_count ≥ 1 | 퀴즈 완료 |
| quiz_10/50/100 | quiz_count ≥ N | 퀴즈 완료 |
| perfect_quiz | is_perfect_quiz = true | 퀴즈 완료 (만점) |
| streak_3/7/30/100 | streak_count ≥ N | 퀴즈/대화 완료 |
| words_50/100 | total_words ≥ N | 퀴즈 완료 |
| level_5/10/20 | level ≥ N | 퀴즈/대화 완료 |
| xp_1000/5000/10000 | total_xp ≥ N | 퀴즈/대화 완료 |
| first_conversation | conversation_count ≥ 1 | 대화 완료 |
| kana_hiragana_complete | 히라가나 전체 마스터 | 가나 퀴즈 완료 |

### 데일리 미션 자동 완료

```
사용자가 퀴즈 완료
    ↓
DailyProgress 업데이트 (quizzes_completed++, words_studied++, ...)
    ↓
다음 번 GET /missions/today 호출 시
    ↓
각 미션의 target_count vs DailyProgress 비교
    ↓
달성 시 자동 XP 지급 + reward_claimed = true
```

---

## 5. 대화(Chat) → Gamification

대화/음성통화도 동일한 게이미피케이션 체인을 거침:

```
대화 완료 (POST /chat/end 또는 /chat/live-feedback)
    ↓
XP 지급: CONVERSATION_COMPLETE_XP (고정)
    ↓
스트릭 업데이트
    ↓
업적 체크 (conversation_count, streak, level)
    ↓
DailyProgress: xp_earned++, study_minutes++ (conversation_count는 별도 업데이트 없음)
```

> **Web MVP Delta**: Web에서도 퀴즈 완료 → SRS → 게이미피케이션 동일 체인 동작. 단, Smart Quiz와 레슨 기반 SRS 등록은 미지원.
