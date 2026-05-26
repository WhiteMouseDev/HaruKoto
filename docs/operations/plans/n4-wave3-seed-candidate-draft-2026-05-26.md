# N4 Wave 3 Seed Candidate Draft - 2026-05-26

## Goal

N4 official lesson coverage를 늘리기 전에 PDF coverage anchor를 기준으로
새 N4 draft seed candidate 5개를 작성한다. 이 작업은 공식 lesson seed
승격이 아니라 candidate review, TTS readiness, human review로 넘기기 위한
입력 데이터 확장이다.

ASSUMPTION: `/Users/kimkunwoo/Downloads/japanese` PDF는 coverage anchor로만
사용한다. PDF의 예문, 설명문, 문항 문장을 HaruKoto lesson content로 복제하지
않는다.

ASSUMPTION: 현재 사람 전문가가 없는 상태이므로 AI가 초안을 작성하되,
`reviewerDecision: PENDING`을 유지해 공식 승격 전 검토 gate를 남긴다.

## Candidate Slice

| Candidate | Target lesson | Topic | Grammar | Review |
| --- | --- | --- | --- | --- |
| `lsc-n4-tari-tari-suru-001` | `HN4-017` | `topic-tari-tari-suru` | `〜たり〜たりする` | `PENDING` |
| `lsc-n4-souda-appearance-001` | `HN4-018` | `topic-souda-hearsay-appearance-a` | `〜そうだ` | `PENDING` |
| `lsc-n4-souda-hearsay-001` | `HN4-019` | `topic-souda-hearsay-appearance-b` | `〜そうだ` | `PENDING` |
| `lsc-n4-mono-functions-001` | `HN4-020` | `topic-mono-functions` | `〜ものだ` | `PENDING` |
| `lsc-n4-hazu-da-001` | `HN4-021` | `topic-hazu-da` | `〜はずだ` | `PENDING` |

## Data Contract Updates

- `example-bank.json`: 각 후보의 HaruKoto-authored 예문 1개씩 추가.
- `lesson-draft-blueprints.json`: 기존 blueprint가 없던 covered topic 2개는
  reinforcement blueprint로 추가하고, 기존 blueprint 3개에는 새 example을
  연결.
- `lesson-seed-candidates.json`: runtime-supported question type만 사용하는
  draft candidate 5개 추가.
- `tts-target-manifest.json`: example sentence 5개, candidate script line
  20개, candidate question prompt 25개를 TTS target으로 추가.
- `tts-review-batches.json`: 새 target 50개를 review batch에 연결하고
  count/status summary를 재계산.
- `lesson-seed-candidate-review/n4-candidate-review.json`: 미승격 N4 후보
  5개를 PENDING review row로 재생성.

## Remaining Gates

1. Candidate curriculum review: `PENDING` 5개를 `APPROVED` 또는
   `NEEDS_EDIT`으로 판정한다.
2. TTS readiness: 새 target 50개를 생성하고 admin review 또는 확장된
   audio QA flow로 승인한다.
3. Official seed promotion: approval 후 `HN4-017`부터 `HN4-021`까지
   official lesson seed로 승격한다.
4. Lesson human review: 공식 seed 승격 후 `lesson-human-review` packet을
   별도로 생성해 내용, 문항, 오디오를 검토한다.
5. Runtime UAT: web/mobile lesson playback, TTS 재생, question flow를
   target runtime에서 확인한다.
