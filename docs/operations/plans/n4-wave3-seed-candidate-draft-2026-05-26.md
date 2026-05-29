# N4 Wave 3 Seed Candidate Draft - 2026-05-26

## Goal

N4 official lesson coverage를 늘리기 전에 PDF coverage anchor를 기준으로
새 N4 draft seed candidate 5개를 작성한다. 이 작업은 공식 lesson seed
승격이 아니라 candidate review, TTS readiness, human review로 넘기기 위한
입력 데이터 확장이다.

ASSUMPTION: `/Users/kimkunwoo/Downloads/japanese` PDF는 coverage anchor로만
사용한다. PDF의 예문, 설명문, 문항 문장을 HaruKoto lesson content로 복제하지
않는다.

ASSUMPTION: 현재 사람 전문가가 없는 상태이므로 AI가 초안 작성과
다중 검수를 맡는다. `reviewerDecision: APPROVED`는 AI-only candidate
approval이며, 사람 전문가 승인이나 TTS/audio runtime 승인은 아니다.

## Candidate Slice

| Candidate | Target lesson | Topic | Grammar | Review |
| --- | --- | --- | --- | --- |
| `lsc-n4-tari-tari-suru-001` | `HN4-017` | `topic-tari-tari-suru` | `〜たり〜たりする` | `APPROVED` |
| `lsc-n4-souda-appearance-001` | `HN4-018` | `topic-souda-hearsay-appearance-a` | `〜そうだ` | `APPROVED` |
| `lsc-n4-souda-hearsay-001` | `HN4-019` | `topic-souda-hearsay-appearance-b` | `〜そうだ` | `APPROVED` |
| `lsc-n4-mono-functions-001` | `HN4-020` | `topic-mono-functions` | `〜ものだ` | `APPROVED` |
| `lsc-n4-hazu-da-001` | `HN4-021` | `topic-hazu-da` | `〜はずだ` | `APPROVED` |

## AI Multi-Pass Review - 2026-05-27

Boundary: delegated AI curriculum review only. This is not native-speaker
human approval, not professional Japanese-teacher approval, and not TTS/audio
runtime approval.

Three parallel AI review passes were used before candidate approval:

- Japanese grammar/naturalness review: no blocking grammar, reading, kana, or
  Korean translation issue; flagged `そうだ` specificity and `ものだ` focus.
- Korean learner pedagogy review: flagged answer-position bias, weak
  distractors, premature `そうだ` exposure in the `たり` lesson, missing
  `そうだ` contrast practice, literal `もの` drift, and short reorder items.
- Runtime/TTS contract review: confirmed target coverage, API bundle sync,
  validator coverage, and that the pre-approval gate was blocked only by
  review decisions. TTS generation remains a separate gate.

Applied edits before approval:

- `HN4-017`: changed `忙しそうですね` to `忙しいですね` to avoid exposing
  the next lesson's target grammar early.
- `HN4-018`: changed `別の機械なら簡単そうです` to
  `別の機械なら操作が簡単そうです` and added appearance-vs-hearsay
  contrast.
- `HN4-019`: added hearsay-vs-appearance contrast and strengthened
  `だそうです` reorder practice.
- `HN4-020`: replaced literal `大切なもの` practice with normative
  `規則はみんなで守るものですね`.
- `HN4-021`: retained content and adjusted answer positions/distractors.
- All five candidates: varied multiple-choice answer positions and strengthened
  distractors where they were too easy or too distant.

Post-review candidate state:

| Candidate | Target lesson | AI review decision | Boundary |
| --- | --- | --- | --- |
| `lsc-n4-tari-tari-suru-001` | `HN4-017` | `APPROVED` | AI-only candidate approval |
| `lsc-n4-souda-appearance-001` | `HN4-018` | `APPROVED` | AI-only candidate approval |
| `lsc-n4-souda-hearsay-001` | `HN4-019` | `APPROVED` | AI-only candidate approval |
| `lsc-n4-mono-functions-001` | `HN4-020` | `APPROVED` | AI-only candidate approval |
| `lsc-n4-hazu-da-001` | `HN4-021` | `APPROVED` | AI-only candidate approval |

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
  5개를 AI-only `APPROVED` review row로 갱신.

## Remaining Gates

1. TTS readiness: 새 target 50개를 생성하고 admin review 또는 확장된
   audio QA flow로 승인한다.
2. Official seed promotion: approval 후 `HN4-017`부터 `HN4-021`까지
   official lesson seed로 승격한다.
3. Lesson human review substitute: 공식 seed 승격 후
   `lesson-human-review` packet을 별도로 생성하되, 사람 전문가가 없으면
   같은 AI-only boundary를 명시한 다중 AI 검수로 대체한다.
4. Runtime UAT: web/mobile lesson playback, TTS 재생, question flow를
   target runtime에서 확인한다.
5. Future human expert audit: 사람 일본어 전문가를 확보하면 AI 승인 row를
   샘플링 또는 전수 재검토한다.
