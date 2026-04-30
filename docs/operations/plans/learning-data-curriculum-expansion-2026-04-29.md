# 학습 데이터 커리큘럼 확장 계획

> 작성일: 2026-04-29
> 상태: Draft
> 범위: PDF 001-102 주제 커버리지, N5-N1 학습 데이터 고도화, 레슨/문법/문항 데이터 계약 확장

## 1. 목표

HaruKoto 학습 데이터를 N5 파일럿 중심 구조에서 N1까지 확장 가능한 커리큘럼 자산으로 고도화한다.

핵심 목표는 다음과 같다.

- PDF 001-102의 모든 학습 주제를 HaruKoto 커리큘럼 안에서 커버한다.
- PDF 원문, 설명문, 예문, 문항은 복제하지 않는다.
- 예문, 대화, 문항, 해설은 HaruKoto 톤과 한국어 학습자 기준으로 새로 제작한다.
- N5 파일럿 레슨과 SRS 흐름은 깨지지 않게 유지한다.
- N4-N1 확장을 위해 주제, 문법, 예문, 문항, 한자/읽기, 레지스터를 별도 운영 단위로 관리한다.

ASSUMPTION: PDF 자료는 유료 구매 자료지만, 제품 데이터에는 원문을 직접 복제하지 않고 커버리지와 난이도 분류 참고 자료로만 사용한다.

ASSUMPTION: 단기 우선순위는 N5 파일럿 품질 보강이며, N4-N1은 동일 데이터 계약으로 확장 가능한 구조를 먼저 설계한다.

## 2. 현재 기반

현재 학습 데이터는 다음 구조를 갖고 있다.

- `vocabularies`: 단어, 읽기, 한국어 뜻, 예문, 품사, 태그, JLPT 레벨
- `grammars`: 문법 패턴, 한국어 의미, 설명, 예문 JSON, 관련 문법
- `chapters` / `lessons`: 레벨별 챕터와 레슨 메타데이터
- `lesson_item_links`: 레슨과 단어/문법 기준 데이터 연결
- `lessons.content_jsonb`: reading script와 questions를 담는 레슨별 JSONB
- `user_lesson_progress`: 레슨 진행과 SRS 등록 상태
- `review_events`: SRS 복습 이벤트 로그

현재 구조는 N5 파일럿처럼 단어, 문법, 대화, 5문항을 묶은 10분 레슨에는 적합하다. 다만 N1까지 확장하려면 "문법/어휘 항목"과 "레슨" 사이에 커리큘럼 주제와 지식 그래프가 추가로 필요하다.

## 3. PDF 커버리지 정의

"PDF 내용을 전부 포함한다"는 아래 의미로 고정한다.

- 모든 PDF 주제를 내부 커리큘럼 topic으로 등록한다.
- 각 topic을 `입문`, `N5`, `N4`, `N3`, `N2`, `N1`, `회화/문체 보강` 중 하나 이상으로 태깅한다.
- 기존 단어/문법/레슨으로 이미 커버되는지 `covered`, `partial`, `missing`, `deferred` 상태로 관리한다.
- 원문 예문이 아니라 새 예문과 새 문항으로 재구성한다.
- 앱에 노출되는 콘텐츠에는 PDF 출처나 문구를 노출하지 않는다.

초기 분류는 다음 방식으로 진행한다.

| PDF 범위 | 1차 성격 | 처리 방향 |
|---|---|---|
| 001 | 문자, 발음, 가나 | Absolute Zero / Kana 트랙 보강 |
| 006-027 | 초급 대명사, 지시어, です, 조사, 형용사, 동사 기초 | N5 우선 매핑 |
| 028-050 | て형 응용, 수수, 희망, 복합 표현 | N5 후반-N4 후보 |
| 051-068 | 과거, 조건, 경험, 의무, 이유 | N5/N4/N3 혼재 분류 |
| 069-096 | 가능, 명령, 의지, 수동, 사역, 추측, 조건 | N4-N3 중심 |
| 097-102 | 회화 축약, 문체, 경어 | N3+ / 회화 / 비즈니스 후보 |

## 4. 추가해야 할 운영 단위

### 4.1 Curriculum Topic

PDF 주제, JLPT 문법, HaruKoto 레슨을 연결하는 중심 단위다.

권장 필드:

```json
{
  "topicId": "topic-n4-passive",
  "titleKo": "동사의 수동형",
  "canonicalPattern": "受身形 〜(ら)れる",
  "topicType": "grammar",
  "inferredJlptLevel": "N4",
  "levelConfidence": "medium",
  "sourceRefs": [{"type": "pdf", "ref": "080"}],
  "coverageStatus": "partial",
  "mappedGrammarOrders": [{"level": "N4", "order": 26}],
  "mappedLessonIds": [],
  "prerequisiteTopicIds": ["topic-n5-verb-groups", "topic-n5-te-ta-forms"],
  "contrastTopicIds": ["topic-n4-causative", "topic-n4-causative-passive"],
  "notesKo": "한국어 피동 표현과 1:1 대응하지 않는 예외를 별도 설명한다."
}
```

이 레이어가 있어야 PDF 커버리지 100%, 레벨별 누락, 선후행 관계, 문법 비교를 운영할 수 있다.

### 4.2 Grammar Metadata v2

N4 이상부터는 단순 `pattern + meaning + explanation`만으로 부족하다.

추가 후보:

- `formation`: 접속 규칙과 활용 형태
- `formationExamples`: 활용 예시
- `usageNoteKo`: 언제 쓰는지
- `nuanceKo`: 뉘앙스, 격식, 구어/문어 구분
- `commonMistakesKo`: 한국어 학습자가 자주 틀리는 점
- `koreanComparisonKo`: 한국어 표현과의 차이
- `contrastPatterns`: 비슷한 문법과 비교
- `prerequisiteGrammarIds`: 선행 문법
- `register`: polite, casual, written, honorific, humble 등
- `productiveForms`: 변환 훈련 가능한 형태

ASSUMPTION: 이 필드는 바로 DB 컬럼으로 추가하기보다, 먼저 JSON 계약과 seed pipeline에서 검증한 뒤 DB 반영 여부를 결정한다.

### 4.3 Example Bank

예문은 단어/문법 안에 1-2개만 두면 N1까지 확장하기 어렵다. 별도 예문 bank가 필요하다.

권장 필드:

```json
{
  "exampleId": "ex-n4-passive-001",
  "japanese": "駅で財布を盗まれました。",
  "reading": "えきでさいふをぬすまれました。",
  "korean": "역에서 지갑을 도난당했습니다.",
  "linkedTopicIds": ["topic-n4-passive"],
  "linkedGrammarIds": [],
  "linkedVocabularyIds": [],
  "jlptLevel": "N4",
  "difficulty": 3,
  "register": "polite",
  "domainTags": ["일상", "문제상황"],
  "skillTags": ["grammar_application", "reading"],
  "reviewStatus": "needs_review"
}
```

예문 bank는 다음에 쓰인다.

- 문법 카드 예문
- 레슨 대화 생성 재료
- 클로즈 문항
- 문장 배열 문항
- 듣기/TTS 문항
- AI 회화 시나리오 anchor

### 4.4 Question Schema v2

현재 레슨 문항은 `VOCAB_MCQ`, `CONTEXT_CLOZE`, `SENTENCE_REORDER` 중심이다. N1까지 가려면 문항 타입과 평가 축을 확장해야 한다.

추가 문항 타입 후보:

- `READING_MCQ`: 문장/짧은 글 의미 선택
- `GRAMMAR_FORM`: 활용형 변환
- `PARTICLE_CHOICE`: 조사 선택
- `PATTERN_CHOICE`: 문법 패턴 선택
- `NUANCE_MCQ`: 유사 문법 뉘앙스 구분
- `REGISTER_CHOICE`: 정중체/보통체/경어 선택
- `ERROR_CORRECTION`: 오류 수정
- `SHORT_PRODUCTION`: 제한된 부분 산출
- `LISTENING_MCQ`: TTS 기반 듣기 선택

권장 공통 필드:

```json
{
  "schemaVersion": 2,
  "type": "NUANCE_MCQ",
  "skill": "grammar_contrast",
  "targetTopicIds": ["topic-n4-souda-hearsay", "topic-n4-souda-appearance"],
  "difficulty": 4,
  "promptKo": "문맥에 맞는 표현을 고르세요.",
  "stemJapanese": "空が暗いですね。雨が___。",
  "options": [
    {"id": "a", "text": "降りそうです", "rationaleKo": "하늘을 보고 추측하는 양태 표현"},
    {"id": "b", "text": "降るそうです", "rationaleKo": "전해 들은 정보에 쓰는 표현"}
  ],
  "correctAnswer": "a",
  "explanationKo": "눈앞의 상태를 보고 추측할 때는 そうです(양태)를 쓴다."
}
```

### 4.5 Kanji / Reading Scaffold

N1까지 고려하면 한자와 후리가나 정책이 별도 축이어야 한다.

추가 운영 단위:

- `kanji_items`: 한자, 음독, 훈독, 의미, 예시 단어, JLPT 레벨
- `reading_policy`: 레벨/숙련도별 후리가나 표시 정책
- `orthography_variants`: 가나 표기, 한자 표기, 혼용 표기
- `furigana_fade_stage`: always, first_seen, on_tap, hidden

N5는 후리가나를 충분히 제공하되, N4부터는 점진적으로 제거하는 정책이 필요하다.

### 4.6 Register / Style Track

후반 PDF에는 회화체 축약, 경어, 겸양어, 문체 표현이 들어간다. 이것은 단순 JLPT 문법보다 사용 맥락이 중요하다.

추가 축:

- `register`: polite, casual, formal, written, honorific, humble
- `relationshipContext`: friend, teacher, customer, workplace, public
- `riskLevel`: 틀렸을 때 무례하게 들리는 정도
- `safeDefault`: 초급자에게 추천할 기본 표현

경어/겸양어는 N3+ 또는 별도 비즈니스/회화 트랙으로 분리하는 것이 좋다.

### 4.7 Can-do / Skill Taxonomy

레슨을 문법 번호가 아니라 실제 수행 능력으로도 추적해야 한다.

권장 skill 축:

- `recognition`: 읽고 의미를 알아본다.
- `form_recall`: 활용형을 만들 수 있다.
- `context_selection`: 상황에 맞는 표현을 고른다.
- `sentence_building`: 문장을 조립한다.
- `contrast`: 비슷한 문법을 구분한다.
- `listening`: 듣고 인식한다.
- `conversation`: 회화에서 사용할 수 있다.

레슨에는 `canDoStatementKo`를 추가한다.

예:

```json
{
  "canDoStatementKo": "상대에게 정중하게 허락을 구할 수 있다.",
  "targetSkills": ["context_selection", "sentence_building"],
  "targetTopicIds": ["topic-n5-temo-ii-desu-ka"]
}
```

### 4.8 Content Provenance / Review

PDF를 참고하더라도 제품 데이터는 새로 제작해야 하므로, 내부 provenance와 review 상태가 필요하다.

권장 필드:

- `sourceRefs`: 내부 참고 자료 번호, 공개 데이터셋, 직접 제작 여부
- `copyrightRisk`: low, medium, high
- `generationMethod`: human, ai_assisted, imported_public_dataset
- `reviewStatus`: needs_review, approved, rejected
- `reviewNotes`
- `reviewedBy`
- `approvedAt`

앱에는 노출하지 않는 내부 운영 메타데이터다.

### 4.9 Audio / TTS Readiness

학습 데이터 고도화는 텍스트만 다루면 안 된다. 현재 서비스에는 vocabulary/kana/admin TTS와 모바일 재생 경로가 이미 있고, 레슨 대화문 TTS는 별도 갭으로 기록되어 있다. 따라서 새 topic, 예문, 문항, 레슨 대화는 처음부터 TTS 생성 가능성을 포함해야 한다.

운영 단위:

- `ttsTargets`: 어떤 필드가 음성 생성 대상인지 지정한다.
- `voiceId`: 레슨 대화 script line에 사용할 화자 음성 식별자다.
- `audioTargetType`: vocabulary, grammar, kana, lesson_script, example_sentence, question_prompt 등이다.
- `audioField`: word, reading, example_sentence, pattern, sentence, script_line 등이다.
- `audioCacheKey`: provider/model/speed/field/text hash를 포함해 재생성 충돌을 막는다.
- `generationStatus`: missing, generated, approved, rejected, stale 중 하나다. 기존 콘텐츠 검수용 `reviewStatus`와 분리한다.

예:

```json
{
  "audioPolicy": {
    "ttsTargets": ["japanese", "reading"],
    "defaultSpeed": 1,
    "requiredBeforePublish": false,
    "preferredVoiceId": "japanese_female_1",
    "audioTargetType": "example_sentence"
  }
}
```

레벨별 원칙:

| 영역 | TTS 정책 |
|---|---|
| Kana / Absolute Zero | 문자 단위 발음 TTS 또는 사전 생성 음성 우선 |
| Vocabulary | word/reading 기본, 예문은 선택 |
| Grammar | pattern은 짧은 경우만, example sentence 우선 |
| Lesson script | line 단위 `lesson_script` target으로 생성 |
| Question | listening 문항에서 prompt/stem audio 필수 |
| N2-N1 Reading | 긴 지문 전체 TTS보다 문장/문단 단위 분할 권장 |

ASSUMPTION: Wave 0에서는 TTS 음성을 생성하지 않는다. 대신 향후 생성 대상과 캐시 키가 안정적으로 계산되도록 JSON 계약에 audio policy를 포함한다.

## 5. N1까지 고려한 레벨별 설계

| 레벨 | 학습 초점 | 데이터 확장 포인트 |
|---|---|---|
| Absolute Zero | 문자, 발음, 가나, 기본 인사 | kana scaffold, 발음 주의, TTS |
| N5 | 기초 문장 구조, 정중형, 조사, 기본 동사/형용사 | topic inventory, 레슨 v2, SRS 안정화 |
| N4 | て형 응용, 조건, 수수, 수동/사역, 추측 | formation, contrast, common mistakes |
| N3 | 복합 문형, 접속, 문맥 의미, 구어/문어 차이 | nuance, register, discourse functions |
| N2 | 추상 표현, 문어체, 논리 연결, 독해 밀도 | reading passages, grammar contrast, formal style |
| N1 | 고급 문어체, 관용적 문형, 담화/논설 독해 | discourse tags, advanced register, long-form reading |

N1까지 가려면 레슨이 항상 10분 단위일 필요는 없다. 초급은 micro lesson 중심, N2-N1은 독해/담화 중심 모듈을 별도로 둘 수 있어야 한다.

## 6. 추천 구현 순서

### Phase 1. 문서/JSON 계약

- PDF topic inventory 작성
- `curriculum_topics` JSON 초안 생성
- 기존 N5/N4/N3 grammar와 topic 매핑
- coverage 상태 `covered / partial / missing / deferred` 부여

### Phase 2. N5 파일럿 보강

- N5 topic 누락/partial 항목 찾기
- 기존 30개 레슨의 `learning_objectives`, `targetTopicIds`, `targetSkills` 보강
- 문법 설명에 formation, usage note, common mistakes 후보 추가
- 예문은 새로 작성하고 PDF 예문은 사용하지 않음

### Phase 3. 데이터 계약 v2

- `GrammarMetadataV2` JSON schema 정의
- `ExampleBank` JSON schema 정의
- `QuestionSchemaV2` 정의
- `AudioPolicy` / `TtsTarget` JSON 계약 정의
- lesson quality gate에 v2 필드 검증 추가

### Phase 4. API/Mobile 호환 확장

- API는 v1 레슨을 계속 지원한다.
- v2 필드는 optional로 내려준다.
- 모바일은 v2 필드가 있을 때만 문법 접속 규칙, 예문, 주의점을 표시한다.
- 기존 N5 레슨이 깨지지 않는 fallback을 유지한다.

### Phase 5. DB 정규화 여부 결정

JSON 기반 운영으로 검증한 뒤, 조회/관리/어드민 필요가 분명한 것만 DB 테이블로 승격한다.

테이블 승격 후보:

- `curriculum_topics`
- `example_sentences`
- `content_source_refs`
- `topic_item_links`
- `question_bank`
- `kanji_items`
- `tts_audio` 확장 또는 `audio_assets`

## 7. 품질 게이트 확장

현재 레슨 검증은 구조와 일부 품질 휴리스틱을 확인한다. N1까지 확장하려면 아래 게이트가 추가로 필요하다.

| 게이트 | 목적 |
|---|---|
| Coverage Gate | PDF topic이 모두 mapped/covered/deferred 중 하나인지 확인 |
| Level Gate | N5 레슨에 N3+ topic이 섞이지 않았는지 확인 |
| Prerequisite Gate | 선행 topic 없이 고급 topic이 등장하지 않는지 확인 |
| Example Originality Gate | 외부 자료와 과도하게 유사한 예문/설명 방지 |
| Register Gate | 경어/반말/문어체 표현에 사용 맥락이 있는지 확인 |
| Contrast Gate | 유사 문법 묶음에 비교 설명이 있는지 확인 |
| Question Balance Gate | 인식형 문제에 치우치지 않고 적용/산출/비교 문항이 포함되는지 확인 |
| Korean Learner Gate | 한국어 화자 오류 포인트가 문법 설명에 반영되는지 확인 |
| Audio Readiness Gate | publish 대상 콘텐츠의 TTS target, voice_id, generationStatus가 추적되는지 확인 |

## 8. Wave 1 Seed Candidate Staging

Wave 1에서는 `WAVE_1_N5_PATCH` 중 P0 주제를 곧바로 공식 lesson seed로 넣지 않는다. 대신 `packages/database/data/curriculum/lesson-seed-candidates.json`에 seed-shaped draft로 두고, 공식 `data/lessons/**` 승격 전 아래 조건을 통과시킨다.

- `lessonBlueprintId`, `sourceTopicIds`, `exampleIds`가 기존 curriculum 계약과 연결된다.
- `seedShape`는 현재 lesson runtime이 처리 가능한 `VOCAB_MCQ`, `CONTEXT_CLOZE`, `SENTENCE_REORDER` 문항만 포함한다.
- reading script에는 line 단위 `speaker`, `voice_id`, `text`, `translation`을 포함해 TTS 후보로 추적 가능해야 한다.
- vocabulary order와 grammar order는 현재 seed 데이터에 존재하는 항목만 참조한다.
- candidate 상태와 promotion target은 `DRAFT`로 유지한다.
- PDF 원문/예문은 포함하지 않고 HaruKoto 신규 예문과 문항만 사용한다.

현재 `WAVE_1_N5_PATCH` P0 22개 topic은 모두 example-bank 예문을 가진다. 그중 seed-shaped draft로 승격한 후보는 PDF 006-014, PDF 023, PDF 025-026, PDF 035-036, PDF 043 범위의 N5 보강 후보 14개다.

| Candidate | Topic | Promotion target | Runtime question types |
|---|---|---|---|
| `lsc-personal-pronouns-001` | `topic-personal-pronouns` | N5 lesson 31 draft | `VOCAB_MCQ`, `CONTEXT_CLOZE`, `SENTENCE_REORDER` |
| `lsc-demonstratives-001` | `topic-demonstratives` | N5 lesson 32 draft | `VOCAB_MCQ`, `CONTEXT_CLOZE`, `SENTENCE_REORDER` |
| `lsc-nominal-negative-001` | `topic-nominal-negative` | N5 lesson 33 draft | `VOCAB_MCQ`, `CONTEXT_CLOZE`, `SENTENCE_REORDER` |
| `lsc-basic-particles-001` | `topic-basic-particles` | N5 lesson 34 draft | `VOCAB_MCQ`, `CONTEXT_CLOZE`, `SENTENCE_REORDER` |
| `lsc-greetings-001` | `topic-greetings` | N5 lesson 35 draft | `VOCAB_MCQ`, `CONTEXT_CLOZE`, `SENTENCE_REORDER` |
| `lsc-numbers-and-counters-001` | `topic-numbers-and-counters` | N5 lesson 36 draft | `VOCAB_MCQ`, `CONTEXT_CLOZE`, `SENTENCE_REORDER` |
| `lsc-time-and-weekdays-001` | `topic-time-and-weekdays` | N5 lesson 37 draft | `VOCAB_MCQ`, `CONTEXT_CLOZE`, `SENTENCE_REORDER` |
| `lsc-onegai-shimasu-001` | `topic-onegai-shimasu` | N5 lesson 38 draft | `VOCAB_MCQ`, `CONTEXT_CLOZE`, `SENTENCE_REORDER` |
| `lsc-aru-iru-existence-001` | `topic-aru-iru-existence` | N5 lesson 39 draft | `VOCAB_MCQ`, `CONTEXT_CLOZE`, `SENTENCE_REORDER` |
| `lsc-verb-groups-001` | `topic-verb-groups` | N5 lesson 40 draft | `VOCAB_MCQ`, `CONTEXT_CLOZE`, `SENTENCE_REORDER` |
| `lsc-polite-form-applications-001` | `topic-polite-form-applications` | N5 lesson 41 draft | `VOCAB_MCQ`, `CONTEXT_CLOZE`, `SENTENCE_REORDER` |
| `lsc-no-functions-001` | `topic-no-functions` | N5 lesson 42 draft | `VOCAB_MCQ`, `CONTEXT_CLOZE`, `SENTENCE_REORDER` |
| `lsc-verb-connection-forms-001` | `topic-verb-connection-forms` | N5 lesson 43 draft | `VOCAB_MCQ`, `CONTEXT_CLOZE`, `SENTENCE_REORDER` |
| `lsc-te-iru-progress-state-001` | `topic-te-iru-progress-state` | N5 lesson 44 draft | `VOCAB_MCQ`, `CONTEXT_CLOZE`, `SENTENCE_REORDER` |

아직 seed-shaped draft로 승격하지 않은 P0 topic은 다음 8개다.

- `topic-kana-hiragana`, `topic-kanji-reading-basics`: kana/kanji scaffold에 가까워 현재 grammar-linked seed shape와 분리한다.
- `topic-shiru-wakaru`: 어휘/문맥 선택 중심 topic이라 전용 contrast 문항 정책을 먼저 정한다.
- `topic-hoshii`, `topic-ku-naru-ni-naru`, `topic-ni-suru`: N5 도입과 N4 확장 용법이 섞여 있어 grammar metadata v2에서 범위를 분리한다.
- `topic-dake`, `topic-toiu`: 현재 grammar JSON에 전용 N5 row가 없어 anchor 정책을 확정한 뒤 승격한다.

이 8개는 방치하지 않고 별도 staging 계약으로 추적한다.

| Contract | Purpose | Covered P0 topics |
|---|---|---|
| `scaffold-candidates.json` | grammar order 없이 kana/kanji scaffold를 검수한다. | `topic-kana-hiragana`, `topic-kanji-reading-basics` |
| `grammar-metadata-v2.json` | formation, nuance, 한국어 학습자 오류, N5/N4+ 분리를 검수한다. | `topic-hoshii`, `topic-ku-naru-ni-naru`, `topic-dake`, `topic-ni-suru`, `topic-toiu` |
| `topic-anchor-policies.json` | seed candidate 전 필요한 anchor 결정을 기록한다. | 위 2개를 포함한 미승격 P0 8개 전체 |
| `contrast-question-policies.json` | seed candidate 작성 전 어휘/문법 대비 문항 기준과 TTS 검수 대상을 고정한다. | `topic-shiru-wakaru`, `topic-hoshii`, `topic-ku-naru-ni-naru`, `topic-dake`, `topic-ni-suru`, `topic-toiu` |

Anchor route는 다음 네 가지로 제한한다.

| Route | 사용 조건 |
|---|---|
| `scaffold_candidate` | kana/kanji처럼 grammar-linked lesson shape가 맞지 않는 경우 |
| `vocab_skill_candidate` | `知る/分かる`처럼 어휘와 문맥 선택이 핵심인 경우 |
| `new_grammar_metadata_v2` | N5 전용 grammar metadata가 아직 없는 경우 |
| `split_grammar_metadata_v2` | N5 도입 용법과 N4+ 확장 용법을 분리해야 하는 경우 |

ASSUMPTION: 후보 lesson을 공식 seed 파일로 승격하기 전에는 admin review, mobile playback, API seed publish 정책을 별도 확인한다.
ASSUMPTION: 숫자, 시간, 부탁 표현처럼 전용 grammar row가 없는 후보는 promotion 호환성을 위해 가장 가까운 기존 N5 grammar order를 anchor로 사용하고, 전용 grammar metadata는 후속 확장으로 분리한다.
ASSUMPTION: anchor policy가 `blocked`인 topic은 공식 lesson seed로 승격하지 않는다. 먼저 grammar metadata v2, contrast question policy, 또는 scaffold review를 통과해야 한다.

현재 `grammar-metadata-v2.json`에는 9개 metadata가 있다.

- N5: `gmv2-n5-noun-ga-hoshii`, `gmv2-n5-i-adj-ku-naru`, `gmv2-n5-na-noun-ni-naru`, `gmv2-n5-dake-limitation`, `gmv2-n5-choice-ni-suru`, `gmv2-n5-toiu-naming`
- N4+: `gmv2-n4-te-hoshii`, `gmv2-n4-koto-ni-suru`, `gmv2-n3-toiu-quotation`

Metadata가 채워진 anchor policy 5개는 `grammar_metadata_v2` blocker를 해소하고 `ready_for_candidate` 상태가 된다. 추가로 `contrast-question-policies.json`이 6개 contrast 정책을 제공하면서 `contrast_question_policy` blocker도 해소했다.

- `topic-shiru-wakaru`: N5 vocabulary order 393 `知る`와 122 `分かる`를 대비한다.
- `topic-hoshii`: N5 명사 욕구와 N4 `Vてほしい`를 분리한다.
- `topic-ku-naru-ni-naru`: い형용사 `くなる`와 な형용사/명사 `になる`를 분리한다.
- `topic-dake`: N5 `だけ` 제한 표현과 기존 N5 grammar 33 `も`를 대비한다.
- `topic-ni-suru`: N5 명사 선택 `にする`와 N4 `ことにする`를 분리한다.
- `topic-toiu`: N5 명칭 `という`과 N3+ 인용 `という`을 분리한다.

이 6개 topic은 이제 `ready_for_candidate`이며 `lesson-seed-candidates.json`에 lesson 45-50 draft 후보로 승격했다.

| Lesson candidate | Topic | 남은 gate |
|---|---|---|
| `lsc-shiru-wakaru-001` | `topic-shiru-wakaru` | runtime question review, TTS readiness, human curriculum review |
| `lsc-hoshii-001` | `topic-hoshii` | TTS readiness, human curriculum review |
| `lsc-ku-naru-ni-naru-001` | `topic-ku-naru-ni-naru` | TTS readiness, human curriculum review |
| `lsc-dake-001` | `topic-dake` | TTS readiness, human curriculum review |
| `lsc-ni-suru-001` | `topic-ni-suru` | TTS readiness, human curriculum review |
| `lsc-toiu-001` | `topic-toiu` | TTS readiness, human curriculum review |

Anchor policy는 이제 미승격 blocker만이 아니라 draft seed candidate를 만든 근거로도 남긴다. validator는 anchor, contrast policy, seed candidate가 같은 topic, lesson blueprint, example을 가리키는 경우에만 이 공존을 허용한다.

TTS readiness도 seed candidate 단위로 확장했다. `tts-target-manifest.json`은 이제 498개 target을 추적한다.

- topic/example 기반 target: 320개
- lesson seed candidate 기반 target: 178개
- seed script line target: 78개
- seed question prompt target: 100개

validator는 `AudioReadinessGate`가 있는 모든 seed candidate에 대해 reading script line과 question prompt마다 `lesson-seed-candidates:<candidateId>:script:<order>` 또는 `lesson-seed-candidates:<candidateId>:question:<order>` target이 있는지 확인한다.

`tts-review-batches.json`은 498개 target을 7개 review/export batch로 묶는다. 현재 admin/backend TTS 경로가 직접 지원하는 batch와, admin/API 확장이 필요한 batch를 분리해 TTS 생성 순서를 고정한다.

| Batch | 대상 수 | Review surface | Export 상태 |
|---|---:|---|---|
| `tts-review-admin-vocabulary-fields` | 18 | `admin_existing_tts` | vocabulary `word`, `reading`, `example_sentence` |
| `tts-review-admin-grammar-fields` | 156 | `admin_existing_tts` | grammar `pattern`, `example_sentences` |
| `tts-review-gap-grammar-question-prompts` | 78 | `admin_extension_required` | `admin_tts_field_gap` |
| `tts-review-gap-kana-fields` | 3 | `admin_extension_required` | `admin_content_type_gap` |
| `tts-review-gap-example-sentence-fields` | 65 | `admin_extension_required` | `admin_content_type_gap` |
| `tts-review-gap-seed-script-lines` | 78 | `admin_extension_required` | `lesson_seed_admin_surface_gap` |
| `tts-review-gap-seed-question-prompts` | 100 | `admin_extension_required` | `lesson_seed_admin_surface_gap` |

ASSUMPTION: 이번 단계의 TTS review/export 계약은 아직 생성 action이 아니다. Read-only Admin UI/API는 검토용으로 연결했지만, 기존 `apps/admin` TTS field와 `apps/api` admin TTS service를 통한 batch 생성/쓰기 확장은 후속 단계에서 다룬다.

Read-only admin backend 연결도 추가했다. `GET /api/v1/admin/content/tts/review-batches`는 생성된 `tts-review-batches.json`을 읽어 reviewer 전용 응답으로 반환한다.

- `summary.totalTargets`: 498
- `summary.adminReadyTargets`: 174
- `summary.extensionRequiredTargets`: 324
- `review_surface=admin_existing_tts` query로 현재 admin TTS 필드에 연결 가능한 batch만 조회할 수 있다.

ASSUMPTION: 이 endpoint는 검토/대시보드용 조회 계약이다. 실제 batch 기반 TTS 생성, `tts_audio` 쓰기, GCS 업로드, admin bulk action은 후속 구현에서 별도로 다룬다.
API 배포 이미지에서도 이 endpoint가 동작하도록 `curriculum:derive`는 동일한 review batch 계약을 `apps/api/app/data/curriculum/tts-review-batches.json`에 번들 사본으로 생성한다. source-of-truth는 계속 `packages/database/data/curriculum/tts-review-batches.json`이며, 운영 데이터로 승격하는 시점에는 같은 계약을 DB/스토리지로 옮기고 번들 사본을 제거할 수 있다.

Batch별 target drilldown도 read-only로 연결했다. `GET /api/v1/admin/content/tts/review-batches/{batch_id}/targets`는 `tts-review-batches.json`의 target id 순서대로 `tts-target-manifest.json` metadata를 반환한다. API 배포 이미지에서 이 상세 조회가 동작하도록 `curriculum:derive`는 `apps/api/app/data/curriculum/tts-target-manifest.json` 번들 사본도 함께 생성한다.

Batch별 generation dry-run도 read-only로 연결했다. `GET /api/v1/admin/content/tts/review-batches/{batch_id}/generation-plan`은 실제 TTS 생성/쓰기 없이 현재 admin TTS service field와 호환되는 target, DB lookup 이후 바로 생성 가능한 target, 수동 매핑이 필요한 target, 확장 전 차단되는 target을 구분한다. 이 dry-run은 grammar topic mapping을 위해 `apps/api/app/data/curriculum/topic-grammar-map.json` 번들 사본을 사용한다.

Vocabulary topic mapping도 별도 계약으로 분리했다. `topic-vocabulary-map.json`은 넓은 어휘 topic과 현재 seed vocabulary row를 연결하되, 단일 exact mapping만 `ready_after_db_lookup`으로 승격한다. 현재 vocabulary batch 18개 target 중 `topic-kanji-reading-basics`의 3개 target은 N5 vocabulary order 309 `漢字`로 해석 가능하고, target도 `tts-vocabulary-n5-309-word`, `tts-vocabulary-n5-309-reading`, `tts-vocabulary-n5-309-example-sentence`처럼 row-level source로 생성한다. 나머지 15개 target은 personal pronouns, numbers, weekdays, `知る/分かる`, `きっと`처럼 topic 범위가 넓거나 정확 row가 없어 수동 매핑으로 유지한다.

Batch별 execute preview도 read-only로 연결했다. `GET /api/v1/admin/content/tts/review-batches/{batch_id}/execute-preview`는 generation dry-run의 `ready_after_db_lookup` grammar/vocabulary target을 현재 DB의 `Grammar` 또는 `Vocabulary` row로 해석해 `resolved`, `missing`, `ambiguous`, `not_lookup_ready`, `blocked` 상태를 반환한다. 이 endpoint도 TTS 생성, `tts_audio` 쓰기, GCS 업로드를 수행하지 않으며, 기존 admin TTS service로 호출 가능한 입력이 만들어지는지만 미리 보여준다.

Admin app에는 `/tts-review` read-only 화면을 추가한다. 이 화면은 `summary` 수치, 현재 admin TTS 지원 대상, 확장 필요 대상, blocker, target drilldown, generation dry-run, execute preview 상태를 보여주지만 batch 생성 action은 제공하지 않는다.

## 9. Out of Scope

이번 계획은 아래를 바로 구현하지 않는다.

- 운영 DB 마이그레이션
- N4-N1 레슨 대량 생성
- 모바일 UI 대규모 개편
- PDF 원문 저장 또는 앱 노출
- 외부 자료 예문 복제
- STT 기반 자유 발화 평가

## 10. 다음 작업

1. PDF 001-102 topic inventory를 생성한다.
2. 기존 `packages/database/data/grammar/*-grammar.json`과 topic inventory를 매핑한다.
3. `covered / partial / missing / deferred` 커버리지 리포트를 만든다.
4. N5 보강 대상과 N4 신규 커리큘럼 후보를 분리한다.
5. `GrammarMetadataV2`, `ExampleBank`, `QuestionSchemaV2` JSON 계약 초안을 작성한다.
6. TTS 대상 필드와 lesson script audio pipeline 갭을 커리큘럼 coverage 리포트에 포함한다.
7. `missing / partial` topic은 `coverage-priorities.json`와 `lesson-draft-blueprints.json`으로 먼저 우선순위화한 뒤 실제 seedable lesson JSON으로 승격한다.
8. `lesson-seed-candidates.json`에서 human review와 TTS readiness를 통과한 후보만 공식 `data/lessons/**` 파일로 승격한다.
9. `topic-kanji-reading-basics`와 `topic-kana-hiragana`는 grammar-linked seed shape가 아니라 kana/kanji scaffold shape로 따로 승격한다.
10. lesson 45-50 draft seed candidates는 TTS readiness와 human review를 통과한 뒤 공식 `data/lessons/**` 승격 후보가 된다.
11. `topic-shiru-wakaru`는 vocabulary/skill contrast 특성상 runtime question review를 추가로 통과해야 한다.
