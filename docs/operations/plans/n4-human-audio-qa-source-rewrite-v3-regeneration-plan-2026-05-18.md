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
| Current PASS verdicts | 97 |
| Current PENDING verdicts | 0 |
| Current FLAG verdicts | 2 |
| Current FAIL verdicts | 0 |
| Source verdict filter | FLAG |
| Regeneration manifest rows | 2 |
| Script-line rows | 2 |
| Question-prompt rows | 0 |

## Packet Distribution

| Packet | Selected targets |
|---|---:|
| `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` | 1 |
| `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md` | 1 |

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
| HN4-006 script:1 | この川の浅さもわかります。 | この歯の舞さも分かりますか | 94d8d321-17c6-4fa1-8c50-af29c08e9c22 script:1 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-1-regen-20260518T075845Z.mp3) | direct-listen waiver or regenerate audio before broad rollout | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-011 script:3 | ノートの厚さと柔らかさを比べます。 | 硬さ、柔らかさを比べて選びましょう。 | 03cfdb15-c916-450c-8168-9052f3e754aa script:3 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-3-regen-20260518T075845Z.mp3) | direct-listen waiver or regenerate audio before broad rollout | `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md` |

## CSV Review Columns

The companion CSV leaves `regeneration_status`, `new_audio_url`,
`post_regen_verdict`, and `post_regen_notes` blank. Fill these only
after actual regeneration or an approved waiver step.

## Decision

Broad/full N4 rollout remains on hold while any `FLAG`, `PENDING`,
`FAIL`, or invalid verdict remains. This handoff reduces ambiguity for
the next execution slice but does not clear the gate by itself.
