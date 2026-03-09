# 작업 지시: 단어 데이터 AI 보강

> N5(574개) + N4(867개) = 1,441개 단어에 품사, 예문을 추가하는 작업.
> 작업 완료 후 이 문서는 삭제할 것.

---

## 개요

현재 CSV에는 `reading, word, jlptLevel, meaningKo` 4개 컬럼만 있다.
아래 4개 컬럼을 AI로 채운다:

| 추가 컬럼 | 설명 | 예시 |
|----------|------|------|
| partOfSpeech | 품사 | VERB |
| exampleSentence | 일본어 예문 | 友達に会いました。 |
| exampleReading | 예문 히라가나 | ともだちにあいました。 |
| exampleTranslation | 예문 한국어 번역 | 친구를 만났습니다. |

---

## 작업 흐름

```
Google Sheets에서 N5/N4 필터 → 50개씩 복사
  → Claude App 프로젝트에 붙여넣기 → 보강 결과 받기
  → Google Sheets에 E~H 열 붙여넣기
  → 반복 (약 29배치)
```

---

## Step 1: Claude App 프로젝트 설정

PDF 변환 프로젝트와 **별도 프로젝트**를 만들거나, 기존 프로젝트의 지침을 변경한다.

### 프로젝트 설명

```
일본어 단어 데이터에 품사, 예문을 추가하는 AI 보강 작업
```

### 지침

```
일본어 단어 데이터에 누락된 필드를 채우는 작업을 수행한다.

## 입력 형식
CSV 4컬럼이 주어진다:
reading,word,jlptLevel,meaningKo

## 출력 형식
CSV 4컬럼을 추가하여 반환한다 (입력 4컬럼은 절대 수정하지 않는다):
reading,word,jlptLevel,meaningKo,partOfSpeech,exampleSentence,exampleReading,exampleTranslation

## partOfSpeech 규칙
반드시 아래 11개 값 중 하나를 사용한다:
- NOUN: 명사 (学校, 友達, 天気)
- VERB: 동사 (食べる, 行く, する)
- I_ADJECTIVE: い형용사 (大きい, 高い, おいしい)
- NA_ADJECTIVE: な형용사 (静か, 好き, 大変)
- ADVERB: 부사 (とても, もう, ゆっくり)
- PARTICLE: 조사 (は, が, を, に, で)
- CONJUNCTION: 접속사 (しかし, そして, でも)
- COUNTER: 조수사 (〜つ, 〜人, 〜個, 〜枚)
- EXPRESSION: 인사말/관용구 (おはようございます, すみません)
- PREFIX: 접두어 (お〜, ご〜, 毎〜)
- SUFFIX: 접미어 (〜さん, 〜的, 〜中)

## 분류가 애매한 경우
- する동사 (勉強する): VERB
- い로 끝나지만 な형용사인 것 (きれい, 有名): NA_ADJECTIVE
- 의성어/의태어 (ゆっくり, はっきり): ADVERB
- 인사/감사/사과 표현: EXPRESSION
- 숫자/요일/월: NOUN

## 예문 규칙
1. 해당 단어를 반드시 예문에 포함할 것
2. JLPT 레벨에 맞는 난이도:
   - N5: です/ます형, 기본 문형만 사용
   - N4: て형, たい형, 가능형 등 N4 문법까지 사용
3. 자연스럽고 실용적인 문장 (교과서적인 예문)
4. 1문장, 적당한 길이 (10~25자)

## exampleReading 규칙
- 예문의 모든 한자를 히라가나로 변환
- 카타카나는 카타카나 그대로 유지
- 조사, 활용어미 등은 그대로

## exampleTranslation 규칙
- 자연스러운 한국어 번역
- 직역보다 의역 우선

## 출력 규칙
- 입력된 reading, word, jlptLevel, meaningKo는 한 글자도 수정하지 않는다
- CSV 값에 쉼표가 포함되면 큰따옴표로 감싸기
- 빈 행 없이 연속 출력
- 헤더 포함 여부는 사용자 지시에 따른다
```

---

## Step 2: 배치 작업

### 배치 크기: 50개

1,441개 ÷ 50 = **약 29배치**

50개인 이유:
- 너무 적으면 (20개) 배치 수가 많아 손이 많이 감
- 너무 많으면 (100개) AI가 후반부에서 품질이 떨어지거나 누락 발생
- 50개가 품질과 효율의 균형점

### N5부터 시작 (574개 = 12배치)

Google Sheets에서:
1. jlptLevel을 N5로 필터링
2. A~D열, 1~50행 복사

### 프롬프트

**1차 배치:**
```
아래 50개 단어에 partOfSpeech, exampleSentence, exampleReading, exampleTranslation을 추가해주세요.
헤더 포함해서 CSV로 출력해주세요.

[여기에 50개 CSV 붙여넣기]
```

**2차 이후:**
```
다음 50개입니다. 헤더 제외, 데이터만 출력해주세요.

[여기에 50개 CSV 붙여넣기]
```

### 결과 붙여넣기

Claude가 반환한 CSV에서 **E~H열(partOfSpeech ~ exampleTranslation)만** 복사해서
Google Sheets의 해당 행 E~H열에 붙여넣기.

> ⚠️ A~D열을 통째로 덮어쓰지 않도록 주의. 원본이 바뀔 수 있음.

---

## Step 3: 배치 관리 팁

### 진행 추적

Google Sheets에 I열을 추가해서 배치 상태를 기록:

| I열 헤더 | 값 |
|---------|---|
| status | `done` 또는 빈 칸 |

보강이 완료된 행에 `done`을 넣으면 어디까지 했는지 추적 가능.

### 대화 교체 타이밍

- **4~5배치(200~250개)마다** 새 대화 시작
- 프로젝트 내 새 대화이므로 지침은 유지됨
- 새 대화에서는 다시 "헤더 포함"으로 시작

### 예상 소요 시간

| 작업 | 시간 |
|------|------|
| N5 574개 (12배치) | 1.5~2시간 |
| N4 867개 (18배치) | 2~3시간 |
| 검수 | 30분~1시간 |
| **총합** | **약 4~6시간** |

하루에 다 할 필요 없음. N5 먼저 완료 → 시딩 → 앱 확인 → N4 진행.

---

## Step 4: 검수

### Google Sheets 수식 검수

모든 배치 완료 후:

```
partOfSpeech 빈 셀:  =COUNTBLANK(E2:E1442)  → 0이어야 함
예문 빈 셀:          =COUNTBLANK(F2:F1442)  → 0이어야 함
예문 읽기 빈 셀:     =COUNTBLANK(G2:G1442)  → 0이어야 함
예문 번역 빈 셀:     =COUNTBLANK(H2:H1442)  → 0이어야 함
```

### 잘못된 partOfSpeech 찾기

Google Sheets에서 E열 필터 → 아래 11개 외의 값이 있는지 확인:
```
NOUN, VERB, I_ADJECTIVE, NA_ADJECTIVE, ADVERB,
PARTICLE, CONJUNCTION, COUNTER, EXPRESSION, PREFIX, SUFFIX
```

### 샘플 검수 (수동)

N5에서 10개, N4에서 10개를 랜덤으로 골라:
- [ ] 예문에 해당 단어가 실제로 포함되어 있는가?
- [ ] 예문 난이도가 레벨에 맞는가? (N5 예문에 N3 문법이 쓰이면 안 됨)
- [ ] exampleReading이 정확한가? (한자 → 히라가나 변환)
- [ ] 한국어 번역이 자연스러운가?
- [ ] partOfSpeech가 맞는가? (특히 きれい→NA_ADJECTIVE, 勉強する→VERB)

---

## Step 5: CSV → JSON 변환

검수 완료 후, Google Sheets에서 CSV로 내보내기.
이후 변환 스크립트로 레벨별 JSON 파일 생성 → 시딩.

이 단계는 Claude Code에서 진행. (별도 작업 지시)

---

## 작업 순서 요약

```
1. Claude App 프로젝트 설정 (지침 등록)
2. N5 574개 → 12배치 보강 → Sheets에 붙여넣기
3. N5 검수
4. (선택) N5만 먼저 JSON 변환 + 시딩 + 앱 확인
5. N4 867개 → 18배치 보강 → Sheets에 붙여넣기
6. N4 검수
7. 전체 CSV → JSON 변환 + 시딩
```
