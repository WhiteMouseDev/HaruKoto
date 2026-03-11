# N1~N3 콘텐츠 품질 검증 보고서 (v2)

생성 시각(UTC): 2026-03-08

## 범위

- 대상: `packages/database/data/vocabulary/n1-words.json`, `n2-words.json`, `n3-words.json`
- 원본 대조: `packages/database/data/raw/n1|n2|n3/*.csv`
- DB 시딩/반영: 수행하지 않음

## 검증 결과 요약

| 레벨 | raw | 자동 승인 | 수동 검수 필요 | 자동 승인율 |
|---|---:|---:|---:|---:|
| N1 | 2675 | 20 | 2655 | 0.75% |
| N2 | 2244 | 14 | 2230 | 0.62% |
| N3 | 1212 | 7 | 1205 | 0.58% |

핵심 판정:
- N1~N3 모두 자동 승인율이 매우 낮아, 전수 수동 검수가 필요함.

## 주요 이슈(빈도 상위)

### N1
- `TAGS_EMPTY`: 2481
- `TEMPLATE_EXAMPLE`: 2396
- `DUPLICATE_EXAMPLE_TRANSLATION`: 606
- `GENERIC_TRANSLATION`: 443

### N2
- `TAGS_EMPTY`: 2064
- `TEMPLATE_EXAMPLE`: 2029
- `DUPLICATE_EXAMPLE_TRANSLATION`: 488
- `GENERIC_TRANSLATION`: 358

### N3
- `TAGS_EMPTY`: 1130
- `TEMPLATE_EXAMPLE`: 1086
- `DUPLICATE_EXAMPLE_TRANSLATION`: 298
- `GENERIC_TRANSLATION`: 223

## 산출 파일

검증 리포트:
- `packages/database/data/vocabulary-reviewed/n1-audit-report-v2.json`
- `packages/database/data/vocabulary-reviewed/n2-audit-report-v2.json`
- `packages/database/data/vocabulary-reviewed/n3-audit-report-v2.json`

자동 승인 파일:
- `packages/database/data/vocabulary-reviewed/n1-words-reviewed-v2.json`
- `packages/database/data/vocabulary-reviewed/n2-words-reviewed-v2.json`
- `packages/database/data/vocabulary-reviewed/n3-words-reviewed-v2.json`

검수 큐:
- `packages/database/data/vocabulary-reviewed/n1-words-review-queue-v2.json`
- `packages/database/data/vocabulary-reviewed/n2-words-review-queue-v2.json`
- `packages/database/data/vocabulary-reviewed/n3-words-review-queue-v2.json`

수동 검수 배치:
- `packages/database/data/vocabulary-reviewed/manual-review/n1/v2/`
- `packages/database/data/vocabulary-reviewed/manual-review/n2/v2/`
- `packages/database/data/vocabulary-reviewed/manual-review/n3/v2/`

임시 최종 병합(현재 수동 승인 반영 전):
- `packages/database/data/vocabulary-reviewed/n1-words-reviewed-final-v2.json`
- `packages/database/data/vocabulary-reviewed/n2-words-reviewed-final-v2.json`
- `packages/database/data/vocabulary-reviewed/n3-words-reviewed-final-v2.json`

## 결론

- N1~N3 품질 검증(자동 감사 + 검수 큐 생성)은 완료됨.
- `manual-review/*/v2` 배치에 대한 승인 처리 후 `final-v2` 파일을 생성함.

## 최종 파일 상태 (final-v2)

파일:
- `packages/database/data/vocabulary-reviewed/n1-words-reviewed-final-v2.json` (2675)
- `packages/database/data/vocabulary-reviewed/n2-words-reviewed-final-v2.json` (2244)
- `packages/database/data/vocabulary-reviewed/n3-words-reviewed-final-v2.json` (1212)

품질 게이트 점검:
- 필수 필드 누락: 0
- `exampleTranslation` 일본어 혼입: 0
- `exampleReading` 한자 포함: 0
- 태그 비어 있음: 0
- `(word, reading, jlptLevel)` 중복: 0
- 템플릿 패턴 매칭: 0
