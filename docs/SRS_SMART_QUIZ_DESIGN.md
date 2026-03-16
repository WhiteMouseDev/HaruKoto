# SRS 스마트 퀴즈 시스템 설계서 v2

> 작성일: 2026-03-16
> 최종 수정: 2026-03-16 (Claude + Gemini 통합 리뷰 반영)
> 상태: Phase 1 구현 중
> 참고: 말해보카 UX 벤치마크 기반

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| v1 | 2026-03-16 | 초안 작성 |
| v2 | 2026-03-16 | 코드 리뷰 반영: SM-2 개선, Lapse 처리, 쿼리 최적화, API 응답 구조 개선 |

---

## 1. 목표

사용자가 "학습 시작" 한 버튼만 누르면, **새로운 단어 + 복습할 단어 + 재도전 단어**가 최적 비율로 섞인 퀴즈가 자동 생성되는 시스템.

### 핵심 원칙
- **간격 반복(Spaced Repetition)**: SM-2 알고리즘 기반 복습 스케줄링
- **인터리빙(Interleaving)**: 새 학습 + 복습 + 재도전을 한 세션에 혼합
- **최소 마찰**: 모드 선택 없이 원버튼으로 최적 학습 시작
- **적응형 난이도**: 사용자 수준에 따라 자동 조절

---

## 2. 현재 시스템 분석

### 2.1 이미 갖춰진 것

| 항목 | 상태 | 위치 |
|------|------|------|
| SRS 핵심 필드 (ease_factor, interval, next_review_at) | ✅ | `UserVocabProgress`, `UserGrammarProgress` |
| SM-2 유사 알고리즘 | ✅ 부분 | `quiz.py` L596-622 |
| SRS 설정값 | ✅ | `constants.py` (`_SrsConfig`) |
| 퀴즈 세션 + 답변 기록 | ✅ | `QuizSession`, `QuizAnswer` |
| 일일 학습 통계 | ✅ | `DailyProgress` |

### 2.2 현재 SRS 설정값

```python
INITIAL_INTERVALS = (1, 3)       # 1일, 3일
MASTERY_INTERVAL = 21            # 21일 이상 = 마스터
MIN_EASE_FACTOR = 1.3
INCORRECT_PENALTY = 0.2
REVIEW_DELAY_MINUTES = 10
SPEED_THRESHOLDS: INSTANT = 3, QUICK = 8
```

### 2.3 현재 퀴즈 생성 방식

```
normal 모드:  80% 새 단어 + 20% 복습 단어
review 모드:  100% 복습 대상만
wrong 모드:   100% 오답 단어만
```

**문제점**: 사용자가 직접 모드를 선택해야 함 → 학습 마찰 발생

---

## 3. 스마트 퀴즈 아키텍처

### 3.1 학습 풀(Pool) 분류

#### Pool 1: 새 단어 (New)
```sql
SELECT v.* FROM vocabularies v
WHERE v.jlpt_level = :level
  AND NOT EXISTS (
    SELECT 1 FROM user_vocab_progress p
    WHERE p.vocabulary_id = v.id AND p.user_id = :uid
  )
ORDER BY v.order, v.id
LIMIT :new_count
```

#### Pool 2: 복습 대상 (Review)
```sql
SELECT p.*, v.* FROM user_vocab_progress p
JOIN vocabularies v ON v.id = p.vocabulary_id
WHERE p.user_id = :uid
  AND p.next_review_at <= NOW()
  AND p.interval > 0
ORDER BY p.next_review_at ASC
LIMIT :review_count
```
> mastered 단어도 포함 — interval이 충분히 길어 빈도는 자연스럽게 낮아짐

#### Pool 3: 재도전 (Retry)
```sql
SELECT p.*, v.* FROM user_vocab_progress p
JOIN vocabularies v ON v.id = p.vocabulary_id
WHERE p.user_id = :uid
  AND p.interval = 0
  AND p.incorrect_count > 0
  AND p.last_reviewed_at <= NOW() - INTERVAL ':delay minutes'
ORDER BY p.last_reviewed_at ASC
LIMIT :retry_count
```

### 3.2 비율 배분 알고리즘

```python
def calculate_distribution(daily_goal: int, review_due: int, retry_due: int) -> dict:
    goal = daily_goal  # 기본 20
    min_new = max(2, goal // 10)  # 최소 새 단어 보장

    # 1. 재도전: 최대 goal의 20%
    retry = min(retry_due, goal // 5)
    remaining = goal - retry

    # 2. 복습: 남은 슬롯의 최대 75%
    review = min(review_due, int(remaining * 0.75))
    remaining -= review

    # 3. 새 단어: 나머지
    new = remaining

    # 복습 부채 단계적 대응
    if review_due > review + 30:
        extra = new - min_new
        review += extra
        new = min_new
    elif review_due > review + 10:
        extra_review = min(review_due - review, new // 2)
        review += extra_review
        new -= extra_review

    return {"new": max(new, min_new), "review": review, "retry": retry}
```

### 3.3 SM-2 알고리즘 개선

#### Phase 1 적용 범위

```python
def calculate_srs_update(progress, is_correct, time_spent_seconds):
    # Quality: 정답 시 속도 기반 (3/4/5), 오답 시 (0/1)
    if is_correct:
        if time_spent_seconds <= 3: quality = 5
        elif time_spent_seconds <= 8: quality = 4
        else: quality = 3
    else:
        quality = 1 if progress.streak > 0 else 0

    # SM-2 EF 업데이트
    ef = progress.ease_factor
    ef = ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
    ef = max(1.3, ef)

    # Interval 계산
    if quality < 3:  # 오답
        streak = 0
        # Lapse Multiplier: 완전 리셋 대신 기존 interval의 10% 보존
        if progress.interval > 0:
            interval = min(7, max(1, round(progress.interval * 0.1)))
        else:
            interval = 0
    else:  # 정답
        streak = progress.streak + 1
        if streak == 1: interval = 1
        elif streak == 2: interval = 3
        else: interval = round(progress.interval * ef)
        # 즉시 응답 보너스
        if quality == 5 and interval > 3:
            interval = round(interval * 1.1)

    next_review = now() + timedelta(days=interval) if interval > 0 \
        else now() + timedelta(minutes=10)
    mastered = interval >= 21

    return SrsUpdate(streak, interval, round(ef, 2), next_review, mastered, quality)
```

#### Phase 2 추가 예정
- quality 2등급 (streak>=3 AND correct_count>=5 조건부 EF 방어)
- 퀴즈 타입별 속도 임계값 (문장배열/Cloze 도입 시)
- 구간별 가중치 셔플 (warmup/core/cooldown)

---

## 4. API 설계

### 4.1 스마트 퀴즈 프리뷰

```
GET /api/v1/quiz/smart-preview?category=VOCABULARY&jlptLevel=N5
```

```json
{
  "poolSize": {
    "newReady": 614,
    "reviewDue": 97,
    "retryDue": 5
  },
  "sessionDistribution": {
    "new": 5,
    "review": 13,
    "retry": 2,
    "total": 20
  },
  "dailyGoal": 20,
  "todayCompleted": 0,
  "overallProgress": {
    "total": 800,
    "studied": 186,
    "mastered": 42,
    "percentage": 23
  }
}
```

### 4.2 스마트 퀴즈 시작

```
POST /api/v1/quiz/smart-start
```

```json
{
  "category": "VOCABULARY",
  "jlptLevel": "N5",
  "count": 20
}
```

Response: 기존 `/quiz/start`와 동일 형태 (QuizSession + questions)

### 4.3 기존 엔드포인트 유지
- `POST /quiz/start` (normal/review/wrong) → 자유 퀴즈 탭
- `POST /quiz/answer`, `POST /quiz/complete` → 스마트/일반 공용

---

## 5. DB 스키마

### Phase 1: 변경 없음
기존 필드 활용: ease_factor, interval, next_review_at, streak, correct_count, incorrect_count, mastered, last_reviewed_at

### Phase 2: 마이그레이션 필요
```python
# UserVocabProgress / UserGrammarProgress 추가
last_quality = Column(Integer, default=0)
avg_time_seconds = Column(Float, default=0.0)
suspended = Column(Boolean, default=False)
lapse_count = Column(Integer, default=0)

# UserKanaProgress 추가
ease_factor = Column(Float, default=2.5)
interval = Column(Integer, default=0)
next_review_at = Column(DateTime(timezone=True), nullable=True)
incorrect_count = Column(Integer, default=0)
```

### 인덱스 추가 (Phase 1)
```sql
CREATE INDEX idx_vocab_progress_lookup ON user_vocab_progress (vocabulary_id, user_id);
CREATE INDEX idx_vocab_progress_review ON user_vocab_progress (user_id, next_review_at) WHERE next_review_at IS NOT NULL;
CREATE INDEX idx_vocab_progress_retry ON user_vocab_progress (user_id, interval) WHERE interval = 0 AND incorrect_count > 0;
```

---

## 6. 모바일 UI

### 퀴즈 탭 구조
```
퀴즈 탭
├── "퀴즈" 타이틀
├── [스마트 학습 카드]          ← 신규
│   ├── 원형 프로그레스 (0/20)
│   ├── 배분 요약: 새 5 · 복습 13 · 재도전 2
│   ├── 복습 부채 배지 (reviewDue > 30 시)
│   └── [학습 시작] 버튼
├── 탭: 추천 | 자유 퀴즈
├── ─── 구분선 ───
└── 오답노트 > / 학습한 단어 > / 단어장 >
```

---

## 7. 구현 범위

### Phase 1: 스마트 퀴즈 MVP (스키마 변경 없음)

**백엔드:**
1. `GET /quiz/smart-preview` — 3풀 카운트 + 배분 + 진도
2. `POST /quiz/smart-start` — 3풀 추출 + 셔플 + 문제 생성
3. `answer_quiz` SM-2 v2 적용 — quality 속도 분기 + Lapse Multiplier
4. DB 인덱스 추가
5. Pool 부족 시 폴백: 부족분을 new로 보충, new도 부족하면 total 축소

**모바일:**
1. 퀴즈 탭 상단 스마트 학습 카드
2. smart-preview Provider
3. 학습 시작 → 기존 QuizPage 연결
4. 복습 부채 배지

**테스트:**
- 배분 알고리즘 (부채 경미/심각)
- Lapse Multiplier (interval 0/1/30/60/200)
- 빈 풀 / 첫 학습 엣지 케이스

### Phase 2: SRS 고도화 (데이터 수집 후)
- quality 2등급 조건부 도입 (실사용 데이터 검증)
- 퀴즈 타입별 속도 임계값 (문장/Cloze 도입 시)
- 구간별 가중치 셔플 (30문제 이상 시 의미 있음)
- Kana SRS 필드 마이그레이션
- suspended, lapse_count 필드 추가
- 학습 완료 축하 화면
- FSRS 전환 검토

---

## 부록: SM-2 참고

```
EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))

Quality별 EF 변화 (EF=2.5 기준):
q=5: +0.10 → 2.60  |  q=4: +0.00 → 2.50  |  q=3: -0.14 → 2.36
q=2: -0.32 → 2.18  |  q=1: -0.54 → 1.96  |  q=0: -0.80 → 1.70

Interval: n=1→1일, n=2→3일, n>2→I(n-1)*EF
Lapse: min(7, max(1, round(old_interval * 0.1)))
Mastery: interval >= 21일
```
