# 데이터 스키마 설계

> 최종 수정: 2026-03-20
> 상태: 설계 확정
> 작성: Claude Code × Codex 3차 토론

---

## 1. 설계 원칙

```
1. 기존 테이블 최대 활용 — 새 테이블은 최소한으로
2. dual-write 금지 — 상태 테이블 이중 운영 안 함
3. KANJI/LISTENING은 지금 안 넣음 — WORD/GRAMMAR만
4. SM-2 → FSRS 점진 전환 — scheduler_version으로 분기
5. 레슨 콘텐츠는 JSONB + 링크 테이블 하이브리드
```

---

## 2. 전체 테이블 구조

### 신규 테이블 (5개)

| 테이블 | 용도 |
|--------|------|
| `chapters` | 챕터 (Part > Chapter > Lesson 중 Chapter) |
| `lessons` | 레슨 메타 + content_jsonb (대화문/문항) |
| `lesson_item_links` | 레슨 ↔ 단어/문법 연결 |
| `user_lesson_progress` | 유저별 레슨 진도 |
| `review_events` | SRS 리뷰 이벤트 로그 (월별 파티션) |

### 기존 테이블 변경 (2개)

| 테이블 | 변경 내용 |
|--------|----------|
| `user_vocab_progress` | SRS 상태 + FSRS 필드 추가 |
| `user_grammar_progress` | SRS 상태 + FSRS 필드 추가 (동일) |

### 기존 유지 (변경 없음)

| 테이블 | 설명 |
|--------|------|
| `vocabularies` | 단어 콘텐츠 (meaning_glosses_ko, synonym_group_id 추가) |
| `grammars` | 문법 콘텐츠 (meaning_glosses_ko, synonym_group_id 추가) |
| `quiz_sessions` | 퀴즈 세션 |
| `quiz_answers` | 퀴즈 답변 |

### 뷰 (물리 테이블 아님)

| 뷰 | 용도 |
|-----|------|
| `user_chapter_progress_v` | 챕터별 진도 집계 (lesson_progress에서 계산) |

---

## 3. 신규 테이블 상세

### chapters

```sql
CREATE TABLE chapters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  jlpt_level TEXT NOT NULL,           -- N5, N4, ...
  part_no SMALLINT NOT NULL,          -- Part 1, 2, 3
  chapter_no SMALLINT NOT NULL,       -- Chapter 번호
  title TEXT NOT NULL,                -- "인사와 소개"
  topic TEXT,                         -- "인사"
  order_no SMALLINT NOT NULL DEFAULT 0,
  is_published BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (jlpt_level, part_no, chapter_no)
);
```

### lessons

```sql
CREATE TABLE lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chapter_id UUID NOT NULL REFERENCES chapters(id),
  jlpt_level TEXT NOT NULL,
  lesson_no INTEGER NOT NULL,           -- 레벨 내 전역 순번
  chapter_lesson_no SMALLINT NOT NULL,  -- 챕터 내 순번
  title TEXT NOT NULL,                  -- "인사하기"
  topic TEXT NOT NULL,                  -- "인사"
  estimated_minutes SMALLINT NOT NULL DEFAULT 10,

  -- 레슨 콘텐츠 (대화문 + 확인 문제)
  content_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb,
  /*
  content_jsonb 구조:
  {
    "reading": {
      "type": "dialogue",
      "scene": "대학 오리엔테이션 교실, 옆자리 학생에게 인사",
      "script": [
        {
          "speaker": "田中",
          "voice_id": "japanese_male_1",
          "text": "はじめまして。田中です。",
          "translation": "처음 뵙겠습니다. 다나카입니다."
        },
        {
          "speaker": "キム",
          "voice_id": "japanese_female_1",
          "text": "はじめまして。キムです。",
          "translation": "처음 뵙겠습니다. 김입니다."
        }
      ],
      "highlights": ["はじめまして", "です"],
      "audio_url": "..."
    },
    "questions": [
      {
        "order": 1,
        "type": "VOCAB_MCQ",
        "cognitive_level": "인식",
        "prompt": "こんにちは의 뜻은?",
        "options": [
          {"id": "a", "text": "안녕하세요"},
          {"id": "b", "text": "감사합니다"},
          {"id": "c", "text": "죄송합니다"},
          {"id": "d", "text": "잘 부탁합니다"}
        ],
        "correct_answer": "a",
        "explanation": "こんにちは는 낮 시간대 인사말입니다."
      },
      {
        "order": 5,
        "type": "SENTENCE_REORDER",
        "cognitive_level": "산출유사",
        "prompt": "'저는 학생입니다'를 올바른 순서로 배열하세요.",
        "tokens": ["学生", "私は", "です"],
        "correct_order": ["私は", "学生", "です"],
        "explanation": "일본어 어순: 주어 + 명사 + です"
      }
    ]
  }

  --- 스키마 필드 설명 ---
  reading.scene:               대화 상황 설명 (한국어, UI에서 컨텍스트 제공)
  script[].translation:        각 대사의 한국어 번역 (학습자 이해 보조)
  questions[].cognitive_level:  인식 | 적용 | 산출유사 (인지 수준 태깅)
  questions[].type:            VOCAB_MCQ | CONTEXT_CLOZE | SENTENCE_REORDER
  -- SENTENCE_REORDER 전용 필드:
  questions[].tokens:          섞어서 제시할 토큰 배열
  questions[].correct_order:   올바른 순서 배열
  -- MCQ/CLOZE 전용 필드:
  questions[].options:         선택지 배열 [{id, text}]
  questions[].correct_answer:  정답 id (항상 첫 번째에 저장, 프론트에서 셔플)
  */

  is_published BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (chapter_id, chapter_lesson_no),
  UNIQUE (jlpt_level, lesson_no)
);

CREATE INDEX idx_lessons_chapter ON lessons (chapter_id, chapter_lesson_no);
```

### lesson_item_links

```sql
CREATE TABLE lesson_item_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  item_type TEXT NOT NULL,             -- 'WORD' | 'GRAMMAR'
  vocabulary_id UUID REFERENCES vocabularies(id),
  grammar_id UUID REFERENCES grammars(id),
  item_order SMALLINT NOT NULL,
  is_core BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (lesson_id, item_type, vocabulary_id, grammar_id),
  CHECK (
    (item_type = 'WORD' AND vocabulary_id IS NOT NULL AND grammar_id IS NULL) OR
    (item_type = 'GRAMMAR' AND grammar_id IS NOT NULL AND vocabulary_id IS NULL)
  )
);

CREATE INDEX idx_lesson_item_links_lesson ON lesson_item_links (lesson_id, item_order);
CREATE INDEX idx_lesson_item_links_vocab ON lesson_item_links (vocabulary_id);
CREATE INDEX idx_lesson_item_links_grammar ON lesson_item_links (grammar_id);
```

### user_lesson_progress

```sql
CREATE TABLE user_lesson_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'NOT_STARTED',  -- NOT_STARTED | IN_PROGRESS | COMPLETED
  attempts INTEGER NOT NULL DEFAULT 0,
  score_correct INTEGER NOT NULL DEFAULT 0,
  score_total INTEGER NOT NULL DEFAULT 0,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  srs_registered_at TIMESTAMPTZ,       -- SRS 등록 시점
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, lesson_id)
);

CREATE INDEX idx_user_lesson_progress_user ON user_lesson_progress (user_id, status);
```

### review_events (월별 파티션)

```sql
CREATE TABLE review_events (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  item_type TEXT NOT NULL,             -- 'WORD' | 'GRAMMAR'
  vocabulary_id UUID,
  grammar_id UUID,
  session_id UUID,
  lesson_id UUID,

  direction TEXT NOT NULL,             -- 'JP_KR' | 'KR_JP'
  is_correct BOOLEAN NOT NULL,
  response_ms INTEGER NOT NULL,
  rating SMALLINT NOT NULL,            -- 1~4
  state_before TEXT NOT NULL,          -- SRS 상태
  state_after TEXT NOT NULL,
  distractor_difficulty TEXT,          -- 'EASY' | 'MEDIUM' | 'HARD'

  is_provisional_phase BOOLEAN NOT NULL DEFAULT FALSE,
  is_new_card BOOLEAN NOT NULL DEFAULT FALSE,
  reviewed_on DATE NOT NULL,           -- 유저 로컬 날짜 (daily_new_cap용)

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- 월별 파티션 예시
CREATE TABLE review_events_2026_03 PARTITION OF review_events
  FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

CREATE INDEX idx_review_events_user ON review_events (user_id, created_at DESC);
CREATE INDEX idx_review_events_user_day ON review_events (user_id, reviewed_on)
  WHERE is_new_card = TRUE;
```

---

## 4. 기존 테이블 변경

### user_vocab_progress 확장

```sql
ALTER TABLE user_vocab_progress
  -- SRS 상태 (신규)
  ADD COLUMN IF NOT EXISTS state TEXT NOT NULL DEFAULT 'UNSEEN',
  ADD COLUMN IF NOT EXISTS introduced_by TEXT,              -- 'LESSON' | 'QUIZ'
  ADD COLUMN IF NOT EXISTS learning_step SMALLINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS source_lesson_id UUID,

  -- FSRS 필드 (신규, SM-2와 공존)
  ADD COLUMN IF NOT EXISTS fsrs_stability DOUBLE PRECISION NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS fsrs_difficulty DOUBLE PRECISION NOT NULL DEFAULT 5,
  ADD COLUMN IF NOT EXISTS fsrs_last_rating SMALLINT,
  ADD COLUMN IF NOT EXISTS fsrs_reps INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS fsrs_lapses INTEGER NOT NULL DEFAULT 0,

  -- 스케줄러 버전 (SM-2 vs FSRS 분기)
  ADD COLUMN IF NOT EXISTS scheduler_version SMALLINT NOT NULL DEFAULT 1,
  -- 1 = SM-2 (기존), 2 = FSRS

  -- 방향별 통계
  ADD COLUMN IF NOT EXISTS jp_kr_correct INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS jp_kr_total INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS kr_jp_correct INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS kr_jp_total INTEGER NOT NULL DEFAULT 0,

  -- 찍기 위험도
  ADD COLUMN IF NOT EXISTS guess_risk NUMERIC(4,3) NOT NULL DEFAULT 0,

  -- 당일 중복 방지
  ADD COLUMN IF NOT EXISTS last_presented_on DATE;

-- 기존 필드 (유지, SM-2용)
-- ease_factor, interval, next_review_at, streak, mastered → 그대로

CREATE INDEX IF NOT EXISTS idx_uvp_state_due
  ON user_vocab_progress (user_id, state, next_review_at);
CREATE INDEX IF NOT EXISTS idx_uvp_today_seen
  ON user_vocab_progress (user_id, last_presented_on);
```

### user_grammar_progress 확장

```sql
-- user_vocab_progress와 동일한 컬럼 추가 (위 ALTER 참조)
-- 문법과 단어의 SRS 파라미터는 독립 운영
```

### vocabularies 확장 (오답 안전장치)

```sql
ALTER TABLE vocabularies
  ADD COLUMN IF NOT EXISTS meaning_glosses_ko TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS synonym_group_id UUID,
  ADD COLUMN IF NOT EXISTS category_tag TEXT;   -- "색깔", "음식" 등
```

### grammars 확장

```sql
ALTER TABLE grammars
  ADD COLUMN IF NOT EXISTS meaning_glosses_ko TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS synonym_group_id UUID;
```

---

## 5. 챕터 진도 뷰

```sql
CREATE OR REPLACE VIEW user_chapter_progress_v AS
SELECT
  ulp.user_id,
  l.chapter_id,
  COUNT(*) FILTER (WHERE ulp.status = 'COMPLETED') as completed_lessons,
  COUNT(*) as total_lessons,
  BOOL_AND(ulp.status = 'COMPLETED') as all_completed
FROM user_lesson_progress ulp
JOIN lessons l ON l.id = ulp.lesson_id
GROUP BY ulp.user_id, l.chapter_id;
```

---

## 6. SM-2 → FSRS 전환 전략

```
Phase 1: SM-2 유지 + FSRS 필드 추가 + review_events 로깅 시작
  → scheduler_version = 1 (SM-2)
  → 기존 로직 변경 없음
  → review_events에 모든 채점 기록

Phase 2: FSRS 전환 (기능 플래그)
  → scheduler_version = 2 (FSRS)
  → 새 유저부터 FSRS 적용
  → 기존 유저는 플래그로 전환

Phase 3: SM-2 필드 정리
  → ease_factor, interval 등 읽기 전용으로 전환
  → 안정화 후 제거
```

### 기존 데이터 백필

```sql
-- 기존 progress → state 매핑
UPDATE user_vocab_progress SET state = CASE
  WHEN mastered = TRUE THEN 'MASTERED'
  WHEN interval >= 4 THEN 'REVIEW'
  WHEN interval IN (1, 3) THEN 'LEARNING'
  WHEN interval = 0 AND incorrect_count > 0 THEN 'RELEARNING'
  ELSE 'UNSEEN'
END
WHERE state = 'UNSEEN';

-- introduced_by는 기존 데이터는 'QUIZ' 기본값
UPDATE user_vocab_progress SET introduced_by = 'QUIZ'
WHERE introduced_by IS NULL AND state != 'UNSEEN';
```

---

## 7. 마이그레이션 순서

```
Step 1: 스키마 추가 (ALTER + CREATE)
  → 기존 API 영향 없음

Step 2: 백필
  → state 컬럼 매핑
  → meaning_glosses_ko 생성 (meaning_ko에서 파싱)

Step 3: 레슨 콘텐츠 투입
  → chapters, lessons, lesson_item_links 데이터

Step 4: 기능 플래그로 새 로직 활성화
  → 퀴즈 세션 생성 시 state/stability 기반 로직
  → review_events 기록 시작

Step 5: 안정화 후 레거시 정리
  → SM-2 전용 필드 제거
  → study_stages (기존 스테이지) 비활성화
```

---

## 8. review_events 운영

```
보관 정책:
  OLTP: 최근 12~18개월
  아카이브: 이후 Parquet/BigQuery로 이관
  파티션: 월별 detach → export → drop

크기 예측:
  유저당 하루 20~40문항 × 365일 = ~15,000행/년
  1만 유저: ~1.5억 행/년
  → 월별 파티션 필수
```

---

## 미결 사항

### 1. synonym_groups 테이블

동의어 그룹을 별도 테이블로 관리할지, vocabularies.synonym_group_id만으로 충분한지.
현재는 synonym_group_id 컬럼만 추가, 별도 테이블은 필요시 생성.

### 2. 퀴즈 세션 테이블 확장

기존 quiz_sessions에 session_mode, source_lesson_id 등 추가 여부.
레슨 확인 문제도 quiz_sessions에 기록할지, 별도로 할지.

**→ 구현 시 결정**
