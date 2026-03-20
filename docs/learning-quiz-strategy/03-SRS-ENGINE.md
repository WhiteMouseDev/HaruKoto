# SRS 엔진 설계

> 최종 수정: 2026-03-20
> 상태: 설계 확정 (일부 미결 사항 하단 참조)

---

## 1. 목적

**학습 트랙과 퀴즈 트랙을 연결하는 기억 유지 엔진**

- 학습 탭에서 배운 것 → SRS가 복습 스케줄링
- 퀴즈 탭에서 만난 것 → SRS가 등록 + 복습 스케줄링
- 두 경로 모두 같은 SRS 풀로 합류

---

## 2. 아이템 상태 머신

```
                         ┌─────────────────────┐
                         │                     │
                         ▼                     │
┌────────┐   ┌─────────────┐   ┌─────────┐   │   ┌─────────┐
│ UNSEEN │──▶│ PROVISIONAL │──▶│LEARNING │──▶┼──▶│ REVIEW  │
└────────┘   └─────────────┘   └─────────┘   │   └─────────┘
     │                              ▲         │       │   │
     │                              │         │       │   ▼
     │                              │         │   ┌─────────┐
     │                         ┌────────────┐ │   │MASTERED │
     │                         │ RELEARNING │─┘   └─────────┘
     │                         └────────────┘         │
     │                              ▲                 │
     │                              └─────────────────┘
     │
     └──────────────────────▶ LEARNING (학습 탭에서 직접)
```

### 상태 정의

| 상태 | 설명 | 진입 경로 |
|------|------|----------|
| UNSEEN | 아직 만난 적 없는 아이템 | 초기 상태 |
| PROVISIONAL | 퀴즈 탭에서 처음 만남 (찍기 가능성) | 퀴즈 탭 첫 응답 |
| LEARNING | 학습 중 (초기 간격 단계) | 레슨 완료 / PROVISIONAL 검증 통과 |
| REVIEW | 정상 복습 사이클 | LEARNING 단계 완료 |
| MASTERED | 장기 기억 정착 | REVIEW에서 안정도 기준 도달 |
| RELEARNING | 잊어버림, 재학습 필요 | REVIEW/MASTERED에서 오답 |

### 상태 전환 조건

| 전환 | 조건 |
|------|------|
| UNSEEN → PROVISIONAL | 퀴즈 탭에서 첫 응답 (정답/오답 무관) |
| UNSEEN → LEARNING | 학습 탭 레슨 완료 |
| PROVISIONAL → LEARNING | 1일 후 재확인 정답 (방향 반전) |
| PROVISIONAL → LEARNING | 1일 후 재확인 오답 (오답 루트로 재학습) |
| LEARNING → REVIEW | 초기 간격 단계 전부 통과 (1일 → 3일) |
| REVIEW → MASTERED | stability >= 45일, 최근 30일 recall >= 90% |
| REVIEW → RELEARNING | 복습 오답 |
| MASTERED → RELEARNING | 장기 복습에서 오답 (lapse) |
| MASTERED → REVIEW | FSRS 스케줄에 따른 장기 간격 복습 (45일→90일→180일→...) |
| RELEARNING → REVIEW | 재학습 단계 통과 |

---

## 3. PROVISIONAL 간격 체계 (찍기 방지)

### 핵심 원칙
- 같은 날 재출제 없음. 최소 단위는 1일.
- 방향 반전으로 진짜 아는지 검증 (JP→KR로 맞췄으면 KR→JP로)

### 정답 루트

```
첫 정답 (PROVISIONAL 등록)
  │
  ▼
1일 후: 재확인 (방향 반전)
  │
  ├── 정답 → LEARNING 승급, 3일 후 복습
  │            │
  │            ├── 정답 → FSRS 자동 스케줄링
  │            └── 오답 → 1일 후 다시
  │
  └── 오답 → LEARNING 등록, 1일 후 다시
```

### 오답 루트

```
첫 오답 (PROVISIONAL 등록, 정답 피드백 표시)
  │
  ▼
1일 후: 재출제
  │
  ├── 정답 → 정답 루트 합류 (3일 후 복습)
  └── 오답 → 1일 후 다시
```

### 요약

```
정답 루트: 1일 → 3일 → FSRS
오답 루트: 1일 → 정답 루트 합류
```

---

## 4. LEARNING 간격 단계

학습 탭에서 진입한 아이템 (레슨 완료 후):

```
Step 1: 1일 후 첫 복습
Step 2: 3일 후 두번째 복습
Step 3: FSRS 자동 스케줄링
```

- 레슨에서 확인 문제를 틀린 아이템: Step 1부터 (동일)
- 레슨에서 확인 문제를 맞힌 아이템: Step 1부터 (동일)
- 차이는 FSRS 초기 파라미터에서 반영 (틀린 아이템은 difficulty 높게)

---

## 5. SRS 알고리즘

### 현재: SM-2 → 목표: FSRS

| 항목 | SM-2 (현재) | FSRS (목표) |
|------|------------|------------|
| 파라미터 | ease_factor 고정 공식 | 19개 가중치 데이터 학습 |
| 예측 | 간격 기반 | 망각 확률 직접 추정 |
| 개인화 | 없음 | 리뷰 로그 기반 최적화 |

### 전환 전략

1. **Phase 1**: SM-2 유지 + review_events 로깅 시작
2. **Phase 2**: FSRS 기본 파라미터로 전환 (retention 목표: 0.90)
3. **Phase 3**: 로그 축적 후 카테고리별 파라미터 최적화

### FSRS 전환 시점

- PROVISIONAL 단계(1일 → 3일)를 통과한 후 FSRS로 넘김
- PROVISIONAL 로그는 FSRS 학습 데이터에서 제외 (노이즈 방지)
- LEARNING 이상 상태의 로그만 FSRS 파라미터 학습에 사용

### Rating 산출 (반응시간 기반)

```
정답 + 3초 이내:      rating = 4 (Easy)
정답 + 3~8초:         rating = 3 (Good)
정답 + 8초 초과:      rating = 2 (Hard)
오답:                 rating = 1 (Again)

PROVISIONAL 첫 정답:  rating = 2 (Hard) 고정 — 찍기 가능성 반영
```

- 유저에게 Easy/Hard 자기평가를 묻지 않음
- 앱이 반응시간으로 자동 판단

### 카테고리별 파라미터

```
단어: 독립 파라미터 (가장 많은 로그)
문법: 독립 파라미터 (기억 동학이 단어와 다름)
한자: 독립 파라미터 (읽기/의미 별도 추적)
리스닝: 글로벌 파라미터 공유 (초기 로그 부족)
```

- 로그 50k 미만: 글로벌 파라미터 가중 공유
- 로그 50k 이상: 완전 독립 파라미터

---

## 6. 세션 생성 알고리즘

### "오늘의 퀴즈" 20문항 구성

```
규칙:
  1. 복습 due가 있으면 우선 채움
  2. 나머지를 새 단어로 채움
  3. 새 단어는 항상 최소 20% 보장 (복습만 세션 방지)
  4. 복습 due가 0이면 새 단어 100%
```

### 의사코드

```pseudo
function build_quiz_session(user, tab, N=20):
    due = fetch_due_items(user, tab, now)
    new = fetch_new_candidates(user, tab)

    // 새 단어 최소 20% 보장
    min_new = max(4, round(N * 0.20))

    if len(due) == 0:
        // 복습할 게 없으면 새 단어 100%
        new_count = min(N, len(new), daily_new_remaining)
        due_count = 0
    else:
        due_count = min(len(due), N - min_new)
        new_count = min(N - due_count, len(new), daily_new_remaining)

    due_pick = priority_sort(due)[:due_count]
    new_pick = new[:new_count]

    return interleave(due_pick, new_pick)
```

### 복습 우선순위

```
priority = overdue_days * 1.2
         + (1 - recall_probability) * 1.0
         + lapse_count * 0.6
         + guess_risk * 0.4
```

### 신규 단어 일일 상한

```
daily_new_cap: 전체 16개 (탭당 최대 8개)
```

- 유저가 여러 세션을 돌려도 하루에 새 단어는 최대 16개
- 이를 넘으면 나머지는 복습으로 채움

---

## 7. 복습 스케줄링

### 일일 최대 복습량

```
daily_review_cap = clamp(60, 160, active_cards * 0.12 + 20)
```

- active_cards: LEARNING + REVIEW + MASTERED 상태의 총 아이템 수
- 최소 60개, 최대 160개

### 백로그(과부하) 처리

```
if due_count > daily_review_cap:
    critical = items where recall < 0.75 or overdue >= 3일
    → critical 우선 출제
    → 나머지는 +1~3일 랜덤 분산 재배치
    → 새 단어 비율은 최소 20% 유지
```

---

## 8. 난이도 조절

### 퀴즈 방향 전환 (JP→KR ↔ KR→JP)

```
시작: JP→KR 100%

KR→JP 오픈 조건:
  JP→KR 최근 3회 정확도 >= 85%
  stability >= 4일

숙련도별 비율:
  Tier 1 (stability < 7일):  JP→KR 70% / KR→JP 30%
  Tier 2 (7일 <= S < 30일):  JP→KR 50% / KR→JP 50%
  Tier 3 (S >= 30일):        JP→KR 35% / KR→JP 65%

KR→JP 2연속 오답 시: 한 단계 하향
```

### 오답 난이도: stability 기반 자동 파생

**핵심: 난이도와 rating은 독립. 추가 상태 관리 없음.**

```
난이도 = "어떤 오답을 보여줄까" (출제 시점, stability에서 파생)
rating = "얼마나 잘 맞췄나" (채점 시점, 반응시간 기반)
두 개는 서로 영향 안 줌.
```

#### 난이도 결정

```
function get_distractor_difficulty(item_state):
    s = item_state.stability
    recent_lapse = lapses > 0 and last_lapse < 14일

    if s < 7 or state == PROVISIONAL:
        return "easy"     // 의미가 꽤 다른 오답
    elif s < 30 or recent_lapse:
        return "medium"   // 같은 카테고리 오답
    else:
        return "hard"     // 형태/발음까지 유사한 오답
```

#### 오답 유사도 점수 계산

```python
def similarity(word_a, word_b):
    # 1. 읽기 유사도 (가나 편집거리)
    reading_sim = 1 - levenshtein(a.reading, b.reading) / max_len

    # 2. 의미 유사도 (같은 카테고리면 높음)
    semantic_sim = 1.0 if same_category else 0.0

    # 3. 형태 유사도 (품사 + 활용형)
    form_sim = 1.0 if same_pos else 0.0

    return 0.4 * reading_sim + 0.3 * semantic_sim + 0.3 * form_sim
```

#### 난이도별 오답 선택 예시 (정답: あおい/파란색)

```
easy (stability < 7일):
  あおい vs たべる vs いく vs おおきい
  → 품사/의미가 완전히 다름. 소거법 가능.

medium (7~30일):
  あおい vs あつい vs おおきい vs たべる
  → 2개는 소거 가능, 1개(あつい)는 형태 유사로 헷갈림

hard (30일+):
  あおい vs あかい vs あつい vs あらい
  → 전부 あ행 い형용사. 진짜 알아야 맞춤.
```

#### 구현 Phase

```
Phase 1: 품사 + JLPT 레벨 기반 (즉시 가능)
  → 같은 품사, 같은 레벨에서 오답 뽑기
  → 필요 데이터: part_of_speech, jlpt_level (이미 있음)

Phase 2: 읽기 유사도 추가
  → 가나 편집거리로 유사 발음 묶기
  → 자동 계산, 추가 태깅 불필요

Phase 3: 카테고리 태그 추가
  → "색깔", "음식", "교통" 등 의미 그룹 태깅
  → 데이터 제작 시 포함
```

#### 오답 안전장치 (동의어/유사 뜻 충돌 방지)

**문제**: 정답 あおい(파란, 푸른)의 오답에 みどり(초록, 푸른)가 나오면 뜻이 겹침

**해결: 3단계 필터**

```
1. 의미 토큰 교집합 차단 (자동, 즉시 구현)
   정답 뜻: "파란, 푸른" → 토큰 {"파란", "푸른"}
   후보 뜻: "초록, 푸른" → 토큰 {"초록", "푸른"}
   교집합: {"푸른"} → 겹침! → 오답에서 제외

2. synonym_group_id로 동의어 그룹 묶기 (데이터 태깅)
   おおきい(큰)과 でかい(큰) = 같은 그룹
   → 같은 그룹 내 단어는 서로 오답으로 사용 불가

3. 오답 부족 시 대응
   → 더 넓은 풀에서 재시도 (같은 레벨 전체)
   → 그래도 부족하면 해당 문항 스킵
```

```python
def meaning_tokens(text: str) -> set[str]:
    parts = re.split(r"[,\./;:。]+", text or "")
    return {p.strip().lower() for p in parts if p.strip()}

def is_conflict(correct: str, candidate: str) -> bool:
    if correct.strip().lower() == candidate.strip().lower():
        return True
    return bool(meaning_tokens(correct) & meaning_tokens(candidate))
```

**보장 사항:**
- 정답은 4개 선택지 중 반드시 포함 (정답 먼저 확정 → 오답 3개 추가)
- 오답에 정답과 뜻이 겹치는 단어는 절대 포함되지 않음
- 오답끼리 뜻이 중복되는 경우도 제거

**데이터 추가 필드:**
- `meaning_glosses_ko: string[]` — 의미를 미리 분해한 배열
- `synonym_group_id: string | null` — 동의어 그룹 ID

---

## 9. 알림 정책

```
설정: ON / OFF (유저 선택)
최대: 하루 2회
시점: 점심 12:30, 저녁 20:30 (로컬 시간)
조건: 복습 due >= 8개일 때만 발송
2차 알림: 1차 이후 미학습 + due 여전히 있을 때만
```

---

## 10. MASTERED 이후 동작

**MASTERED = "잘 안다". "영원히 안다"가 아님.**

```
MASTERED 진입: stability >= 45일
이후 스케줄: FSRS 자동 (45일 → 90일 → 180일 → ...)
  → 맞추면 간격 더 늘어남
  → 틀리면 RELEARNING으로 강등, 1일부터 다시
```

매일 하는 유저 기준 체감:
```
LEARNING:   거의 매일 나옴
REVIEW:     며칠~몇 주에 한 번
MASTERED:   한 달에 한 번 → 반년에 한 번 → 점점 드물어짐
```

**영원히 안 나오는 아이템은 없음.** 오래된 단어도 가끔 나와서 "아직 기억나네!" 경험 제공.

---

## 11. 학습/퀴즈 탭 충돌 처리

### 핵심 원칙

```
1. SRS 카드는 user_id + item_id로 1개만 유지 (중복 생성 금지)
2. 레슨 진도(LessonProgress)는 SRS와 별도 관리
3. 퀴즈 결과는 레슨 진도/unlock에 영향 없음
4. 오늘 이미 본 단어는 오늘 다시 안 나옴 (최소 1일 간격)
```

### 당일 중복 노출 방지

```
규칙: 퀴즈 세션 생성 시 last_reviewed_at이 오늘인 아이템 제외
효과: 학습 탭에서 배웠든, 퀴즈에서 풀었든, 오늘 본 건 내일부터 출제
체감: "어? 이거 어제 배웠던 건데!" (기억 정착의 핵심 순간)
```

### Case별 처리

| Case | 상황 | 처리 |
|------|------|------|
| 학습 먼저 → 퀴즈 | LEARNING에서 퀴즈 출제 | 내일부터 SRS 복습으로 출제 |
| 퀴즈 먼저 → 학습 | PROVISIONAL에서 레슨 진행 | LEARNING으로 승급 (레슨이 더 강함) |
| 퀴즈 MASTERED → 학습 | 이미 아는 단어가 레슨에 나옴 | 레슨에서 그대로 노출 (대화문 맥락 보존), SRS 상태 유지 |
| 학습 REVIEW → 퀴즈 오답 | 복습 단어를 퀴즈에서 틀림 | due 복습이면 RELEARNING, 아니면 due_at만 앞당김 |

### 상태 승급 규칙

```
강도 순서: UNSEEN < PROVISIONAL < LEARNING = RELEARNING < REVIEW < MASTERED

레슨 완료 시: state = max(현재 상태, LEARNING)
  → PROVISIONAL이면 LEARNING으로 승급
  → REVIEW/MASTERED면 그대로 유지
```

### 레슨에서 이미 아는 단어

- 스킵하지 않음 (대화문 맥락 보존)
- 도입 카드에 "이미 학습한 단어" 배지 표시
- SRS에 중복 강화 반영 안 함

---

## 12. 데이터 모델

### 핵심 필드

```
user_item_state {
  user_id
  item_id
  category: word | grammar | kanji | listening
  introduced_by: lesson | quiz

  // 상태
  state: UNSEEN | PROVISIONAL | LEARNING | REVIEW | MASTERED | RELEARNING
  learning_step: 0 | 1 | 2  // LEARNING/PROVISIONAL 단계

  // FSRS
  stability: float
  difficulty: float
  next_due_at: timestamp
  last_reviewed_at: timestamp

  // 이력
  reps: int
  lapses: int
  last_rating: int

  // 방향별 통계
  jp_kr_correct: int
  jp_kr_total: int
  kr_jp_correct: int
  kr_jp_total: int

  // 찍기 위험도
  guess_risk: float (0~1)
}
```

### 리뷰 이벤트 로그

```
review_event {
  id
  user_id
  item_id
  session_id
  direction: JP_KR | KR_JP
  correct: bool
  response_ms: int
  rating: 1~4
  state_before: state enum
  state_after: state enum
  created_at: timestamp
}
```

---

## 미결 사항 및 논의 필요 항목

### 1. FSRS 전환 타이밍

SM-2에서 FSRS로 언제 전환할지:
- Phase 1에서 SM-2 유지 + 로깅
- Phase 2에서 FSRS 전환
- 구체적 전환 시점 (유저 수? 로그 양? 출시 후 몇 개월?)

**→ 운영 판단. 출시 후 데이터 보고 결정.**

### 2. "모르겠음" 버튼 — 미도입 (확정)

**결정: 넣지 않음.**

이유:
- PROVISIONAL 체계로 찍기 방지가 충분
- "틀리면서 배운다"가 퀴즈 탭의 핵심 철학
- 찍어서라도 맞추면 성취감, "모르겠음"은 성취감 0
- 남용 시 이탈 위험 (15/20 모르겠음 → "아무것도 못했네")
- 출퇴근 한손 5분 퀴즈에서 행동 경로는 하나여야 함
- 대신 정답 피드백 화면 강화로 오기억 문제 완화

### 3. PROVISIONAL 로그의 FSRS 파라미터 학습 제외

PROVISIONAL 단계의 로그(찍기 가능성 높음)를 FSRS 파라미터 최적화에서 제외해야 함.
구현 시 `state_before`가 PROVISIONAL인 이벤트를 필터링.

**→ 구현 시 반영.**

### 4. 카테고리별 FSRS 파라미터 분리 시점

로그 50k 기준은 상당한 규모. 초기에는 글로벌 파라미터를 쓰되,
카테고리별 분리 시점을 모니터링해야 함.

**→ 운영 판단.**

### 5. MCQ 오답 선택지의 오기억 위험

Codex 지적: 4지선다의 오답 선택지가 오기억으로 남을 수 있음.
정답 피드백에서 "왜 이게 정답인지"를 명확히 보여주는 것으로 완화.

**→ 피드백 화면 설계 시 반영.**
