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
- lexical-risk STT retry:
  `docs/operations/plans/n4-wave3-draft-lexical-risk-stt-retry-2026-05-27.md`
- review queue:
  `docs/operations/plans/n4-wave3-draft-audio-qa-review-queue-2026-05-27.md`
- STT reconciliation:
  `docs/operations/plans/n4-wave3-draft-stt-reconciliation-2026-05-27.md`
- high-risk listening batch:
  `docs/operations/plans/n4-wave3-draft-high-risk-listening-batch-2026-05-27.md`
- source-cleanup post-regeneration audit:
  `docs/operations/plans/n4-wave3-draft-audio-qa-post-regeneration-audit-2026-05-27.md`
- lexical-risk post-regeneration audit:
  `docs/operations/plans/n4-wave3-draft-lexical-risk-post-regeneration-audit-2026-05-27.md`
- lexical-risk second post-regeneration audit:
  `docs/operations/plans/n4-wave3-draft-lexical-risk-second-post-regeneration-audit-2026-05-27.md`

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

After combining the first run and retry, applying the `HN4-018 script:3`
source cleanup, and running targeted regeneration for the three lexical-risk
script rows:

| Bucket | Count | Decision |
|---|---:|---|
| `P0_MACHINE_WARNING` | 0 | no machine-warning blocker |
| `LEXICAL_RISK` | 0 | all lexical-risk pending rows were either cleared or converted to explicit FLAG |
| `NEAR_JAPANESE_MATCH` | 6 | lower-risk spot-listen lane |
| `MIXED_PROMPT_STT_UNRELIABLE` | 24 | do not treat mismatch alone as audio fail |
| `NO_STT_TRANSCRIPT` | 5 | timeout-only rows remain review signals |

Current packet verdict summary:

| Verdict | Count |
|---|---:|
| `PENDING` | 41 |
| `PASS` | 2 |
| `FLAG` | 2 |
| `FAIL` | 0 |
| `WAIVED` | 0 |

## Lexical-Risk Remediation

The three original lexical-risk rows were retried with STT before regeneration.
All three still produced mismatch signals, so they were regenerated with the
same source text instead of changing the lesson content.

| Step | Scope | Machine pass | STT exact | PASS | FLAG |
|---|---:|---:|---:|---:|---:|
| first lexical-risk regeneration | 3 rows | 3 | 1 | 1 | 2 |
| second lexical-risk regeneration | 2 residual rows | 2 | 0 | 0 | 2 |

Resolved:

- `HN4-017 script:1` is now `PASS` after regenerated STT matched
  `忙しいですね。`

Residual blockers:

| Target | Source text | Latest STT signal | Decision |
|---|---|---|---|
| `HN4-018 script:0` | `この機械は壊れそうです。` | `この機械は、壊れそう。` | keep `FLAG`; the final `です` is still absent in STT after the second regeneration |
| `HN4-019 script:3` | `受付は混むそうですから、早く行きましょう。` | `てこれまではタコむそうでしたから、早く行きましょう。` | keep `FLAG`; the lexical transcript remains too divergent after the second regeneration |

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

The next implementation slice should resolve the two residual `FLAG` rows
before seed registry promotion. Options are another targeted TTS generation
strategy, source-level audio prompt adjustment that preserves the learning
sentence, or an explicit owner waiver if playback is judged acceptable despite
STT mismatch.

Mixed Korean/Japanese question prompt mismatches should remain review signals,
not automatic regeneration triggers.
