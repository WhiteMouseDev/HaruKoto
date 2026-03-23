# 학습 콘텐츠 데이터 관리 전략

> 어휘, 문법, 퀴즈 등 학습 데이터를 어떻게 만들고, 관리하고, 확장할 것인가.

---

## 1. 업계는 어떻게 하는가?

### Duolingo — AI + 전문가 파이프라인

2024년부터 Duolingo는 콘텐츠 생산을 AI 중심으로 전환했다.

```
커리큘럼 전문가가 주제/문법 포인트 설정
  → 프롬프트 템플릿에 입력
  → LLM이 10개 문제 후보 생성 (수초)
  → 자동 품질 평가기 (Birdbrain)가 난이도/논리 점수 부여
  → 전문가가 최종 선별 → 출시
```

- 2021년: 연간 425개 콘텐츠 단위
- 2024년: 연간 7,500개 (동일 인원, 5배 생산성)
- 148개 신규 언어 코스를 1년 안에 구축 (기존 방식이면 12년)
- 자체 어드민 툴 사용 (CMS 아님, 내부 전용 도구)

### WaniKani — 의존성 기반 수동 큐레이션

일본어 한자 학습 앱의 정석. 콘텐츠 구조:

```
부수(radical) → 한자(kanji) → 어휘(vocabulary)
```

- 60개 레벨, 레벨당 50~100+ 항목
- **부수를 마스터해야 해당 한자 해금, 한자를 마스터해야 해당 어휘 해금**
- 콘텐츠는 Tofugu 팀이 수동 큐레이션
- 자체 DB + 어드민 패널, JSON/CMS 미사용
- 공개 API로 커뮤니티가 데이터를 JSON/CSV로 추출해 공유 중

### Anki — 커뮤니티 주도 파일 기반

- `.apkg` 파일 (내부적으로 SQLite DB)
- 커뮤니티가 CSV/TSV로 데이터 관리 → 빌드 스크립트로 Anki 포맷 변환
- JLPT 덱은 수십만 다운로드
- [open-anki-jlpt-decks](https://github.com/jamsinclair/open-anki-jlpt-decks)가 대표 사례

### 요약: 규모별 접근법

| 규모 | 접근법 | 사례 |
|------|--------|------|
| 1인~소규모 | **JSON 시드 파일 + Git** | Anki 커뮤니티, 인디 앱 |
| 중규모 (5~20명) | **Headless CMS or 스프레드시트 파이프라인** | 중소 EdTech |
| 대규모 (50명+) | **자체 어드민 + AI 파이프라인** | Duolingo |

---

## 2. 하루코토 현재 구조 분석

### 현재 아키텍처

```
packages/database/
├── prisma/
│   ├── schema.prisma          # DB 스키마
│   ├── migrations/            # 마이그레이션 히스토리
│   └── seed.ts                # 시딩 스크립트 (오케스트레이터)
└── data/
    ├── vocabulary/
    │   ├── n5-words.json      # N5 어휘
    │   └── n4-words.json      # N4 어휘
    ├── grammar/
    │   ├── n5-grammar.json    # N5 문법
    │   └── n4-grammar.json    # N4 문법
    ├── kana/
    │   ├── hiragana.json
    │   ├── katakana.json
    │   ├── hiragana-dakuten.json
    │   ├── katakana-dakuten.json
    │   ├── hiragana-youon.json
    │   ├── katakana-youon.json
    │   ├── stages-hiragana.json
    │   └── stages-katakana.json
    ├── cloze/
    │   └── n5-cloze.json
    ├── sentence-arrange/
    │   └── n5-arrange.json
    └── characters/
        └── ai-characters.json
```

### 잘 되어있는 점

- **콘텐츠 테이블과 유저 진행 테이블 분리** — `Vocabulary`(콘텐츠) vs `UserVocabProgress`(유저 상태)
- **`JlptLevel` enum**으로 유효 레벨 DB 수준에서 보장
- **`order` 필드**로 학습 순서 수동 큐레이션 가능
- **멱등 시딩** — `count() === 0`으로 중복 시딩 방지
- **Git으로 콘텐츠 버전 관리** — JSON 파일이 코드와 함께 커밋

### 현재 문제점

#### 1. 증분 추가 불가 (가장 큰 문제)

현재 시딩은 `count === 0`일 때만 전체를 삽입:

```typescript
// 현재 방식
const vocabCount = await prisma.vocabulary.count({ where: { jlptLevel: 'N5' } });
if (vocabCount === 0) {
  await prisma.vocabulary.createMany({ data: n5Words });
}
```

**문제:** N5 어휘가 200개 있는데 50개를 추가하고 싶으면? → 시드를 돌려도 `count > 0`이라 스킵됨. 수동으로 DB에서 전부 지우고 다시 시드해야 함.

**원인:** `Vocabulary` 모델에 unique 제약 조건이 없어서 `upsert`를 쓸 수 없음.

#### 2. 회화 시나리오가 seed.ts에 하드코딩

5개 시나리오가 TypeScript 객체로 직접 작성되어 있음. JSON 파일이 아니라 코드에 내장. 수정하더라도 `count > 0`이라 프로덕션에 반영 안 됨.

#### 3. 단일 파일 한계

N3에만 어휘 ~650개, N2는 ~1,500개, N1은 ~2,000개. `n3-words.json` 하나에 1,500줄 이상이면 리뷰/편집이 어려움.

---

## 3. 개선 계획

### Phase 1: 증분 시딩 가능하게 만들기 (즉시)

#### 스키마에 unique 제약 조건 추가

```prisma
model Vocabulary {
  // ... 기존 필드 ...
  @@unique([word, jlptLevel])        // 추가
  @@index([jlptLevel])
  @@map("vocabularies")
}

model Grammar {
  // ... 기존 필드 ...
  @@unique([pattern, jlptLevel])     // 추가
  @@index([jlptLevel])
  @@map("grammars")
}

model ClozeQuestion {
  // ... 기존 필드 ...
  @@unique([sentence, jlptLevel])    // 추가
  @@map("cloze_questions")
}

model SentenceArrangeQuestion {
  // ... 기존 필드 ...
  @@unique([koreanSentence, jlptLevel])  // 추가
  @@map("sentence_arrange_questions")
}
```

#### 시딩 로직을 upsert로 전환

```typescript
// 개선된 방식
for (const word of n5Words) {
  await prisma.vocabulary.upsert({
    where: {
      word_jlptLevel: { word: word.word, jlptLevel: word.jlptLevel },
    },
    update: {},  // 이미 있으면 건드리지 않음
    create: word,
  });
}
```

이제 JSON에 새 단어를 추가하고 `pnpm db:seed`만 돌리면 기존 데이터는 유지하면서 새 항목만 삽입됨.

#### 회화 시나리오 JSON 분리

```
data/scenarios/
└── scenarios.json
```

`seed.ts`에서 하드코딩된 시나리오를 JSON으로 이동.

### Phase 2: 파일 구조 확장 (N3 추가 시)

#### 레벨별 디렉토리 분할

```
data/
├── vocabulary/
│   ├── n5/
│   │   ├── nouns.json          # 명사 ~100개
│   │   ├── verbs.json          # 동사 ~80개
│   │   ├── adjectives.json     # 형용사 ~60개
│   │   └── expressions.json    # 표현 ~30개
│   ├── n4/
│   │   ├── nouns.json
│   │   ├── verbs.json
│   │   └── adjectives.json
│   └── n3/
│       ├── nouns.json
│       ├── verbs.json
│       └── adjectives.json
├── grammar/
│   ├── n5/
│   │   └── grammar.json
│   ├── n4/
│   │   └── grammar.json
│   └── n3/
│       └── grammar.json
├── cloze/
│   ├── n5/
│   │   ├── particles.json
│   │   └── verb-forms.json
│   └── n4/
│       └── te-form.json
└── sentence-arrange/
    ├── n5/
    │   └── basic.json
    └── n4/
        └── basic.json
```

#### 시드 스크립트 모듈화

```
prisma/
├── seed.ts                   # 오케스트레이터
└── seeders/
    ├── vocabulary.ts         # data/vocabulary/*/*.json 자동 스캔
    ├── grammar.ts
    ├── kana.ts
    ├── cloze.ts
    ├── sentence-arrange.ts
    ├── scenarios.ts
    └── characters.ts
```

```typescript
// prisma/seeders/vocabulary.ts
import { readdirSync } from 'fs';

export async function seedVocabulary() {
  const levels = ['n5', 'n4', 'n3', 'n2', 'n1'];

  for (const level of levels) {
    const dir = `../data/vocabulary/${level}`;
    if (!existsSync(dir)) continue;

    const files = readdirSync(dir).filter(f => f.endsWith('.json'));
    for (const file of files) {
      const words = loadJson(`../data/vocabulary/${level}/${file}`);
      for (const word of words) {
        await prisma.vocabulary.upsert({
          where: { word_jlptLevel: { word: word.word, jlptLevel: level.toUpperCase() } },
          update: {},
          create: word,
        });
      }
    }
  }
}
```

새 레벨을 추가할 때: **JSON 파일만 해당 폴더에 넣으면 자동으로 시딩됨.** 코드 수정 불필요.

### Phase 3: AI 활용 대량 생성 파이프라인 (N3+ 확장 시)

#### 파이프라인 구조

```
1. 프롬프트 템플릿 작성
   ↓
2. Claude/GPT로 배치 생성 (JSON 형식 지정)
   ↓
3. 자동 검증 (스키마 일치, 필수 필드 체크)
   ↓
4. 사람이 리뷰 (읽기 정확성, 예문 자연스러움)
   ↓
5. JSON 파일로 커밋
   ↓
6. pnpm db:seed → 프로덕션 반영
```

#### 프롬프트 템플릿 (어휘 생성)

```
JLPT N3 일본어 명사 20개를 아래 JSON 형식으로 생성해주세요.

[
  {
    "word": "電話",
    "reading": "でんわ",
    "meaningKo": "전화",
    "partOfSpeech": "NOUN",
    "jlptLevel": "N3",
    "exampleSentence": "電話をかけてください。",
    "exampleReading": "でんわをかけてください。",
    "exampleTranslation": "전화해 주세요.",
    "tags": ["communication"],
    "order": 1
  }
]

규칙:
- reading은 정확한 히라가나/가타카나
- meaningKo는 한국어 의미 (간결하게)
- exampleSentence는 N3 수준의 자연스러운 예문
- tags는 주제 카테고리 (daily, food, travel, business, school, nature 등)
- 주제: [여기에 주제 지정, 예: 학교/교육 관련]
```

#### 프롬프트 템플릿 (빈칸 채우기 생성)

```
JLPT N3 수준의 빈칸 채우기 문제 10개를 아래 JSON 형식으로 생성해주세요.

[
  {
    "sentence": "明日は友達{blank}会う予定です。",
    "translation": "내일은 친구를 만날 예정입니다.",
    "correctAnswer": "に",
    "options": ["に", "を", "で", "と"],
    "explanation": "「会う」는 「~に会う」의 형태로 사용합니다.",
    "grammarPoint": "に (대상)",
    "jlptLevel": "N3",
    "difficulty": 2,
    "order": 1
  }
]

규칙:
- {blank}이 들어갈 위치는 문법 포인트가 드러나는 곳
- options는 4개, 정답 포함
- explanation은 한국어로 간결하게
- difficulty는 1~5 (1=쉬움)
```

#### 자동 검증 스크립트

```typescript
// scripts/validate-content.ts
import Ajv from 'ajv';

const vocabSchema = {
  type: 'array',
  items: {
    type: 'object',
    required: ['word', 'reading', 'meaningKo', 'partOfSpeech', 'jlptLevel'],
    properties: {
      word: { type: 'string', minLength: 1 },
      reading: { type: 'string', minLength: 1 },
      meaningKo: { type: 'string', minLength: 1 },
      partOfSpeech: { enum: ['NOUN', 'VERB', 'I_ADJECTIVE', 'NA_ADJECTIVE', 'ADVERB', 'PARTICLE', 'CONJUNCTION', 'COUNTER', 'EXPRESSION', 'PREFIX', 'SUFFIX'] },
      jlptLevel: { enum: ['N5', 'N4', 'N3', 'N2', 'N1'] },
    },
  },
};

// JSON 파일을 커밋하기 전에 실행
// npx tsx scripts/validate-content.ts data/vocabulary/n3/nouns.json
```

---

## 4. JLPT 콘텐츠 데이터 출처

### 공식 상태

JLPT(日本語能力試験)는 **공식 어휘/문법 목록을 발표하지 않는다** (2010년 개편 이후). 존재하는 모든 JLPT 단어 목록은 커뮤니티가 기출/교재를 분석해서 정리한 것.

### 사용 가능한 오픈 데이터

| 출처 | 내용 | 라이선스 | 비고 |
|------|------|----------|------|
| **JMdict / EDRDG** | 17만+ 일본어 사전 항목 | CC BY-SA 4.0 (상업 사용 가능) | 출처 표기 필수. Jisho.org의 데이터 소스 |
| **Tanos.co.uk** | N5~N1 어휘 목록 + MP3 오디오 | 무료 공개 | 가장 널리 사용되는 JLPT 단어 목록 |
| **jlpt-kanji-dictionary** (GitHub) | N5~N1 구조화된 JSON | 오픈소스 | 영어+러시아어 번역 |
| **JLPT_Vocabulary** (GitHub) | 전 레벨 JSON/CSV | 오픈소스 | 단어+읽기+의미 |
| **open-anki-jlpt-decks** (GitHub) | Anki 덱 소스 CSV | 오픈소스 | 커뮤니티 검증됨 |
| **kanji-data** (GitHub) | 한자 데이터 + JLPT/WaniKani 레벨 | 오픈소스 | 한자 학습 확장 시 활용 |

### 저작권 주의사항

- **단어 목록 자체는 저작물이 아님** (사실의 나열). 자유롭게 사용 가능.
- **예문은 저작물이 될 수 있음.** 교재에서 예문을 그대로 가져오면 안 됨 → AI로 새 예문 생성 권장.
- **JMdict 사용 시** 앱 내 또는 웹사이트에 출처 표기 필수 (CC BY-SA 4.0 조건).
- **오디오 파일**은 별도 라이선스 확인 필요. Google Cloud TTS / OpenAI TTS로 자체 생성이 안전.

---

## 5. 콘텐츠 vs 스키마 배포 전략

| 변경 유형 | 필요한 작업 | 코드 배포 필요? |
|-----------|-------------|-----------------|
| 스키마 변경 (새 컬럼/테이블) | Alembic migration (`cd apps/api && uv run alembic revision --autogenerate -m "desc" && uv run alembic upgrade head`) + `cd packages/database && pnpm db:sync` | **필요** |
| 콘텐츠 추가 (새 JSON 항목) | JSON 편집 + `pnpm db:seed` | **불필요** (DB에 직접 시딩) |
| 콘텐츠 수정 (의미 오류 수정) | JSON 수정 + 타겟 update 스크립트 | **불필요** |
| 시나리오 추가/수정 | JSON 편집 + `pnpm db:seed` | **불필요** |

**핵심:** 콘텐츠 업데이트는 배포 없이 DB에 직접 반영할 수 있어야 한다. 이것이 시드 파이프라인의 핵심 가치.

```bash
# 프로덕션 콘텐츠만 업데이트 (배포 없이)
DATABASE_URL="..." pnpm --filter @harukoto/database db:seed
```

---

## 6. 커밋 컨벤션

콘텐츠 변경은 코드 변경과 구분:

```
content: N3 어휘 128단어 추가 (명사)
content: N4 빈칸채우기 30문제 추가 (조사)
content: N5 예문 오류 수정 (「食べる」)
fix: 시딩 스크립트 upsert 로직 수정
feat: N3 문법 학습 플로우 구현
```

콘텐츠 PR과 기능 PR을 분리하면 리뷰가 쉽고 롤백도 독립적.

---

## 7. 규모별 콘텐츠 관리 도구 진화

| 단계 | 유저 수 | 도구 | 설명 |
|------|---------|------|------|
| **현재** | 0~1K | JSON + Git + seed.ts | 개발자가 직접 관리. 충분. |
| **성장** | 1K~10K | JSON + AI 생성 + 검증 스크립트 | Claude로 대량 생성 → 사람 리뷰 → 커밋 |
| **확장** | 10K~50K | Headless CMS (Sanity) + JSON export | 일본어 교사가 GUI로 콘텐츠 편집 가능 |
| **스케일** | 50K+ | 자체 어드민 + AI 파이프라인 | Duolingo 방식. 전문가 + AI + 자동 QA |

**지금은 JSON + Git이 최적.** CMS는 비개발자 편집자가 합류할 때 도입.

---

## 8. 즉시 실행 가능한 액션 아이템

### 우선순위 1: 증분 시딩 인프라 (1~2일)

1. `Vocabulary`, `Grammar`, `ClozeQuestion`, `SentenceArrangeQuestion`에 unique 제약 조건 추가
2. `seed.ts`를 upsert 기반으로 리팩토링
3. 회화 시나리오를 `data/scenarios/scenarios.json`으로 분리

### 우선순위 2: N3 콘텐츠 추가 (1~2주)

1. 커뮤니티 JLPT N3 단어 목록 수집 (GitHub 오픈소스)
2. Claude로 한국어 의미 + 예문 배치 생성
3. 사람이 검증 → JSON 커밋
4. `pnpm db:seed`로 프로덕션 반영

### 우선순위 3: 콘텐츠 검증 자동화 (반나절)

1. JSON 스키마 검증 스크립트 작성 (`scripts/validate-content.ts`)
2. CI에 추가 — 콘텐츠 JSON 변경 시 자동 검증

---

## 참고 자료

- [Duolingo: AI로 콘텐츠 생산 5배 가속](https://blog.duolingo.com/content-production/)
- [Duolingo: AI로 병목 해소](https://blog.duolingo.com/using-ai-to-open-up-bottlenecks-in-course-content-creation/)
- [WaniKani API 문서](https://docs.api.wanikani.com/)
- [EDRDG/JMdict 라이선스](https://www.edrdg.org/edrdg/licence.html)
- [Tanos.co.uk JLPT 리소스](https://www.tanos.co.uk/jlpt/)
- [GitHub: kanji-data](https://github.com/davidluzgouveia/kanji-data)
- [GitHub: JLPT_Vocabulary](https://github.com/Bluskyo/JLPT_Vocabulary)
- [GitHub: open-anki-jlpt-decks](https://github.com/jamsinclair/open-anki-jlpt-decks)
- [Prisma Seeding 공식 문서](https://www.prisma.io/docs/orm/prisma-migrate/workflows/seeding)
- [Sanity.io](https://www.sanity.io/)
