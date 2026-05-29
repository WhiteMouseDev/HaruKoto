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

## Summary

| Metric | Count |
|---|---:|
| Total review targets | 45 |
| Current PASS verdicts | 2 |
| Current PENDING verdicts | 41 |
| Current FLAG verdicts | 2 |
| Current FAIL verdicts | 0 |
| Source verdict filter | FLAG |
| Regeneration manifest rows | 2 |
| Script-line rows | 2 |
| Question-prompt rows | 0 |

## Packet Distribution

| Packet | Selected targets |
|---|---:|
| `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` | 2 |

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
| HN4-018 script:0 | この機械は壊れそうです。 | この議会は壊れそう。 | b68d0a77-31f9-4061-8e22-baedb02367f7 script:0 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-0-regen-n4ch05-lexical-20260527.mp3) | direct-listen waiver or regenerate audio before broad rollout | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-019 script:3 | 受付は混むそうですから、早く行きましょう。 | てくてはさおむそうですから早く行きましょう。 | 50d21797-c2c3-40ed-8641-db05efa0578d script:3 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-3-regen-n4ch05-lexical-20260527.mp3) | direct-listen waiver or regenerate audio before broad rollout | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |

## CSV Review Columns

The companion CSV leaves `regeneration_status`, `new_audio_url`,
`post_regen_verdict`, and `post_regen_notes` blank. Fill these only
after actual regeneration or an approved waiver step.

## Decision

Broad/full N4 rollout remains on hold while any `FLAG`, `PENDING`,
`FAIL`, or invalid verdict remains. This handoff reduces ambiguity for
the next execution slice but does not clear the gate by itself.
