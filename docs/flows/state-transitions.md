# SRS / 레벨 / 진도 상태 전이

> **Canonical**: Mobile | **Source**: `srs-engine.md` (Frozen)

---

## 1. SRS 아이템 상태 머신

### 전체 상태 다이어그램

```mermaid
stateDiagram-v2
    [*] --> UNSEEN: 콘텐츠 존재

    UNSEEN --> PROVISIONAL: 퀴즈 첫 답변
    UNSEEN --> LEARNING: 레슨 완료 (PROVISIONAL 스킵)

    PROVISIONAL --> PROVISIONAL: 오답 (step 리셋)
    PROVISIONAL --> LEARNING: 2연속 정답

    LEARNING --> LEARNING: 오답 (step 리셋)
    LEARNING --> REVIEW: step ≥ 2 정답

    REVIEW --> REVIEW: 정답 (interval 증가)
    REVIEW --> MASTERED: interval ≥ 21일
    REVIEW --> RELEARNING: 오답

    MASTERED --> RELEARNING: 오답

    RELEARNING --> REVIEW: 정답
    RELEARNING --> RELEARNING: 오답 (리셋)
```

### 상태 설명

| 상태 | 의미 | 진입 조건 | 복습 간격 |
|------|------|----------|----------|
| **UNSEEN** | 아직 학습 안 함 | 콘텐츠 등록 시 | - |
| **PROVISIONAL** | 찍기 방지 단계 | 퀴즈 첫 답변 | [1, 3]일 |
| **LEARNING** | 학습 중 | 레슨 완료 / PROVISIONAL 2연속 정답 | [1, 3]일 |
| **REVIEW** | 정기 복습 | LEARNING step ≥ 2 정답 | interval × EF |
| **MASTERED** | 마스터 | interval ≥ 21일 | 장기 |
| **RELEARNING** | 재학습 | REVIEW/MASTERED에서 오답 | 1일 |

### PROVISIONAL 단계 상세

```mermaid
flowchart LR
    P0["PROVISIONAL<br/>step 0"] -->|정답| P1["PROVISIONAL<br/>step 1<br/>(1일 후 복습)"]
    P1 -->|정답| L["LEARNING<br/>(3일 후 복습)"]
    P0 -->|오답| P0
    P1 -->|오답| P0
```

- **목적**: 찍기(guessing) 방지 — 2번 연속 맞혀야 LEARNING 진입
- **필요 조건**: `PROVISIONAL_STEPS_REQUIRED = 2`
- **레슨 항목은 이 단계를 건너뜀** (큐레이팅된 콘텐츠이므로)

### SM-2 알고리즘 (REVIEW 단계)

```
정답:
  interval' = max(int(interval × ease_factor), 1)
  ease_factor' = ease_factor + 0.1

오답:
  interval' = 1
  ease_factor' = max(ease_factor - 0.2, 1.3)
  state → RELEARNING

MASTERED 조건:
  interval ≥ 21일 → 자동 승격
```

---

## 2. 유저 레벨 시스템

### 레벨 공식

```
level = floor(sqrt(totalXP / 100)) + 1
```

| 레벨 | 필요 XP | 누적 XP |
|------|---------|---------|
| 1 | 0 | 0 |
| 2 | 100 | 100 |
| 3 | 300 | 400 |
| 4 | 500 | 900 |
| 5 | 700 | 1,600 |
| 10 | 1,700 | 8,100 |
| 20 | 3,700 | 36,100 |

### XP 획득 경로

```mermaid
flowchart LR
    subgraph 퀴즈
        QC[정답당 XP]
    end
    subgraph 대화
        CC[대화 완료 XP]
    end
    subgraph 미션
        MC[미션 달성 XP]
    end

    QC --> XP[totalXP]
    CC --> XP
    MC --> XP
    XP --> Level["level = floor(sqrt(XP/100)) + 1"]
    Level --> Unlock[캐릭터 해금]
```

---

## 3. 스트릭 시스템

### 상태 전이

```mermaid
stateDiagram-v2
    [*] --> Active: 첫 학습

    Active --> Active: 같은 날 학습 (유지)
    Active --> Incremented: 다음 날 학습 (+1)
    Active --> Reset: 2일+ 미학습 (리셋→1)

    Incremented --> Active: 같은 날 추가 학습
    Incremented --> Incremented: 다음 날 학습 (+1)
    Incremented --> Reset: 2일+ 미학습

    Reset --> Active: 학습 재개 (1부터)
```

### 규칙
| 조건 | 동작 |
|------|------|
| `last_study_date == today` | streak 유지 (변경 없음) |
| `last_study_date == yesterday` | streak += 1, longest_streak 갱신 |
| `last_study_date < yesterday` | streak = 1 (리셋), longest_streak 보존 |

### 트리거
- 퀴즈 완료 (`POST /quiz/complete`)
- 대화 완료 (`POST /chat/end`, `POST /chat/live-feedback`)

---

## 4. 챕터/레슨 진도

### 잠금해제 시스템

```mermaid
flowchart TD
    C1["Ch.01 인사와 첫 만남"] --> C1L1[Lesson 1]
    C1 --> C1L2[Lesson 2]
    C1 --> C1L3[Lesson 3]

    C1L3 -->|Ch.01 완료| C2["Ch.02 물건과 사람 소개"]
    C2 --> C2L1[Lesson 4]
    C2 --> C2L2[Lesson 5]
    C2 --> C2L3[Lesson 6]

    C2L3 -->|Ch.02 완료| C3["Ch.03 ..."]
```

### 레슨 상태 전이

```mermaid
stateDiagram-v2
    [*] --> LOCKED: 선행 챕터 미완료
    LOCKED --> NOT_STARTED: 선행 챕터 완료
    NOT_STARTED --> IN_PROGRESS: POST /lessons/{id}/start
    IN_PROGRESS --> COMPLETED: POST /lessons/{id}/submit
    COMPLETED --> IN_PROGRESS: 다시 풀기
```

### 진행률 계산
- 챕터 진행률: `completedLessons / totalLessons`
- 파트 진행률: `completedChapters / totalChapters`
- N5 전체: 90 레슨, 18 챕터, 3 파트

---

## 5. 가나 스테이지 진도

```mermaid
flowchart TD
    H1["히라가나 기본<br/>(あ~ん)"] --> H2["히라가나 탁음<br/>(が~ぽ)"]
    H2 --> H3["히라가나 요음<br/>(きゃ~ぴょ)"]
    H3 --> HM["히라가나 마스터<br/>(46자 전체)"]

    K1["가타카나 기본<br/>(ア~ン)"] --> K2["가타카나 탁음<br/>(ガ~ポ)"]
    K2 --> K3["가타카나 요음<br/>(キャ~ピョ)"]
    K3 --> KM["가타카나 마스터<br/>(46자 전체)"]
```

### 스테이지 완료 조건
- 스테이지 퀴즈 통과 (정확도 기준)
- 완료 시 다음 스테이지 잠금해제
- 마스터 퀴즈: 전체 46자 대상, 별도 업적 부여

---

> **Web MVP Delta**: Web에서도 가나 스테이지는 동일. 레슨/챕터 진도는 Mobile 전용.
