# N4 Audio QA High-Risk Listening Batch

> Status: LISTENING BATCH - no verdicts applied
> Boundary: high-risk audio review surface only; does not approve rollout

ASSUMPTION: This batch only separates rows that should be listened to
first. It does not set `PASS`, `FLAG`, `FAIL`, or `WAIVED` on any packet
row, and it does not replace native-speaker review.

## Sources

- Packet: `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-tts-machine-report-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-tts-stt-assist-run-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-tts-stt-timeout-retry-2026-05-27.md`

## Summary

| Metric | Count |
|---|---:|
| Total review items | 45 |
| Pending review-signal items | 39 |
| High-risk listening batch | 3 |
| P0 machine-warning rows | 0 |
| Lexical-risk rows | 3 |

## Review Sequence

1. Listen to `P0_MACHINE_WARNING` rows first. These rows include machine
   warnings such as silence-ratio signals, so pacing or truncation can hide
   behind an otherwise reachable audio URL.
2. Listen to `LEXICAL_RISK` rows next. These rows have Japanese source/STT
   divergence large enough that wrong-word audio is plausible.
3. Leave `new_verdict` and `new_notes` blank until direct listening or an
   explicitly delegated review step confirms the audio quality.

## P0_MACHINE_WARNING

- None

## LEXICAL_RISK

| Bucket | Target | Source text | STT transcript | Similarity | Signals | Recommended action | Audio |
|---|---|---|---|---:|---|---|---|
| LEXICAL_RISK | HN4-017 script:1 | 忙しいですね。 | 忙しい | 0.667 | TRANSCRIPTION_TEXT_MISMATCH:忙しい | listen carefully before PASS; prefer FLAG when the source text is not clearly spoken | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/script-line-1.mp3) |
| LEXICAL_RISK | HN4-018 script:0 | この機械は壊れそうです。 | この議会は壊れそう。 | 0.700 | TRANSCRIPTION_TEXT_MISMATCH:この議会は壊れそう。 | listen carefully before PASS; prefer FLAG when the source text is not clearly spoken | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-0.mp3) |
| LEXICAL_RISK | HN4-019 script:3 | 受付は混むそうですから、早く行きましょう。 | てくてはさおむそうですから早く行きましょう。 | 0.800 | TRANSCRIPTION_TEXT_MISMATCH:てくてはさおむそうですから早く行きましょう。 | listen carefully before PASS; prefer FLAG when the source text is not clearly spoken | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-3.mp3) |

## CSV And HTML Use

The companion CSV is an input worksheet only. The HTML file is a static
listening surface with audio controls. Neither file applies verdicts.

## Decision

Broad/full N4 rollout remains blocked. This batch makes the first listening
slice explicit but does not lower the audio-quality verdict gate.
