# N4 Audio QA STT Reconciliation

> Status: TRIAGE ONLY - no verdicts applied
> Boundary: STT mismatch reconciliation only; does not replace listening or native-speaker review

ASSUMPTION: This report helps reduce review ambiguity while preserving
the current verdict gate. It does not set `PASS`, `FLAG`, `FAIL`, or
`WAIVED` on any packet row.

## Sources

- Packet: `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-tts-machine-report-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-tts-stt-assist-run-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-tts-stt-timeout-retry-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-lexical-risk-stt-retry-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-tts-stt-no-transcript-retry-2026-05-27.md`

## Summary

| Metric | Count |
|---|---:|
| Total review items | 45 |
| Pending review-signal items | 8 |
| P0 machine-warning retained first | 0 |
| P1 STT-only items | 8 |
| Canonical text matches | 0 |
| Near Japanese matches | 7 |
| Mixed/Korean prompt STT-unreliable | 1 |
| Lexical-risk Japanese mismatches | 0 |
| Missing STT transcript | 0 |

## Review Order

1. Listen to `P0_MACHINE_WARNING` rows first because high silence ratio
   can hide pacing or truncation problems even when the audio file exists.
2. Review `LEXICAL_RISK` rows next because the transcript diverges from
   the source enough to suggest possible wrong-word audio.
3. Use `NEAR_JAPANESE_MATCH` and `CANONICAL_MATCH` rows as lower-risk
   candidates for delegated PASS after a spot listen.
4. Treat `MIXED_PROMPT_STT_UNRELIABLE` as a prompt-design/STT limitation;
   decide by direct playback rather than transcript mismatch alone.

## CSV Apply Boundary

The companion CSV leaves `new_verdict` and `new_notes` blank. Fill those
columns only after direct listening or an explicitly delegated review step.


## P0_MACHINE_WARNING

- None

## LEXICAL_RISK

- None

## NEAR_JAPANESE_MATCH

| Bucket | Target | Source text | STT transcript | Similarity | Signals | Recommended action | Audio |
|---|---|---|---|---:|---|---|---|
| NEAR_JAPANESE_MATCH | HN4-018 script:2 | 別の機械なら操作が簡単そうです。 | 別の機会なら操作が簡単そうです。 | 0.933 | TRANSCRIPTION_TEXT_MISMATCH:別の機会なら操作が簡単そうです。 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-2.mp3) |
| NEAR_JAPANESE_MATCH | HN4-019 script:0 | 明日の会議は三時から始まるそうです。 | 明日の会議は3時から始まるそうです。 | 0.944 | TRANSCRIPTION_TEXT_MISMATCH:明日の会議は3時から始まるそうです。 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-0.mp3) |
| NEAR_JAPANESE_MATCH | HN4-020 script:0 | 約束は守るものです。 | 約束は守るもの。 | 0.875 | TRANSCRIPTION_TEXT_MISMATCH:約束は守るもの。 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-0.mp3) |
| NEAR_JAPANESE_MATCH | HN4-020 script:2 | 挨拶は普通、先にするものです。 | 挨拶は普通1000にするものです。 | 0.828 | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:挨拶は普通1000にするものです。 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-2.mp3) |
| NEAR_JAPANESE_MATCH | HN4-021 script:0 | 予約したので、席はあるはずです。 | 予約したので昔はあるはずです。 | 0.929 | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:予約したので昔はあるはずです。 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-0.mp3) |
| NEAR_JAPANESE_MATCH | HN4-021 script:2 | 会議の予定は午後に決まるはずです。 | 会議の予定は午後二時に決まるはずです。 | 0.914 | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:会議の予定は午後二時に決まるはずです。 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-2.mp3) |
| NEAR_JAPANESE_MATCH | HN4-021 script:3 | 準備はできそうですね。 | 準備はできそうね | 0.889 | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:準備はできそうね | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-3.mp3) |

## CANONICAL_MATCH

- None

## MIXED_PROMPT_STT_UNRELIABLE

| Bucket | Target | Source text | STT transcript | Similarity | Signals | Recommended action | Audio |
|---|---|---|---|---:|---|---|---|
| MIXED_PROMPT_STT_UNRELIABLE | HN4-019 question:4 | 들은 정보를 전달할 때 알맞은 표현은? | 聞いた情報を伝えるとき、適切な表現は | 0.000 | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:聞いた情報を伝えるとき、適切な表現は | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-4.mp3) |

## NO_STT_TRANSCRIPT

- None

## Decision

Broad/full N4 rollout remains blocked. This triage only narrows the
remaining 8 pending review-signal audio QA rows
into review lanes and does not lower the verdict gate by itself.
