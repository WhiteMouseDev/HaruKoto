# N4 Audio QA Verdict Regeneration Plan

> Status: REGENERATION HANDOFF - no audio generated
> Boundary: planning artifact only; no TTS provider call, storage write,
> packet verdict update, or native-speaker review is performed here

ASSUMPTION: Existing blocker verdict rows should stay blocking until
they are regenerated and re-reviewed, or explicitly waived after direct
listening. This plan only extracts the exact targets that need that next
step.

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
| Total review targets | 45 |
| Current PASS verdicts | 41 |
| Current PENDING verdicts | 0 |
| Current FLAG verdicts | 4 |
| Current FAIL verdicts | 0 |
| Source verdict filter | FLAG |
| Regeneration manifest rows | 4 |
| Script-line rows | 4 |
| Question-prompt rows | 0 |

## Packet Distribution

| Packet | Selected targets |
|---|---:|
| `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` | 4 |

## Execution Boundary

`scripts/generate_n4_pilot_tts_batch.py` currently generates missing TTS
coverage only. Do not expect it to replace selected rows because
their current audio records already exist. A targeted replacement path
must create a new audio object and update the matching `tts_audio`
record, or record an explicit direct-listening waiver.

`scripts/regenerate_n4_audio_qa_flagged_tts.py` is the targeted replacement
harness for this manifest. It is dry-run by default; `--execute` is
required before any TTS provider call, storage write, or DB update.

## Manifest

| Target | Source text | STT transcript | Lesson target | Current audio | Action | Packet |
|---|---|---|---|---|---|---|
| HN4-020 script:0 | 約束は守るものです。 | 約束は守るもの。 | 8d0b1638-2521-4556-964f-29023d1dbcef script:0 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-0-regen-n4ch05-final-20260527.mp3) | direct-listen waiver or regenerate audio before broad rollout | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-020 script:2 | 挨拶は普通、先にするものです。 | 挨拶は普通1000にするものです。 | 8d0b1638-2521-4556-964f-29023d1dbcef script:2 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-2-regen-n4ch05-final-20260527.mp3) | direct-listen waiver or regenerate audio before broad rollout | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-021 script:0 | 予約したので、席はあるはずです。 | 予約したので昔はあるはずです。 | 92a62f1e-1a2f-4b54-897f-50ce13c2696a script:0 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-0-regen-n4ch05-final-20260527.mp3) | direct-listen waiver or regenerate audio before broad rollout | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-021 script:3 | 準備はできそうですね。 | 準備はできそうね | 92a62f1e-1a2f-4b54-897f-50ce13c2696a script:3 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-3-regen-n4ch05-final-20260527.mp3) | direct-listen waiver or regenerate audio before broad rollout | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |

## CSV Review Columns

The companion CSV leaves `regeneration_status`, `new_audio_url`,
`post_regen_verdict`, and `post_regen_notes` blank. Fill these only
after actual regeneration or an approved waiver step.

## Decision

Broad/full N4 rollout remains on hold while any `FLAG`, `PENDING`,
`FAIL`, or invalid verdict remains. This handoff reduces ambiguity for
the next execution slice but does not clear the gate by itself.
