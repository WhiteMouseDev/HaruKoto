# N1~N3 의심 항목 우선순위 재교정 보고서 (v3)

생성 시각(UTC): 2026-03-08

## 목적

- N1~N3 어휘 데이터에서 의심 항목을 우선순위로 선별해 재교정
- 원본(`raw`) 및 기존 결과(`final-v2`)는 보존
- DB 반영 없이 JSON 산출물만 생성

## 입력/출력

입력:
- `packages/database/data/vocabulary-reviewed/n1-words-reviewed-final-v2.json`
- `packages/database/data/vocabulary-reviewed/n2-words-reviewed-final-v2.json`
- `packages/database/data/vocabulary-reviewed/n3-words-reviewed-final-v2.json`
- `packages/database/data/raw/n1|n2|n3/*.csv`

출력:
- `packages/database/data/vocabulary-reviewed/n1-words-reviewed-final-v3.json`
- `packages/database/data/vocabulary-reviewed/n2-words-reviewed-final-v3.json`
- `packages/database/data/vocabulary-reviewed/n3-words-reviewed-final-v3.json`
- `packages/database/data/vocabulary-reviewed/n1-priority-recorrection-queue-v3.json`
- `packages/database/data/vocabulary-reviewed/n2-priority-recorrection-queue-v3.json`
- `packages/database/data/vocabulary-reviewed/n3-priority-recorrection-queue-v3.json`
- `packages/database/data/vocabulary-reviewed/n1-priority-recorrection-report-v3.json`
- `packages/database/data/vocabulary-reviewed/n2-priority-recorrection-report-v3.json`
- `packages/database/data/vocabulary-reviewed/n3-priority-recorrection-report-v3.json`
- `packages/database/data/vocabulary-reviewed/n1-n3-priority-recorrection-summary-v3.json`

## 우선순위 기준

- `POS_MISMATCH_HIGH`, `POS_MISMATCH`
- `ADVERB_SUSPECT`, `CONJUNCTION_SUSPECT`
- `MEANING_SUSPECT` (예: 참조표현만 남은 항목)
- `LOW_INFO_TRANSLATION`
- `GENERIC_TAGS`

점수 기반으로 큐를 정렬해 `priorityOrder`를 부여함.

## 재교정 결과 요약

| 레벨 | 전체 | 재교정 | POS 변경 | 예문/번역 갱신 |
|---|---:|---:|---:|---:|
| N1 | 2675 | 2030 | 33 | 2030 |
| N2 | 2244 | 1702 | 23 | 1702 |
| N3 | 1212 | 903 | 17 | 903 |

## 품질 게이트

`v3` 산출물 기준:
- 필수 필드 누락: 0
- `exampleReading` 한자 포함: 0
- `exampleTranslation` 일본어 혼입: 0
- `exampleTranslation` 한국어 미포함: 0
- 중복 키 `(word, reading, jlptLevel)`: 0

## 개선 포인트

- 저정보 템플릿 번역 패턴(기존 v2) 우선 치환
- 의심 품사 항목의 우선 교정 및 예문 재작성
- 번역용 의미 문자열 정규화(일본어/참조기호 제거)

## 잔여 수동 검수 권장 항목

- `MEANING_SUSPECT`가 남아 있는 항목
- 다의어/문맥 의존 의미(예: 품사 복수 가능 단어)
- 사전식 메타 예문을 실제 사용 문맥 예문으로 바꾸는 최종 편집 단계

핵심:
- 자동 우선순위 재교정은 완료됨.
- 앱 신뢰도 기준(오역 제로)에 맞추려면 `priority queue v3` 상위부터 전수 수동 검수를 이어가야 함.
