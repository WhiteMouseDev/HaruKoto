# 학습 데이터 생성 가이드

> 7,000여 개의 원본 단어 데이터를 앱에 적합한 JSON으로 변환하고, DB에 시딩하기까지의 전체 파이프라인.

---

## 1. 현재 상태

### 보유 데이터

- **원본 형태:** PDF/이미지 (약 7,000단어, N5~N1)
- **원본 포맷 예시:**
  ```
  あう[会う] N5, (-に+) 만나다
  あう[合う] N4, 딱 맞다. 서로 …하다
  あく[開く] N5, 열리다
  あく[空く] N4, 비다
  ```
- **포함 정보:** 읽기(히라가나), 한자, JLPT 레벨, 한국어 의미, (일부) 조사 힌트
- **미포함 정보:** 품사(partOfSpeech), 예문, 예문 읽기, 예문 번역, 태그

### 이미 시딩된 데이터

| 레벨 | 단어 수 | 파일 |
|------|---------|------|
| N5 | 200 | `data/vocabulary/n5-words.json` |
| N4 | 200 | `data/vocabulary/n4-words.json` |
| N3~N1 | 0 | 없음 |

### 타겟 JSON 형식

```json
{
  "word": "会う",
  "reading": "あう",
  "meaningKo": "만나다",
  "partOfSpeech": "VERB",
  "jlptLevel": "N5",
  "exampleSentence": "友達に会う。",
  "exampleReading": "ともだちにあう。",
  "exampleTranslation": "친구를 만나다.",
  "tags": ["사람", "일상"],
  "order": 1
}
```

---

## 2. 스키마 제약 조건 — 먼저 해결해야 할 문제

### 현재 유니크 제약

```prisma
@@unique([word, jlptLevel])  // word(한자) + 레벨
```

### 문제 시나리오

같은 한자가 같은 레벨에서 다른 읽기/의미로 존재할 수 있다:

| word | reading | meaningKo | jlptLevel | 유니크 충돌? |
|------|---------|-----------|-----------|------------|
| 会う | あう | 만나다 | N5 | — |
| 合う | あう | 맞다 | N4 | ❌ 다른 word이므로 OK |
| 開く | あく | 열리다 | N5 | — |
| 開く | ひらく | 열다 | N3 | ❌ 다른 레벨이므로 OK |
| **生** | **なま** | **날것** | **N4** | — |
| **生** | **いきる** | **살다** | **N4** | **⚠️ 충돌!** |

### 해결: 유니크 키에 `reading` 추가

```prisma
// Before
@@unique([word, jlptLevel])

// After
@@unique([word, reading, jlptLevel])
```

> **⚠️ 이 변경은 데이터 투입 전에 반드시 먼저 적용해야 한다.**
> 이미 시딩된 200+200개 단어에는 같은 word+level 중복이 없으므로 안전하게 변경 가능.
> `seed.ts`의 upsert where절도 함께 수정 필요.

---

## 3. 데이터 변환 파이프라인

```
[Step 1]          [Step 2]           [Step 3]           [Step 4]           [Step 5]
PDF/이미지  →  OCR/텍스트 추출  →  파싱 스크립트  →  AI 보강  →  검증 + 시딩
                                    (구조화)        (품사/예문)
```

### Step 1: OCR/텍스트 추출

PDF가 텍스트 기반이면 복사-붙여넣기로 충분. 이미지라면:

| 방법 | 도구 | 정확도 |
|------|------|--------|
| **복사-붙여넣기** | PDF 뷰어 | 텍스트 PDF면 100% |
| **Claude/GPT** | 이미지 직접 첨부 | 95%+ (일본어 OCR 강함) |
| **Google Cloud Vision** | API 호출 | 99%+ (일본어 특화) |

**추천:** Claude에 이미지를 첨부하고 아래 프롬프트로 한 번에 텍스트 변환:

```
이 이미지의 일본어 단어 목록을 아래 TSV 형식으로 변환해주세요.
각 행: 읽기\t한자\tJLPT레벨\t한국어의미
예: あう\t会う\tN5\t만나다

- 대괄호 안의 한자를 word로
- 대괄호 앞의 히라가나를 reading으로
- 괄호 안의 조사 힌트(~に+)는 meaningKo 앞에 포함
- 레벨(N5, N4 등)은 그대로
```

### Step 2: 텍스트를 TSV/CSV로 정리

OCR 결과물 예시 (raw.tsv):

```tsv
あう	会う	N5	(-に+) 만나다
あう	合う	N4	딱 맞다. 서로 …하다
あく	開く	N5	열리다
あく	空く	N4	비다
```

### Step 3: 파싱 스크립트로 레벨별 JSON 분리

`packages/database/scripts/` 디렉토리에 변환 스크립트를 만든다:

```typescript
// scripts/parse-raw-words.ts
import { readFileSync, writeFileSync } from 'fs';
import { join } from 'path';

interface RawWord {
  reading: string;
  word: string;     // 한자 표기
  jlptLevel: string;
  meaningKo: string;
}

interface VocabEntry {
  word: string;
  reading: string;
  meaningKo: string;
  partOfSpeech: string | null;  // Step 4에서 AI가 채움
  jlptLevel: string;
  exampleSentence: string | null;
  exampleReading: string | null;
  exampleTranslation: string | null;
  tags: string[];
  order: number;
}

// 1) TSV 파싱
const raw = readFileSync(join(__dirname, '../data/raw/all-words.tsv'), 'utf-8');
const lines = raw.trim().split('\n');

const words: RawWord[] = lines.map(line => {
  const [reading, word, jlptLevel, meaningKo] = line.split('\t');
  return { reading: reading.trim(), word: word.trim(), jlptLevel: jlptLevel.trim(), meaningKo: meaningKo.trim() };
});

// 2) 레벨별 그룹핑
const byLevel: Record<string, VocabEntry[]> = {};

for (const w of words) {
  if (!byLevel[w.jlptLevel]) byLevel[w.jlptLevel] = [];

  byLevel[w.jlptLevel].push({
    word: w.word,
    reading: w.reading,
    meaningKo: w.meaningKo,
    partOfSpeech: null,       // AI가 채울 필드
    exampleSentence: null,    // AI가 채울 필드
    exampleReading: null,     // AI가 채울 필드
    exampleTranslation: null, // AI가 채울 필드
    tags: [],
    order: byLevel[w.jlptLevel].length + 1,
    jlptLevel: w.jlptLevel,
  });
}

// 3) 중복 검증
for (const [level, entries] of Object.entries(byLevel)) {
  const seen = new Set<string>();
  const dupes: string[] = [];

  for (const e of entries) {
    const key = `${e.word}|${e.reading}`;
    if (seen.has(key)) {
      dupes.push(`${e.word}[${e.reading}]`);
    }
    seen.add(key);
  }

  if (dupes.length > 0) {
    console.warn(`⚠️ ${level}에 중복 ${dupes.length}개: ${dupes.join(', ')}`);
  }

  console.log(`${level}: ${entries.length}개`);
}

// 4) 레벨별 JSON 파일 저장
for (const [level, entries] of Object.entries(byLevel)) {
  const filename = `${level.toLowerCase()}-words-raw.json`;
  const outPath = join(__dirname, '../data/vocabulary', filename);
  writeFileSync(outPath, JSON.stringify(entries, null, 2), 'utf-8');
  console.log(`✅ ${outPath} 저장 (${entries.length}개)`);
}
```

**실행:**
```bash
cd packages/database
npx tsx scripts/parse-raw-words.ts
```

**결과물:**
```
data/vocabulary/
├── n5-words-raw.json    # AI 보강 전 (partOfSpeech=null)
├── n4-words-raw.json
├── n3-words-raw.json
├── n2-words-raw.json
└── n1-words-raw.json
```

### Step 4: AI로 누락 필드 보강

파싱된 JSON을 Claude/GPT에 넣어 품사와 예문을 생성한다.

#### 배치 크기

- 한 번에 **50~100개씩** 처리 (너무 많으면 품질 저하)
- N5 800개 기준 → 8~16 배치

#### AI 프롬프트 (Claude 추천)

```
아래 JSON 배열의 각 단어에 대해 누락된 필드를 채워주세요.

## 채워야 할 필드
1. **partOfSpeech**: 아래 enum 중 하나
   NOUN, VERB, I_ADJECTIVE, NA_ADJECTIVE, ADVERB, PARTICLE, CONJUNCTION, COUNTER, EXPRESSION, PREFIX, SUFFIX

2. **exampleSentence**: 해당 단어를 사용한 자연스러운 일본어 예문 (1문장)
   - 해당 JLPT 레벨에 맞는 난이도
   - N5: です/ます형, 기본 문형
   - N4: て형, 가능형 등
   - N3: 경어, 복합문
   - N2~N1: 서면체, 관용표현

3. **exampleReading**: 예문의 히라가나 읽기 (한자를 전부 히라가나로)

4. **exampleTranslation**: 예문의 한국어 번역

5. **tags**: 의미 카테고리 태그 (1~3개)
   예: ["음식", "일상"], ["감정"], ["비즈니스", "경어"]

## 규칙
- 기존 word, reading, meaningKo, jlptLevel, order는 절대 수정하지 마세요
- JSON 배열 형태로 그대로 반환해주세요
- partOfSpeech는 반드시 위 enum 값 중 하나여야 합니다

## 입력 데이터
[여기에 50~100개의 JSON 배열 붙여넣기]
```

#### 품사 분류 기준

| 원본 힌트 | partOfSpeech |
|-----------|-------------|
| ~する (동사 활용) | VERB |
| ~い로 끝남 (い형용사) | I_ADJECTIVE |
| ~な가 붙음 (な형용사) | NA_ADJECTIVE |
| 조사 (は、が、を 등) | PARTICLE |
| ~つ, ~個, ~人 등 | COUNTER |
| 인사말, 관용구 | EXPRESSION |
| 접두어 (お~, ご~ 등) | PREFIX |
| 접미어 (~さん, ~的 등) | SUFFIX |

### Step 5: 검증 + 시딩

AI가 반환한 JSON을 검증한 후 기존 파일에 병합.

#### 검증 스크립트

```typescript
// scripts/validate-words.ts
import { readFileSync } from 'fs';
import { join } from 'path';

const VALID_POS = [
  'NOUN', 'VERB', 'I_ADJECTIVE', 'NA_ADJECTIVE', 'ADVERB',
  'PARTICLE', 'CONJUNCTION', 'COUNTER', 'EXPRESSION', 'PREFIX', 'SUFFIX'
];
const VALID_LEVELS = ['N5', 'N4', 'N3', 'N2', 'N1'];

const file = process.argv[2];
if (!file) { console.error('Usage: npx tsx scripts/validate-words.ts <json-file>'); process.exit(1); }

const data = JSON.parse(readFileSync(join(__dirname, '..', file), 'utf-8'));
let errors = 0;

for (let i = 0; i < data.length; i++) {
  const v = data[i];
  const prefix = `[${i}] ${v.word}(${v.reading})`;

  // 필수 필드 체크
  if (!v.word) { console.error(`${prefix}: word 없음`); errors++; }
  if (!v.reading) { console.error(`${prefix}: reading 없음`); errors++; }
  if (!v.meaningKo) { console.error(`${prefix}: meaningKo 없음`); errors++; }
  if (!VALID_LEVELS.includes(v.jlptLevel)) { console.error(`${prefix}: 잘못된 jlptLevel "${v.jlptLevel}"`); errors++; }
  if (!VALID_POS.includes(v.partOfSpeech)) { console.error(`${prefix}: 잘못된 partOfSpeech "${v.partOfSpeech}"`); errors++; }

  // 예문 체크
  if (!v.exampleSentence) { console.warn(`${prefix}: exampleSentence 없음`); }
  if (v.exampleSentence && !v.exampleReading) { console.error(`${prefix}: 예문은 있는데 reading 없음`); errors++; }
  if (v.exampleSentence && !v.exampleTranslation) { console.error(`${prefix}: 예문은 있는데 translation 없음`); errors++; }

  // 예문에 해당 단어가 포함되어 있는지 (품질 체크)
  if (v.exampleSentence && !v.exampleSentence.includes(v.word)) {
    console.warn(`${prefix}: 예문에 단어 "${v.word}"가 미포함`);
  }

  // tags 체크
  if (!Array.isArray(v.tags)) { console.error(`${prefix}: tags가 배열이 아님`); errors++; }
}

// 중복 체크 (word + reading + jlptLevel)
const seen = new Map<string, number>();
for (let i = 0; i < data.length; i++) {
  const key = `${data[i].word}|${data[i].reading}|${data[i].jlptLevel}`;
  if (seen.has(key)) {
    console.error(`[${i}] 중복: ${key} (첫 출현: [${seen.get(key)}])`);
    errors++;
  }
  seen.set(key, i);
}

console.log(`\n검증 완료: ${data.length}개 단어, ${errors}개 오류`);
if (errors > 0) process.exit(1);
```

---

## 4. 실전 워크플로우 (단계별 체크리스트)

### Phase A: 원본 데이터 텍스트 변환

- [ ] PDF/이미지에서 텍스트 추출 (Claude OCR 또는 복사-붙여넣기)
- [ ] TSV로 정리: `읽기\t한자\tJLPT레벨\t한국어의미`
- [ ] `data/raw/all-words.tsv`로 저장
- [ ] 수동 spot check: 10개 정도 원본과 대조

### Phase B: 스키마 수정

- [ ] `@@unique([word, jlptLevel])` → `@@unique([word, reading, jlptLevel])` 변경
- [ ] `seed.ts` upsert where절 수정 (reading 추가)
- [ ] Alembic migration 실행 (`cd apps/api && uv run alembic revision --autogenerate -m "update unique constraint" && uv run alembic upgrade head`)
- [ ] Prisma 동기화 (`cd packages/database && pnpm db:sync`)

### Phase C: 파싱 + 중복 검증

- [ ] `scripts/parse-raw-words.ts` 실행
- [ ] 각 레벨별 단어 수 확인 (예상: N5 ~800, N4 ~1500, N3 ~2000, N2 ~1500, N1 ~1200)
- [ ] 중복 경고 확인 및 수동 해결
- [ ] 기존 n5-words.json (200개)와 신규 데이터 병합 계획 수립

### Phase D: AI 보강 (레벨별 순서대로)

- [ ] **N5부터 시작** (가장 쉬움, 프로세스 검증용)
- [ ] 50~100개 배치로 Claude에 전달
- [ ] AI 반환 JSON을 `validate-words.ts`로 검증
- [ ] 오류 수정 후 최종 JSON 저장
- [ ] 기존 200개와 신규 데이터 병합 (order 재정렬)
- [ ] N4 → N3 → N2 → N1 순서로 반복

### Phase E: 시딩 + 확인

- [ ] `pnpm db:seed` 실행
- [ ] 각 레벨별 upsert 결과 확인 (created vs already existed)
- [ ] 앱에서 학습 탭 → 각 레벨 선택 → 퀴즈 동작 확인

---

## 5. 기존 데이터와의 병합 전략

현재 `n5-words.json`에 200개, `n4-words.json`에 200개가 이미 있다.

### 원칙

1. **기존 데이터 우선:** 기존 200개는 이미 품사/예문이 완비되어 있으므로 덮어쓰지 않는다
2. **신규 데이터 추가:** 원본 7000개 중 기존에 없는 단어만 추가
3. **order 재정렬:** 기존 데이터의 order를 유지하고, 신규 데이터는 뒤에 이어 붙인다

### 병합 방법

```typescript
// scripts/merge-words.ts
import { readFileSync, writeFileSync } from 'fs';

const existing = JSON.parse(readFileSync('data/vocabulary/n5-words.json', 'utf-8'));
const newData = JSON.parse(readFileSync('data/vocabulary/n5-words-raw.json', 'utf-8'));

const existingKeys = new Set(existing.map((e: any) => `${e.word}|${e.reading}`));
const maxOrder = Math.max(...existing.map((e: any) => e.order));

let added = 0;
for (const n of newData) {
  const key = `${n.word}|${n.reading}`;
  if (!existingKeys.has(key)) {
    existing.push({ ...n, order: maxOrder + (++added) });
  }
}

writeFileSync('data/vocabulary/n5-words.json', JSON.stringify(existing, null, 2));
console.log(`기존 ${existingKeys.size}개 + 신규 ${added}개 = 총 ${existing.length}개`);
```

---

## 6. 엣지 케이스 정리

### Case 1: 같은 읽기, 다른 한자, 다른 레벨

```
あう[会う] N5 — 만나다
あう[合う] N4 — 맞다
```

→ `word`가 다르므로 **문제 없음**. 현재 스키마로도 OK.

### Case 2: 같은 한자, 다른 읽기, 같은 레벨

```
生[なま] N4 — 날것
生[いきる] N4 — 살다
```

→ `word`가 같고 `jlptLevel`도 같음. **현재 스키마면 충돌!**
→ `@@unique([word, reading, jlptLevel])`로 해결.

### Case 3: 같은 한자, 같은 읽기, 다른 레벨

```
開く[あく] N5 — 열리다 (자동사)
開く[あく] N3 — (보다 복잡한 의미)
```

→ `jlptLevel`이 다르므로 **문제 없음**.

### Case 4: 한자 없이 히라가나만 있는 단어

```
もう N5 — 이미, 벌써
とても N5 — 매우
```

→ `word = reading = "もう"`. 문제 없음. word 필드에 히라가나를 그대로 넣는다.

### Case 5: 한자 없이 카타카나만 있는 단어

```
テレビ N5 — TV
コンピューター N5 — 컴퓨터
```

→ `word = "テレビ"`, `reading = "テレビ"` (또는 히라가나 `"てれび"`).
→ 기존 데이터의 패턴을 따른다. 현재 n5-words.json에서 카타카나 단어 확인 필요.

### Case 6: 조사 힌트가 포함된 의미

```
あう[会う] N5, (-に+) 만나다
```

→ `meaningKo: "(-に+) 만나다"` 로 그대로 저장. 조사 힌트는 학습에 유용한 정보.

---

## 7. 예상 레벨별 단어 수 (JLPT 공식 기준)

| 레벨 | 공식 기준 | 보유 데이터(추정) | 비고 |
|------|----------|------------------|------|
| N5 | ~800 | ~600-800 | 기초 단어 |
| N4 | ~1,500 | ~1,200-1,500 | N5 누적 포함 시 ~2,300 |
| N3 | ~3,000 | ~1,500-2,000 | 중급 |
| N2 | ~6,000 | ~1,500-2,000 | 중상급 |
| N1 | ~10,000 | ~1,000-1,500 | 상급 |

> 원본 데이터 7,000개는 N5~N1 전체에서 주요 단어를 추린 것. JLPT 공식 목록과는 차이가 있을 수 있다.

---

## 8. 디렉토리 구조 (최종)

```
packages/database/
├── data/
│   ├── raw/                          # 원본 텍스트 (시딩 대상 아님)
│   │   └── all-words.tsv
│   ├── vocabulary/
│   │   ├── n5-words.json             # 최종 (기존 200 + 신규)
│   │   ├── n4-words.json             # 최종
│   │   ├── n3-words.json             # 신규 생성
│   │   ├── n2-words.json             # 신규 생성
│   │   └── n1-words.json             # 신규 생성
│   ├── grammar/
│   ├── cloze/
│   ├── sentence-arrange/
│   ├── kana/
│   ├── characters/
│   └── scenarios/
├── scripts/
│   ├── parse-raw-words.ts            # TSV → 레벨별 raw JSON
│   ├── merge-words.ts                # 기존 데이터와 병합
│   └── validate-words.ts             # JSON 검증
└── prisma/
    ├── schema.prisma
    └── seed.ts
```

---

## 9. 시간 예상

| 단계 | 예상 시간 | 비고 |
|------|----------|------|
| PDF → TSV 변환 | 1~2시간 | Claude OCR 사용 시 |
| 파싱 스크립트 작성/실행 | 30분 | 한 번 만들면 재사용 |
| 스키마 변경 | 15분 | 유니크 제약 + seed.ts 수정 |
| AI 보강 (N5, ~800개) | 2~3시간 | 50개씩 16배치, 검수 포함 |
| AI 보강 (N4, ~1500개) | 3~5시간 | |
| AI 보강 (N3~N1) | 6~10시간 | 단어가 어려울수록 예문 검수 시간 증가 |
| 검증 + 시딩 | 1시간 | |
| **총합** | **약 2~3일** | 집중 작업 기준 |

---

## 10. 품질 관리 체크리스트

### AI 생성 예문 검수 포인트

- [ ] 예문에 해당 단어가 실제로 사용되었는가?
- [ ] 예문 난이도가 해당 JLPT 레벨에 적합한가? (N5에 N2급 문법이 들어가면 안 됨)
- [ ] 예문 읽기(exampleReading)가 정확한가? (한자 → 히라가나 변환 오류 주의)
- [ ] 한국어 번역이 자연스러운가?
- [ ] 품사 분류가 정확한가? (특히 な형용사 vs い형용사)

### 데이터 무결성 체크

- [ ] 각 레벨 내 `(word, reading)` 조합이 유일한가?
- [ ] `partOfSpeech`가 유효한 enum 값인가?
- [ ] `jlptLevel`이 파일명의 레벨과 일치하는가?
- [ ] `order`가 1부터 연속적으로 부여되어 있는가?
- [ ] `tags`가 빈 배열이 아닌 의미 있는 값인가?

---

## 11. FAQ

### Q: 기존 200개 단어와 신규 데이터가 겹치면?

upsert 기반 시딩이므로 기존 데이터는 그대로, 신규만 추가된다. `seed.ts`의 `update: {}` 설정에 의해 이미 있는 단어는 건너뛴다.

### Q: AI가 잘못된 품사를 분류하면?

`validate-words.ts`에서 잡힌다. enum에 없는 값이면 에러로 보고. 검수 시 일본어 사전(jisho.org)과 대조 추천.

### Q: 나중에 단어를 수정하고 싶으면?

JSON 파일을 직접 수정하고 `pnpm db:seed`를 다시 실행. 단, 현재 `update: {}`이므로 기존 데이터는 업데이트되지 않는다. 수정 반영이 필요하면 seed.ts의 update 블록에 해당 필드를 추가해야 한다.

### Q: 문법 데이터도 같은 방식으로 만드나?

동일한 파이프라인. 다만 Grammar 모델의 필드가 다르다:
- `pattern` (문법 패턴), `meaningKo`, `explanation`, `exampleSentences` (JSON 배열)
- 유니크: `@@unique([pattern, jlptLevel])`
