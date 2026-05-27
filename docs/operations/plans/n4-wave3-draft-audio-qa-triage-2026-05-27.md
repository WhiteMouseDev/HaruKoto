# N4 Wave 3 Draft Audio QA Triage - 2026-05-27

> Status: REVIEW REQUIRED
> Scope: `N4-CH05` DRAFT TTS audio for `HN4-017` through `HN4-021`
> Boundary: delegated AI/STT triage only; not native-speaker approval and not
> a `DRAFT` to `PILOT` publish decision.

## Inputs

- human-review packet:
  `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md`
- machine QA:
  `docs/operations/plans/n4-wave3-draft-tts-machine-report-2026-05-27.md`
- first STT assist:
  `docs/operations/plans/n4-wave3-draft-tts-stt-assist-run-2026-05-27.md`
- timeout-target STT retry:
  `docs/operations/plans/n4-wave3-draft-tts-stt-timeout-retry-2026-05-27.md`
- review queue:
  `docs/operations/plans/n4-wave3-draft-audio-qa-review-queue-2026-05-27.md`
- STT reconciliation:
  `docs/operations/plans/n4-wave3-draft-stt-reconciliation-2026-05-27.md`
- high-risk listening batch:
  `docs/operations/plans/n4-wave3-draft-high-risk-listening-batch-2026-05-27.md`
- source-cleanup post-regeneration audit:
  `docs/operations/plans/n4-wave3-draft-audio-qa-post-regeneration-audit-2026-05-27.md`

## Result

The non-STT machine gate remains clean:

- total targets: 45
- machine pass: 45
- machine blockers: 0
- machine warnings: 0

The first STT assist run had 18 timeout rows. A targeted retry using
`--target-key` reduced unresolved timeout rows to one:

| Metric | First run | Targeted retry |
|---|---:|---:|
| Retry scope | 45 | 18 |
| STT transcribed | 27 | 17 |
| STT exact matches | 6 | 4 |
| STT mismatches | 21 | 13 |
| STT errors | 18 | 1 |

After combining the first run and retry, then applying the `HN4-018 script:3`
source cleanup and post-regeneration PASS:

| Bucket | Count | Decision |
|---|---:|---|
| `P0_MACHINE_WARNING` | 0 | no machine-warning blocker |
| `LEXICAL_RISK` | 3 | review first; regenerate unchanged source only if playback is unclear/wrong |
| `NEAR_JAPANESE_MATCH` | 6 | lower-risk spot-listen lane |
| `MIXED_PROMPT_STT_UNRELIABLE` | 24 | do not treat mismatch alone as audio fail |
| `NO_STT_TRANSCRIPT` | 1 | one remaining timeout prompt |

## High-Risk Rows

These are the first rows to inspect before clearing the CH05 audio gate:

| Target | Source text | STT signal | Recommended next action |
|---|---|---|---|
| `HN4-017 script:1` | `忙しいですね。` | `忙しい` | listen for the final `ですね`; regenerate unchanged source only if clipped |
| `HN4-018 script:0` | `この機械は壊れそうです。` | `この議会は壊れそう。` | listen for `機械`; likely STT homophone noise unless playback confirms wrong word |
| `HN4-019 script:3` | `受付は混むそうですから、早く行きましょう。` | `てくてはさおむそうですから早く行きましょう。` | listen carefully; regenerate unchanged source if intelligibility is poor |

## Source Cleanup Decision

Parallel AI review found no must-fix source rewrite before regeneration.

The optional cleanup for `HN4-018 script:3` was applied:

- old:
  `田中さんも大変そうです。早めに相談しましょう。`
- new:
  `この操作は大変そうです。早めに相談しましょう。`
- reason:
  `田中さん` was not introduced in the short dialogue and also produced an STT
  near-match signal. The replacement keeps the lesson target `大変そうです`
  while staying anchored to the machine-operation context.

Post-regeneration evidence for `HN4-018 script:3`:

- machine pass: 1/1
- STT exact match: 1/1
- recommended verdict: `PASS`
- boundary: delegated AI/STT QA only; not native-speaker review

## Decision

Do not promote `N4-CH05` to `PILOT` yet.

The next implementation slice should keep source unchanged and regenerate only
confirmed high-risk script rows after a delegated listening/QA decision.

Mixed Korean/Japanese question prompt mismatches should remain review signals,
not automatic regeneration triggers.
