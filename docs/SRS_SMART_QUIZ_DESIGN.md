# SRS 스마트 퀴즈 시스템 설계서

> 작성일: 2026-03-16
> 상태: 설계 완료, 구현 대기
> 참고: 말해보카 UX 벤치마크 기반

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

### 2.1 이미 갖춰진 것 (활용 가능)

| 항목 | 상태 | 위치 |
|------|------|------|
| SRS 핵심 필드 (ease_factor, interval, next_review_at) | ✅ 존재 | `UserVocabProgress`, `UserGrammarProgress` |
| SM-2 유사 알고리즘 | ✅ 부분 구현 | `quiz.py` L596-622 |
| SRS 설정값 | ✅ 존재 | `constants.py` (`_SrsConfig`) |
| 퀴즈 세션 + 답변 기록 | ✅ 완비 | `QuizSession`, `QuizAnswer` |
| 일일 학습 통계 | ✅ 완비 | `DailyProgress` |
| 스테이지 기반 학습 | ✅ 완비 | `StudyStage`, `UserStudyStageProgress` |

### 2.2 현재 SRS 설정값

```python
# constants.py
INITIAL_INTERVALS = (1, 3)       # 1일, 3일
MASTERY_INTERVAL = 21            # 21일 이상 = 마스터
MIN_EASE_FACTOR = 1.3            # 최소 난이도 계수
INCORRECT_PENALTY = 0.2          # 오답 시 ease_factor 감소량
REVIEW_DELAY_MINUTES = 10        # 오답 후 재노출 대기시간
```

### 2.3 현재 정답/오답 처리 로직

```python
# 정답 시
progress.streak += 1
if streak <= 1: interval = 1일
elif streak == 2: interval = 3일
else: interval = round(interval * ease_factor)
ease_factor += 0.1

# 오답 시
progress.streak = 0
progress.interval = 0
ease_factor -= 0.2 (최소 1.3)
next_review = now + 10분
```

### 2.4 현재 퀴즈 생성 방식

```
normal 모드:  80% 새 단어 + 20% 복습 단어 (next_review_at <= now)
review 모드:  100% 복습 대상만
wrong 모드:   100% 오답 단어만 (interval == 0)
```

**문제점**: 사용자가 직접 모드를 선택해야 함 → 학습 마찰 발생

### 2.5 부족한 것

| 항목 | 상태 | 설명 |
|------|------|------|
| Kana SRS 필드 | ❌ 없음 | `UserKanaProgress`에 ease_factor, interval, next_review_at 없음 |
| 응답 품질 등급 | ❌ 없음 | 정답/오답만 (SM-2의 0-5 등급 미사용) |
| 응답 속도 반영 | ❌ 미사용 | `time_spent_seconds` 기록만, SRS에 미반영 |
| 문장/Cloze 진도 추적 | ❌ 없음 | 문장 배열/빈칸 채우기의 개별 진도 모델 없음 |
| 일시 정지(Suspend) | ❌ 없음 | 특정 단어 복습 중단 불가 |
| 일일 학습 배분 알고리즘 | ❌ 없음 | 새/복습/재도전 비율 자동 계산 로직 없음 |

---

## 3. 스마트 퀴즈 아키텍처

### 3.1 학습 풀(Pool) 분류

사용자가 "학습 시작"을 누르면, 백엔드에서 3개의 풀을 조회:

```
┌─────────────────────────────────────────────────┐
│                  스마트 퀴즈 엔진                    │
│                                                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │ 새 단어   │  │ 복습 대상 │  │ 재도전    │       │
│  │ (New)     │  │ (Review)  │  │ (Retry)   │       │
│  └──────────┘  └──────────┘  └──────────┘       │
│       │              │              │              │
│       └──────────────┼──────────────┘              │
│                      ▼                             │
│              비율 배분 알고리즘                       │
│                      │                             │
│                      ▼                             │
│          최종 퀴즈 세트 (20문제)                      │
│          셔플 + 난이도 분산 배치                      │
└─────────────────────────────────────────────────┘
```

#### Pool 1: 새 단어 (New)
```sql
-- UserVocabProgress에 기록이 없는 단어
SELECT v.* FROM vocabularies v
LEFT JOIN user_vocab_progress p ON p.vocabulary_id = v.id AND p.user_id = :uid
WHERE v.jlpt_level = :level AND p.id IS NULL
ORDER BY v.order, v.id
LIMIT :new_count
```

#### Pool 2: 복습 대상 (Review)
```sql
-- next_review_at이 현재 시각 이하인 단어 (복습 시기 도래)
SELECT p.*, v.* FROM user_vocab_progress p
JOIN vocabularies v ON v.id = p.vocabulary_id
WHERE p.user_id = :uid
  AND p.next_review_at <= NOW()
  AND p.interval > 0           -- 최소 1회 이상 정답 이력
  AND p.mastered = false       -- 아직 마스터 안 됨
ORDER BY p.next_review_at ASC  -- 가장 오래된 것 우선
LIMIT :review_count
```

#### Pool 3: 재도전 (Retry)
```sql
-- interval = 0 (직전에 틀린 단어)
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
    """
    일일 목표 수에 따른 새/복습/재도전 배분.

    원칙:
    1. 재도전(오답)이 최우선 — 틀린 건 빨리 교정
    2. 복습이 그 다음 — 망각 곡선 방지
    3. 새 단어는 나머지 — 복습 부채 없을 때 확장
    """
    goal = daily_goal  # 기본 20

    # 1. 재도전: 최대 goal의 20% (4개)
    retry = min(retry_due, goal // 5)
    remaining = goal - retry

    # 2. 복습: 남은 슬롯의 최대 75%
    review = min(review_due, int(remaining * 0.75))
    remaining -= review

    # 3. 새 단어: 나머지
    new = remaining

    # 복습 부채가 많으면 새 단어를 줄임
    if review_due > review + 10:
        # 복습 부채 경고 — 새 단어 비율 줄이기
        extra_review = min(review_due - review, new // 2)
        review += extra_review
        new -= extra_review

    return {
        "new": max(new, 0),
        "review": review,
        "retry": retry,
        "total": retry + review + max(new, 0),
    }
```

**예시 시나리오** (daily_goal=20):

| 상황 | 재도전 | 복습 | 새 단어 | 합계 |
|------|--------|------|---------|------|
| 첫 학습 (복습 없음) | 0 | 0 | 20 | 20 |
| 일반 학습 | 2 | 13 | 5 | 20 |
| 복습 부채 많음 | 3 | 15 | 2 | 20 |
| 오답 많음 | 4 | 11 | 5 | 20 |

### 3.3 SM-2 알고리즘 개선

현재 구현을 기반으로, 응답 품질(quality)과 속도를 반영하도록 강화:

```python
def calculate_srs_update(
    progress: UserVocabProgress,
    is_correct: bool,
    time_spent_seconds: int,
) -> SrsUpdate:
    """
    SM-2 기반 SRS 업데이트 계산.

    Quality 등급 (자동 판정):
    - 5: 정답 + 즉시 (≤3초)     → "완벽 기억"
    - 4: 정답 + 빠름 (≤8초)     → "잘 기억"
    - 3: 정답 + 보통 (>8초)      → "어렵게 기억"
    - 2: 오답 + 정답에 가까움     → "거의 기억" (향후)
    - 1: 오답                    → "기억 못 함"
    - 0: 오답 + 반복 오답        → "완전 망각"
    """
    # 품질 등급 산정
    if is_correct:
        if time_spent_seconds <= SRS_CONFIG.SPEED_THRESHOLDS.INSTANT:
            quality = 5
        elif time_spent_seconds <= SRS_CONFIG.SPEED_THRESHOLDS.QUICK:
            quality = 4
        else:
            quality = 3
    else:
        quality = 1 if progress.streak > 0 else 0

    # SM-2 ease_factor 업데이트
    # EF' = EF + (0.1 - (5-q) * (0.08 + (5-q) * 0.02))
    ef = progress.ease_factor
    ef = ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
    ef = max(SRS_CONFIG.MIN_EASE_FACTOR, ef)

    # Interval 계산
    if quality < 3:  # 오답
        interval = 0
        streak = 0
    else:  # 정답
        streak = progress.streak + 1
        if streak == 1:
            interval = 1
        elif streak == 2:
            interval = 3
        else:
            interval = round(progress.interval * ef)

        # 빠른 응답 보너스: 즉시 응답 시 interval 10% 추가
        if quality == 5 and interval > 3:
            interval = round(interval * 1.1)

    # next_review_at 계산
    if interval > 0:
        next_review = now() + timedelta(days=interval)
    else:
        next_review = now() + timedelta(minutes=SRS_CONFIG.REVIEW_DELAY_MINUTES)

    mastered = interval >= SRS_CONFIG.MASTERY_INTERVAL

    return SrsUpdate(
        streak=streak,
        interval=interval,
        ease_factor=round(ef, 2),
        next_review_at=next_review,
        mastered=mastered,
        quality=quality,
    )
```

---

## 4. API 설계

### 4.1 새 엔드포인트: 스마트 퀴즈 프리뷰

사용자에게 "오늘의 학습" 모달을 보여주기 위한 엔드포인트.

```
GET /api/v1/quiz/smart-preview?category=VOCABULARY&jlptLevel=N5
```

**Response:**
```json
{
  "distribution": {
    "new": 5,
    "review": 13,
    "retry": 2,
    "total": 20
  },
  "dailyGoal": 20,
  "todayCompleted": 0,
  "reviewDebt": 97,
  "lastReviewedAt": "2026-03-13T10:30:00Z",
  "overallProgress": {
    "total": 800,
    "studied": 186,
    "mastered": 42,
    "percentage": 23
  }
}
```

### 4.2 새 엔드포인트: 스마트 퀴즈 시작

```
POST /api/v1/quiz/smart-start
```

**Request:**
```json
{
  "category": "VOCABULARY",
  "jlptLevel": "N5",
  "count": 20,
  "distribution": {
    "new": 5,
    "review": 13,
    "retry": 2
  }
}
```

**Response:** 기존 `/quiz/start`와 동일한 형태 (QuizSession + questions)

**백엔드 로직:**
1. Pool 3개에서 지정 비율대로 단어 추출
2. 중복 제거 (meaning_ko 기준)
3. 셔플 (단, 재도전 단어를 앞쪽에 배치하는 경향)
4. 문제 생성 (4지선다 옵션)
5. QuizSession 저장 + 반환

### 4.3 기존 엔드포인트 유지

기존 `POST /quiz/start` (mode: normal/review/wrong)는 **그대로 유지**. 자유 퀴즈 탭에서 계속 사용. 스마트 퀴즈는 별도 엔드포인트로 추가하여 점진적 마이그레이션.

---

## 5. DB 스키마 변경

### 5.1 변경 필요 없음 (기존 필드 활용)

**UserVocabProgress, UserGrammarProgress**: 이미 충분한 SRS 필드 보유
- `ease_factor` (Float, default 2.5) ✅
- `interval` (Integer, default 0) ✅
- `next_review_at` (DateTime, nullable) ✅
- `last_reviewed_at` (DateTime, nullable) ✅
- `mastered` (Boolean, default False) ✅
- `streak` (Integer, default 0) ✅
- `correct_count`, `incorrect_count` ✅

### 5.2 선택적 추가 필드 (Phase 2)

```python
# UserVocabProgress / UserGrammarProgress에 추가 고려
class UserVocabProgress(Base):
    # ... 기존 필드 ...

    # Phase 2: 품질 추적
    last_quality = Column(Integer, default=0)          # 마지막 응답 품질 (0-5)
    avg_time_seconds = Column(Float, default=0.0)      # 평균 응답 시간
    suspended = Column(Boolean, default=False)          # 학습 일시정지

    # Phase 2: 망각 분석
    lapse_count = Column(Integer, default=0)            # 마스터 후 다시 틀린 횟수
```

### 5.3 UserKanaProgress SRS 필드 추가 (Phase 2)

```python
# 현재 없는 필드 추가 필요
class UserKanaProgress(Base):
    # ... 기존 필드 ...

    # 추가 필요
    ease_factor = Column(Float, default=2.5)
    interval = Column(Integer, default=0)
    next_review_at = Column(DateTime(timezone=True), nullable=True)
    incorrect_count = Column(Integer, default=0)
```

### 5.4 마이그레이션 계획

```
Phase 1: 스키마 변경 없음 — 기존 필드만으로 스마트 퀴즈 구현
Phase 2: Alembic 마이그레이션
  - UserVocabProgress: last_quality, avg_time_seconds, suspended, lapse_count
  - UserGrammarProgress: 동일
  - UserKanaProgress: ease_factor, interval, next_review_at, incorrect_count
```

---

## 6. 모바일 UI 설계

### 6.1 퀴즈 탭 UX 플로우

```
퀴즈 탭
├── 상단: "퀴즈" 타이틀
├── [스마트 학습 카드]          ← 신규
│   ├── "오늘의 학습"
│   ├── 원형 프로그레스 (0/20)
│   ├── 배분 요약: 새 5 · 복습 13 · 재도전 2
│   └── [학습 시작] 버튼
├── 탭: 추천 | 자유 퀴즈        ← 기존 유지
│   ├── 추천 탭: AI 추천 카드들
│   └── 자유 퀴즈 탭: 레벨/타입/모드 직접 선택
├── ─── 구분선 ───
└── 메뉴 리스트
    ├── 오답노트 >
    ├── 학습한 단어 >
    └── 단어장 >
```

### 6.2 스마트 학습 카드 (메인 CTA)

```
┌──────────────────────────────────────┐
│  📖 오늘의 학습                       │
│                                       │
│        ╭───────────╮                  │
│        │   0/20    │                  │
│        │   ○○○○    │  ← 원형 프로그레스│
│        ╰───────────╯                  │
│                                       │
│  새로운 단어  5개                      │
│  복습할 단어  13개                     │
│  재도전 단어  2개                      │
│                                       │
│  ┌──────────────────────────────┐    │
│  │       학습 시작 →             │    │
│  └──────────────────────────────┘    │
└──────────────────────────────────────┘
```

### 6.3 학습 시작 시 모달 (말해보카 스타일)

"학습 시작" 탭 → 바텀시트 모달:

```
┌──────────────────────────────────────┐
│  어휘 학습                    ✕      │
│                                       │
│  ┌─ 학습 코스 ─────────────────┐     │
│  │ JLPT N5          [변경]     │     │
│  │ ━━━━━━━━━░░░ 186/800        │     │
│  │ 완료율: 23%                  │     │
│  └─────────────────────────────┘     │
│                                       │
│        ╭───────────╮                  │
│        │           │                  │
│        │  새로운  5 개 │               │
│        │  복습   13 개 │               │
│        │  재도전  2 개 │               │
│        │           │                  │
│        ╰───────────╯                  │
│                                       │
│       0 / 20                          │
│                                       │
│  ┌──────────────────────────────┐    │
│  │     📖 오늘의 학습            │    │
│  └──────────────────────────────┘    │
└──────────────────────────────────────┘
```

---

## 7. 구현 로드맵

### Phase 1: 스마트 퀴즈 MVP (1주)

**백엔드** (3일):
1. `GET /quiz/smart-preview` 엔드포인트 추가
   - 3개 풀 카운트 조회 (새/복습/재도전)
   - 배분 알고리즘 적용
   - 전체 진도 반환
2. `POST /quiz/smart-start` 엔드포인트 추가
   - 3개 풀에서 비율대로 추출
   - 기존 문제 생성 로직 재사용
   - QuizSession에 `mode: "smart"` 표기
3. 기존 답변 처리(`answer_quiz`)에 응답 속도 반영
   - `time_spent_seconds` 기반 quality 등급 자동 산정
   - SM-2 ease_factor 계산식 개선

**모바일** (3일):
1. 퀴즈 탭 상단에 스마트 학습 카드 추가
2. smart-preview API 연동 (Provider 추가)
3. 학습 시작 바텀시트 모달 구현
4. smart-start API 연동 → 기존 QuizPage로 이동

**테스트** (1일):
- 배분 알고리즘 단위 테스트
- 빈 풀 / 복습 부채 / 첫 학습 등 엣지 케이스

### Phase 2: SRS 고도화 (1주)

1. SM-2 품질 등급 + 속도 보너스 완전 구현
2. UserKanaProgress에 SRS 필드 추가 (Alembic 마이그레이션)
3. 복습 부채 알림 ("97개 단어가 복습을 기다리고 있어요")
4. 일일 학습 완료 시 축하 화면 + 통계 요약
5. `suspended` 필드: 특정 단어 학습 일시 정지 기능

### Phase 3: 고급 기능 (2주)

1. 문장 배열 / Cloze 문제의 진도 추적 모델 추가
2. 카테고리 혼합 퀴즈 (단어 + 문법 + 문장을 한 세션에)
3. 망각 분석 (lapse_count) + 취약 단어 집중 학습
4. 학습 리포트 ("이번 주 복습 완료율 85%")
5. 오프라인 모드: 마지막 동기화 시점의 퀴즈 세트 캐시

---

## 8. 기존 코드와의 호환성

### 유지하는 것
- 기존 `POST /quiz/start` (normal/review/wrong 모드) → 자유 퀴즈 탭에서 계속 사용
- 기존 `POST /quiz/answer`, `POST /quiz/complete` → 스마트 퀴즈도 동일하게 사용
- 기존 SRS 업데이트 로직 → Phase 1에서는 그대로, Phase 2에서 개선
- 스테이지 기반 학습 → 학습 탭에서 그대로 유지

### 변경하는 것
- 퀴즈 탭 UI: 스마트 학습 카드 추가 (상단)
- 추천 탭 내용: smart-preview 데이터 기반으로 개선
- QuizSession 모델: `mode` 필드에 "smart" 값 추가 (기존 enum 확장)

### 마이그레이션 전략
1. Phase 1에서 스마트 퀴즈를 **추가** (기존 기능 건드리지 않음)
2. 사용자 반응 보고 Phase 2에서 기존 모드를 점진적으로 통합
3. 최종적으로 자유 퀴즈 탭은 "고급 설정"으로 남기거나 제거 결정

---

## 9. 성능 고려사항

### 쿼리 최적화
```sql
-- smart-preview에서 3개 풀 카운트를 한 번에 조회
SELECT
  COUNT(*) FILTER (WHERE p.id IS NULL) AS new_count,
  COUNT(*) FILTER (WHERE p.next_review_at <= NOW() AND p.interval > 0) AS review_count,
  COUNT(*) FILTER (WHERE p.interval = 0 AND p.incorrect_count > 0) AS retry_count
FROM vocabularies v
LEFT JOIN user_vocab_progress p ON p.vocabulary_id = v.id AND p.user_id = :uid
WHERE v.jlpt_level = :level;
```

### 인덱스 추가 권장
```sql
-- 복습 대상 빠른 조회
CREATE INDEX idx_vocab_progress_review
ON user_vocab_progress (user_id, next_review_at)
WHERE next_review_at IS NOT NULL;

-- 재도전 대상 빠른 조회
CREATE INDEX idx_vocab_progress_retry
ON user_vocab_progress (user_id, interval)
WHERE interval = 0 AND incorrect_count > 0;

-- Grammar도 동일
CREATE INDEX idx_grammar_progress_review
ON user_grammar_progress (user_id, next_review_at)
WHERE next_review_at IS NOT NULL;
```

---

## 10. 리스크 및 대응

| 리스크 | 영향 | 대응 |
|--------|------|------|
| 복습 부채 폭증 (장기 미접속) | 사용자 좌절 | 복습 캡 설정 (하루 최대 50개), 오래된 것 우선순위 하향 |
| 새 단어 0개 (복습만) | 학습 동기 저하 | 최소 새 단어 보장 (goal의 10%, 최소 2개) |
| 일일 목표 과다 | 번아웃 | 목표 변경 UI 제공, 기본값 20으로 적절 |
| 오프라인 상태 | 학습 불가 | Phase 3에서 오프라인 캐시 대응 |
| SM-2 한계 (개인차) | 비효율 | Phase 3에서 FSRS(Free Spaced Repetition Scheduler) 검토 |

---

## 부록: SM-2 알고리즘 참고

```
SM-2 핵심 공식:
EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))

여기서:
- EF = Ease Factor (난이도 계수, 초기 2.5)
- q  = Quality (응답 품질, 0-5)
- q ≥ 3 → 기억 성공, q < 3 → 기억 실패

Interval 계산:
- n=1: I(1) = 1일
- n=2: I(2) = 6일 (우리는 3일로 조정 — 앱 특성상 빈번한 접속 유도)
- n>2: I(n) = I(n-1) * EF

Mastery 기준:
- interval ≥ 21일 → mastered = true
- 마스터 후에도 복습 스케줄 유지 (간격이 길어질 뿐)
```
