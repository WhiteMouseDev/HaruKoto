# N1~N3 데이터 시딩 작업 지시서

> 이 문서는 다른 Claude Code 세션에서 N1~N3 어휘/문법 데이터를 시딩하기 위한 작업 지시서입니다.

---

## 목표

N1, N2, N3 레벨의 원본 CSV 데이터를 앱에서 사용 가능한 JSON으로 변환하고 시딩한다.

### 현재 상태

| 레벨 | 어휘 | 문법 | 빈칸채우기 | 어순배열 |
|------|------|------|-----------|---------|
| N5 | 200개 ✅ | ~30개 ✅ | ~50개 ✅ | ~30개 ✅ |
| N4 | 200개 ✅ | ~30개 ✅ | ❌ | ❌ |
| N3 | 원본 CSV만 있음 | ❌ | ❌ | ❌ |
| N2 | 원본 CSV만 있음 | ❌ | ❌ | ❌ |
| N1 | 원본 CSV만 있음 | ❌ | ❌ | ❌ |

### 원본 CSV 데이터 크기

| 레벨 | 단어 수 | 파일 |
|------|--------|------|
| N3 | ~1,210개 | `packages/database/data/raw/n3/N3-표 1.csv` |
| N2 | ~2,240개 | `packages/database/data/raw/n2/N2-표 1.csv` |
| N1 | ~2,670개 | `packages/database/data/raw/n1/N1-표 1.csv` |

---

## 작업 순서

### Step 1: 원본 CSV 확인 및 정제

**원본 CSV 위치:** `packages/database/data/raw/n{1,2,3}/`

**원본 CSV 포맷** (4컬럼만 있음):
```csv
reading,word,jlptLevel,meaningKo
あい,愛,N3,사랑
あいかわらず,相変わらず,N3,변함없이. 여전히
```

**정제 필요 사항:**
- `meaningKo`에 `⇔`, `＝`, `⇒` 등 참조 표기가 포함된 항목 정리
  - 예: `올라가다 ⇔さがる[下がる]` → `올라가다`로 정리하거나 유지
- 중복 단어 체크 (같은 word+reading 조합)
- 빈 필드 체크

---

### Step 2: CSV → JSON 변환 (AI 보강 포함)

원본 CSV에는 `partOfSpeech`, `exampleSentence`, `exampleReading`, `exampleTranslation`, `tags`가 없으므로 AI로 보강해야 한다.

**변환 스크립트를 작성하거나, 직접 AI로 보강하여 최종 JSON을 생성한다.**

#### 최종 JSON 포맷 (필수 준수)

**어휘 (`data/vocabulary/n3-words.json`):**
```json
[
  {
    "word": "愛",
    "reading": "あい",
    "meaningKo": "사랑",
    "partOfSpeech": "NOUN",
    "jlptLevel": "N3",
    "exampleSentence": "愛は大切なものです。",
    "exampleReading": "あいはたいせつなものです。",
    "exampleTranslation": "사랑은 소중한 것입니다.",
    "tags": ["감정"],
    "order": 1
  }
]
```

**각 필드 설명:**

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `word` | string | ✅ | 한자/카타카나 표기 |
| `reading` | string | ✅ | 히라가나 읽기 |
| `meaningKo` | string | ✅ | 한국어 의미 |
| `partOfSpeech` | enum | ✅ | 아래 enum 값 중 하나 |
| `jlptLevel` | enum | ✅ | "N1", "N2", "N3" |
| `exampleSentence` | string | ✅ | 일본어 예문 |
| `exampleReading` | string | ✅ | 예문의 히라가나 읽기 |
| `exampleTranslation` | string | ✅ | 예문의 한국어 번역 |
| `tags` | string[] | ✅ | 주제 태그 (1~3개) |
| `order` | int | ✅ | 학습 순서 (1부터 시작) |

**partOfSpeech enum 값:**
```
NOUN, VERB, I_ADJECTIVE, NA_ADJECTIVE, ADVERB,
PARTICLE, CONJUNCTION, COUNTER, EXPRESSION, PREFIX, SUFFIX
```

**품사 판별 기준:**
- 동사: `~する`, `~る`, `~う`, `~く` 등으로 끝나는 단어
- い형용사 (I_ADJECTIVE): `~い`로 끝나는 형용사 (きれい는 NA_ADJECTIVE)
- な형용사 (NA_ADJECTIVE): `~な`가 붙는 형용사
- 명사: 그 외 대부분
- 부사: `とても`, `すっかり` 등
- 접속사: `しかし`, `そして` 등
- 표현: `おはよう`, `すみません` 등 관용 표현

---

### Step 3: 문법 데이터 생성

**문법 JSON 포맷 (`data/grammar/n3-grammar.json`):**
```json
[
  {
    "pattern": "～ので",
    "meaningKo": "~이므로, ~해서 (원인/이유)",
    "explanation": "원인이나 이유를 나타내는 접속 표현입니다. 'から'보다 객관적이고 정중한 느낌을 줍니다. な형용사와 명사에는 'なので'를 사용합니다.",
    "jlptLevel": "N3",
    "exampleSentences": [
      {
        "japanese": "雨なので、出かけません。",
        "reading": "あめなので、でかけません。",
        "korean": "비가 오므로 외출하지 않습니다."
      },
      {
        "japanese": "忙しいので、遊べません。",
        "reading": "いそがしいので、あそべません。",
        "korean": "바빠서 놀 수 없습니다."
      }
    ],
    "order": 1
  }
]
```

**각 레벨별 문법 개수 기준:**
- N3: ~40개 패턴
- N2: ~50개 패턴
- N1: ~50개 패턴

**문법 데이터는 원본 CSV가 없으므로 AI가 직접 생성해야 한다.** 각 레벨의 대표적인 JLPT 문법 항목을 기반으로 작성.

---

### Step 4: JSON 파일 배치

생성된 JSON 파일을 아래 위치에 저장:

```
packages/database/data/
├── vocabulary/
│   ├── n5-words.json      (기존)
│   ├── n4-words.json      (기존)
│   ├── n3-words.json      ← 신규
│   ├── n2-words.json      ← 신규
│   └── n1-words.json      ← 신규
├── grammar/
│   ├── n5-grammar.json    (기존)
│   ├── n4-grammar.json    (기존)
│   ├── n3-grammar.json    ← 신규
│   ├── n2-grammar.json    ← 신규
│   └── n1-grammar.json    ← 신규
```

**시드 스크립트(`prisma/seed.ts`)는 `data/vocabulary/`, `data/grammar/` 폴더의 모든 JSON 파일을 자동 스캔하므로 파일만 추가하면 시딩된다.**

---

### Step 5: 시딩 실행 및 검증

```bash
# 시딩 실행
pnpm --filter @harukoto/database db:seed

# 검증: Prisma Studio에서 확인
pnpm --filter @harukoto/database db:studio
```

**검증 체크리스트:**
- [ ] 각 레벨별 단어 수가 원본 CSV와 일치하는지
- [ ] partOfSpeech가 모두 유효한 enum 값인지
- [ ] exampleSentence/Reading/Translation이 모두 채워져 있는지
- [ ] order가 1부터 순서대로 부여되었는지
- [ ] 중복 단어 없는지 (word+reading+jlptLevel unique)
- [ ] 문법 패턴이 중복 없이 저장되었는지

---

## 작업 우선순위

**데이터 양이 많으므로 레벨별로 나누어 진행을 권장한다.**

### Phase A: N3 (최우선)
1. N3 어휘 ~1,210개 CSV → JSON 변환 + AI 보강
2. N3 문법 ~40개 직접 생성
3. 시딩 및 검증

### Phase B: N2
1. N2 어휘 ~2,240개 CSV → JSON 변환 + AI 보강
2. N2 문법 ~50개 직접 생성
3. 시딩 및 검증

### Phase C: N1
1. N1 어휘 ~2,670개 CSV → JSON 변환 + AI 보강
2. N1 문법 ~50개 직접 생성
3. 시딩 및 검증

---

## AI 보강 작업 가이드

### 배치 처리 권장

데이터가 많으므로 50~100개씩 배치로 처리한다.

**작업 흐름:**
1. CSV에서 50개씩 읽기
2. 각 단어에 대해:
   - `partOfSpeech` 판별
   - `exampleSentence` 생성 (해당 단어를 포함하는 자연스러운 예문)
   - `exampleReading` 생성 (예문의 히라가나)
   - `exampleTranslation` 생성 (예문의 한국어 번역)
   - `tags` 생성 (주제 카테고리 1~3개)
3. JSON 배열에 추가
4. 다음 배치 반복

### 예문 품질 기준
- 해당 JLPT 레벨에 맞는 난이도의 문장
- 단어의 의미가 명확히 드러나는 문장
- 일상에서 실제로 사용할 법한 자연스러운 문장
- N3: 중급 수준 (복문, 접속사 사용 가능)
- N2: 중상급 수준 (추상적 개념, 뉴스체 가능)
- N1: 상급 수준 (격식체, 문어체 가능)

### 태그 카테고리 예시
```
사람, 가족, 감정, 건강, 음식, 동물, 자연, 날씨, 시간,
장소, 교통, 여행, 학교, 직장, 비즈니스, 경제, 정치,
문화, 스포츠, 기술, 생활, 쇼핑, 요리, 인사, 기본
```

---

## 주의사항

1. **시드 스크립트 수정 불필요** — JSON 파일만 올바른 위치에 추가하면 자동 인식
2. **Unique 제약조건** — `(word, reading, jlptLevel)` 조합이 유일해야 함
3. **Upsert 방식** — 같은 키로 다시 시딩하면 업데이트됨 (안전)
4. **파일 크기** — N1 2,670개는 하나의 JSON 파일로 충분 (약 1~2MB)
5. **인코딩** — UTF-8 필수
6. **meaningKo 정제** — 원본 CSV의 `⇔`, `＝` 참조 표기는 제거하거나 별도 필드로
7. **린트/빌드** — 데이터 파일(JSON)은 린트 대상이 아니므로 별도 검증 불필요
