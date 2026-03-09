# N1~N3 어휘 콘텐츠 품질 보증 작업 계획

## 목적

- 원본 CSV(`packages/database/data/raw/n1|n2|n3`)는 변경하지 않는다.
- N1/N2/N3 어휘를 전수 기준으로 검증한다.
- 검증 통과 데이터와 검수 필요 데이터를 분리해 신규 파일로 관리한다.

## 생성된 검증 도구

- `packages/database/scripts/audit-n123-vocabulary.mjs`
  - 원본 CSV ↔ 현재 JSON 대조
  - 품질 규칙 기반 자동 감사
  - 결과 파일 생성
- `packages/database/scripts/prepare-vocab-manual-review-batches.mjs`
  - 검수 큐를 배치(기본 100개)로 분할
- `packages/database/scripts/compile-vocab-reviewed-final.mjs`
  - 자동 승인 + 수동 승인 배치를 병합해 최종 reviewed 파일 생성

## 실행 명령

```bash
# 1) N1/N2/N3 전수 감사
pnpm --filter @harukoto/database vocab:audit:n123

# 2) 수동 검수 배치 생성 (예: N2, 100개 단위)
pnpm --filter @harukoto/database vocab:review:batch n2 100

# 3) 수동 검수 반영 후 최종 파일 병합 (예: N2)
pnpm --filter @harukoto/database vocab:review:compile n2
```

## 감사 산출물

경로: `packages/database/data/vocabulary-reviewed/`

- `n1-audit-report-v1.json`
- `n2-audit-report-v1.json`
- `n3-audit-report-v1.json`
- `n1-words-reviewed-v1.json` (자동 승인)
- `n2-words-reviewed-v1.json` (자동 승인)
- `n3-words-reviewed-v1.json` (자동 승인)
- `n1-words-review-queue-v1.json` (수동 검수 필요)
- `n2-words-review-queue-v1.json` (수동 검수 필요)
- `n3-words-review-queue-v1.json` (수동 검수 필요)

주의:
- `vocabulary-reviewed`는 현재 시드 스캔 경로(`data/vocabulary`) 밖이므로 자동 시딩되지 않는다.
- 최종 반영 전 반드시 수동 검수 후 `*-words-reviewed-final-v1.json`을 사용한다.

## 현재 1차 감사 결과 (2026-03-08)

- N1: raw 2,675 / 자동승인 0 / 수동검수 2,675
- N2: raw 2,244 / 자동승인 0 / 수동검수 2,244
- N3: raw 1,212 / 자동승인 206 / 수동검수 1,006

N2 주요 이슈:
- 템플릿 예문 반복
- 예문 번역에 일본어 포함
- 태그 과도 단순화
- 일부 품사 의심

## 수동 검수 운영 규칙

- `manual-review/<level>/batch-xxxx.json` 단위로 검수한다.
- 각 항목에서:
  - `decision`: `PENDING` -> `APPROVED` 또는 `REJECTED`
  - `corrected` 필드를 최종값으로 수정
  - `reviewer`, `reviewedAt`, `reviewerNotes` 기록
- `APPROVED`인데 `corrected` 필수 필드가 비어 있으면 병합 시 제외된다.

## 최종 반영 권장 절차

1. 레벨별 수동 검수 완료
2. `vocab:review:compile <level>` 실행
3. 생성된 `nX-words-reviewed-final-v1.json`을 검토
4. 필요 시 `data/vocabulary/nX-words.json` 교체 또는 신규 파이프라인 연결
5. 시딩 및 DB 검증
