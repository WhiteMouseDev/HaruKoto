# 레슨 학습 플로우 설계 (Lesson Flow Design)

> 최종 수정: 2026-03-21
> 상태: 설계 확정
> 작성: Claude Code x Codex (3회 토론)
> 반영 기준: 6 pedagogical steps / 3 UI containers / content_jsonb 재활용 / 백엔드 변경 없음

---

## 0. 설계 원칙

1. 레슨은 **6개 학습 스텝**으로 구성한다.
2. UI는 **3개 컨테이너**(Context / Practice / Result)로 묶는다.
3. 데이터는 기존 `content_jsonb`와 `vocabItems/grammarItems`만 사용한다.
4. 백엔드 API, DB 스키마, 채점 로직은 변경하지 않는다.
5. 신규 인터랙션은 **매칭 게임 1종**만 추가한다.

---

## 1. 전체 플로우

### 1.1 Step-Container 매핑

| Step | 단계명 | 시간 | 사용 데이터 | 컨테이너 |
|------|--------|-----:|-----------|----------|
| 1 | 상황 프리뷰 (Context Priming) | 0:30 | `reading.scene`, `reading.highlights` | A: Context |
| 2 | 가이드 리딩 (Guided Reading) | 2:00 | `reading.script[]` | A: Context |
| 3 | 빠른 이해 체크 (Recognition) | 2:00 | `questions[]` (VOCAB_MCQ, CONTEXT_CLOZE) | B: Practice |
| 4 | 매칭 게임 (Form-Meaning Match) | 2:00 | `vocabItems[]`, `reading.highlights` | B: Practice |
| 5 | 문장 재구성 (Order Recall) | 2:00 | `questions[]` (SENTENCE_REORDER) | B: Practice |
| 6 | 결과 + 복습 연결 | 1:30 | submit 응답, SRS 전이 | C: Result |

> 총 학습 시간: **약 10분**

### 1.2 상태 전이

```
Container A (Context)          Container B (Practice)         Container C (Result)
┌──────────────────────┐      ┌──────────────────────┐      ┌──────────────────────┐
│ Step 1: 상황 프리뷰   │──→   │ Step 3: 이해 체크     │      │ Step 6: 결과         │
│ Step 2: 가이드 리딩   │      │ Step 4: 매칭 게임     │──→   │   점수 / 해설        │
│                      │      │ Step 5: 문장 재구성   │      │   SRS 피드백         │
└──────────────────────┘      └──────────────────────┘      │   다시풀기 / 완료    │
                                                             └──────────────────────┘
```

---

## 2. 각 단계별 상세 설계

### Step 1. 상황 프리뷰 (Context Priming)

**화면**: 상단 진행바 `1/6`, 중앙에 상황 카드 + 핵심 표현 칩, 하단 CTA "대화 시작"

**인터랙션**: 탭 → Step 2

**데이터**: `content.reading.scene`, `content.reading.highlights[]`

**목적**: 학습 맥락 활성화 (스키마 프라이밍). "오늘 뭘 배우는지" 30초 안에 전달.

---

### Step 2. 가이드 리딩 (Guided Reading)

**화면**: 대화 버블 리스트 (화자/원문/번역), 번역 표시/숨김 토글

**인터랙션**: 스크롤 + 번역 토글 + CTA "이해 체크로 이동"

**데이터**: `content.reading.script[].speaker/text/translation`

**목적**: 맥락 속에서 자연스러운 입력(Comprehensible Input). 번역 숨김으로 능동적 읽기 유도.

---

### Step 3. 빠른 이해 체크 (Recognition Check)

**화면**: 4지선다 / 빈칸 채우기 문제 카드

**인터랙션**: 선택지 탭, 400ms 후 다음 문항

**데이터**: `content.questions[]` 중 `VOCAB_MCQ`, `CONTEXT_CLOZE`

**목적**: 인식형 능동 회상 (Recognition Recall). 방금 읽은 내용에서 핵심 단어/문법 확인.

---

### Step 4. 매칭 게임 (Form-Meaning Match) [신규]

**화면**: 좌측 일본어 카드 4개, 우측 한국어 카드 4개

**인터랙션**: 탭-탭 매칭 (좌 1개 선택 → 우 1개 선택 → 정답이면 사라짐)

**데이터**: `vocabItems[].word/reading/meaningKo`

**목적**: 형태-의미 연결 강화. 게이미피케이션 요소 (콤보, 속도). 가장 "재미있는" 단계.

**MVP 규칙**:
- 4쌍 고정 (vocabItems에서 4개 선택)
- 오매칭 시 즉시 리셋 (페널티 없음)
- 전부 매칭 완료 → 자동 다음 단계

---

### Step 5. 문장 재구성 (Order Recall)

**화면**: 토큰 배열 영역 + 토큰 뱅크

**인터랙션**: 토큰 탭으로 순서 배치, 전부 선택 시 자동 제출

**데이터**: `content.questions[]` 중 `SENTENCE_REORDER`

**목적**: 생산형 능동 회상 (Production Recall). 문장 구조 이해 확인. 난이도 최고.

---

### Step 6. 결과 + 복습 연결

**화면**: 점수 %, 문항별 정오/해설, SRS 상태 전이, "다시 풀기" / "완료"

**인터랙션**: 결과 확인 + CTA

**데이터**: `submitLesson()` 응답

**목적**: 자기설명(Self-Explanation) + 복습 예약 인지. "24시간 후 복습 예정" 표시.

---

## 3. 인지과학 근거

### 3.1 단계 순서 근거

| 순서 | 원리 | 적용 |
|------|------|------|
| Step 1→2 | **스키마 활성화** — 맥락을 먼저 제시하면 새 정보 처리 비용 감소 | 상황 → 대화문 |
| Step 3 | **인식형 회상** — 가장 쉬운 형태의 Active Recall | 4지선다 |
| Step 4 | **형태-의미 연결** — 양방향 연결 강화 | 매칭 게임 |
| Step 5 | **생산형 회상** — 가장 어려운 형태의 Active Recall | 문장 재구성 |
| Step 6 | **자기설명 효과** — 결과 회고가 장기 기억 전이를 촉진 | 해설 + SRS |

### 3.2 인지 부하 관리

- 10분을 6개 마이크로 스텝으로 분절 → 작업 기억 부하 최소화
- 각 스텝은 **단일 과제**만 수행
- 번역/해설은 **필요한 시점**에만 노출 (적시 제공)

### 3.3 Active Recall 적용

| Step | 회상 유형 | 난이도 |
|------|----------|--------|
| 3 | 인식 (Recognition) | 낮음 |
| 4 | 연결 (Association) | 중간 |
| 5 | 생산 (Production) | 높음 |

→ **난이도 래더**: 쉬운 것 → 어려운 것 순서로 자신감 유지

### 3.4 SRS 연계

- Step 6 제출 시 기존 `submitLesson` → `process_answer()` → `register_items_from_lesson()`
- 프론트 플로우만 변경, SRS 엔진은 그대로

---

## 4. MVP vs Full Version

| 구분 | MVP (프론트엔드만) | Full Version |
|------|-------------------|-------------|
| 플로우 | 6 Step / 3 Container | + 적응형 난이도 |
| 신규 인터랙션 | 매칭 게임 (탭-탭) | + 드래그 매칭, 고급 피드백 |
| 데이터 | 기존 content_jsonb | + 확장 메타 |
| 음성 | 미적용 | TTS 대사 재생 |
| 입력 | 선택/탭 중심 | + 타이핑 모드 |
| 연출 | 최소 전환 | + 모션/햅틱/사운드 |
| 백엔드 | 변경 없음 | 필요 시 확장 |

---

## 5. 기존 코드 매핑

### 5.1 현재 phase 구조 (lesson_page.dart)

```
phase 0 → _ReadingPhase (대화문 + 단어 + 문법 + "확인 문제 풀기")
phase 1 → _QuizPhase (_MultipleChoiceQuiz + _SentenceReorderQuiz)
phase 2 → _ResultPhase (점수 + 문항별 결과)
```

### 5.2 변경될 phase/step 구조

```
phase 0 (Container A: Context)
  step 0 → Step 1: 상황 프리뷰 (신규)
  step 1 → Step 2: 가이드 리딩 (_DialogueBubble 재사용)

phase 1 (Container B: Practice)
  step 2 → Step 3: 이해 체크 (_MultipleChoiceQuiz 재사용)
  step 3 → Step 4: 매칭 게임 (신규 위젯)
  step 4 → Step 5: 문장 재구성 (_SentenceReorderQuiz 재사용)

phase 2 (Container C: Result)
  step 5 → Step 6: 결과 (_ResultPhase 재사용)
```

### 5.3 재사용 위젯

| 위젯 | 사용 Step | 수정 필요 |
|------|----------|----------|
| `_DialogueBubble` | Step 2 | 없음 |
| `_MultipleChoiceQuiz` | Step 3 | 없음 |
| `_SentenceReorderQuiz` | Step 5 | 없음 |
| `_ResultPhase` | Step 6 | 없음 |
| **신규: `_MatchingGame`** | Step 4 | 새로 작성 |
| **신규: `_ContextPreview`** | Step 1 | 새로 작성 |

---

## 6. PM 검수 포인트

```
□ 각 스텝 전환이 자연스러운가?
□ 진행바가 6단계를 명확히 표시하는가?
□ 매칭 게임이 직관적인가? (탭-탭 vs 드래그)
□ 번역 숨김/표시가 학습자 수준에 맞는가?
□ 전체 10분 안에 완료 가능한가?
□ "다시 풀기"가 Step 1부터 재시작하는가?
```
