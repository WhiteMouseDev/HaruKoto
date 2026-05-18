# N4 Audio QA Verdict Regeneration Plan

> Status: REGENERATION HANDOFF - no audio generated
> Boundary: planning artifact only; no TTS provider call, storage write,
> packet verdict update, or native-speaker review is performed here

ASSUMPTION: Existing blocker verdict rows should stay blocking until
they are regenerated and re-reviewed, or explicitly waived after direct
listening. This plan only extracts the exact targets that need that next
step.

## Sources

- Packet: `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md`
- Packet: `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md`
- Packet: `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md`
- Quality signal report: `docs/operations/plans/n4-pilot-tts-machine-report-2026-05-14.md`
- Quality signal report: `docs/operations/plans/n4-pilot-tts-stt-assist-run-2026-05-14.md`

## Summary

| Metric | Count |
|---|---:|
| Total review targets | 99 |
| Current PASS verdicts | 93 |
| Current PENDING verdicts | 1 |
| Current FLAG verdicts | 5 |
| Current FAIL verdicts | 0 |
| Source verdict filter | PENDING |
| Regeneration manifest rows | 1 |
| Script-line rows | 0 |
| Question-prompt rows | 1 |

## Packet Distribution

| Packet | Selected targets |
|---|---:|
| `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` | 1 |

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
| HN4-003 question:4 | 間に合わない___。 (시간에 맞지 못할지도 모릅니다.) | 間に合わない。 時間に間に合わないかもしれません。 | 82d7334e-c4c4-4102-86ea-7be9b3218bce question:4 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-4-regen-20260518T041500Z.mp3) | regenerate audio, then STT audit before setting PASS or FLAG | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |

## CSV Review Columns

The companion CSV leaves `regeneration_status`, `new_audio_url`,
`post_regen_verdict`, and `post_regen_notes` blank. Fill these only
after actual regeneration or an approved waiver step.

## Decision

Broad/full N4 rollout remains on hold while any `FLAG`, `PENDING`,
`FAIL`, or invalid verdict remains. This handoff reduces ambiguity for
the next execution slice but does not clear the gate by itself.
