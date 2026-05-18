# N4 P0 Provider Fallback Clearance

> Status: APPLY CSV GENERATED
> Boundary: delegated AI-assisted verdicts only; not native-speaker approval

ASSUMPTION: After provider fallback regeneration, a P0 mixed Japanese/Korean
cloze prompt can be cleared when the MP3 probe has no blocker or silence
warning and the only remaining signal is STT mismatch. STT remains weak
evidence for these mixed prompt rows.

## Inputs

- Post-regeneration recommendation CSV: `docs/operations/plans/n4-human-audio-qa-p0-machine-warning-provider-fallback-post-regeneration-recommendations-2026-05-18.csv`
- Regeneration results CSV: `docs/operations/plans/n4-human-audio-qa-p0-machine-warning-provider-fallback-current-db-results-2026-05-18.csv`

## Summary

| Metric | Count |
|---|---:|
| Total rows | 11 |
| PASS rows | 10 |
| Held rows | 1 |

## Decisions

| Target | Decision | Basis | Provider/model | Audio |
|---|---|---|---|---|
| HN4-001 question:3 | PASS | provider fallback machine pass; STT mismatch only | gemini / gemini-2.5-flash-preview-tts | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-3-regen-20260518T055500Z.mp3) |
| HN4-002 question:4 | PASS | provider fallback machine pass; STT mismatch only | gemini / gemini-2.5-flash-preview-tts | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-4-regen-20260518T055500Z.mp3) |
| HN4-003 question:3 | PASS | provider fallback machine pass; STT mismatch only | gemini / gemini-2.5-flash-preview-tts | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-3-regen-20260518T055500Z.mp3) |
| HN4-003 question:4 | HOLD | post-regeneration warning remains | elevenlabs / eleven_multilingual_v2 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-4-regen-20260518T041500Z.mp3) |
| HN4-004 question:4 | PASS | provider fallback machine pass; STT mismatch only | gemini / gemini-2.5-flash-preview-tts | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-4-regen-20260518T055500Z.mp3) |
| HN4-005 question:4 | PASS | provider fallback machine pass; STT mismatch only | elevenlabs / eleven_multilingual_v2 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-4-regen-20260518T041500Z.mp3) |
| HN4-006 question:4 | PASS | provider fallback machine pass; STT mismatch only | gemini / gemini-2.5-flash-preview-tts | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-4-regen-20260518T055500Z.mp3) |
| HN4-008 question:3 | PASS | provider fallback machine pass; STT mismatch only | gemini / gemini-2.5-flash-preview-tts | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-3-regen-20260518T055500Z.mp3) |
| HN4-009 question:4 | PASS | provider fallback machine pass; STT mismatch only | gemini / gemini-2.5-flash-preview-tts | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-4-regen-20260518T055500Z.mp3) |
| HN4-010 question:4 | PASS | provider fallback machine pass; STT mismatch only | gemini / gemini-2.5-flash-preview-tts | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-4-regen-20260518T055500Z.mp3) |
| HN4-011 question:3 | PASS | provider fallback machine pass; STT mismatch only | gemini / gemini-2.5-flash-preview-tts | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-3-regen-20260518T055500Z.mp3) |

## Decision

Apply the companion CSV to update regenerated audio URLs, clear rows that
only have mixed-prompt STT mismatch remaining, and keep any row with
post-regeneration silence warning pending.
