# N4 Audio QA Verdict Regeneration Plan

> Status: REGENERATION HANDOFF - no audio generated
> Boundary: planning artifact only; no TTS provider call, storage write,
> packet verdict update, or native-speaker review is performed here

ASSUMPTION: Existing blocker verdict rows should stay blocking until
they are regenerated and re-reviewed, or explicitly waived after direct
listening. This plan only extracts the exact targets that need that next
step.

## Sources

- Packet: `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md`
- Quality signal report: `docs/operations/plans/n4-wave2-draft-tts-machine-report-2026-05-20.md`
- Quality signal report: `docs/operations/plans/n4-wave2-draft-tts-stt-assist-run-2026-05-20.md`

## Summary

| Metric | Count |
|---|---:|
| Total review targets | 45 |
| Current PASS verdicts | 42 |
| Current PENDING verdicts | 0 |
| Current FLAG verdicts | 3 |
| Current FAIL verdicts | 0 |
| Source verdict filter | FLAG |
| Regeneration manifest rows | 3 |
| Script-line rows | 3 |
| Question-prompt rows | 0 |

## Packet Distribution

| Packet | Selected targets |
|---|---:|
| `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` | 3 |

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
| HN4-013 script:1 | 分からなければ、受付で聞いてみましょう。 | わからなければ、ふふで聞いてみましょう。 | 254bf018-bbdc-41f7-9458-67cedba4a4c7 script:1 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-1.mp3) | direct-listen waiver or regenerate audio before broad rollout | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-013 script:2 | 案内の紙も読んでみます。 | 案内のおせも読んでみます。 | 254bf018-bbdc-41f7-9458-67cedba4a4c7 script:2 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-2.mp3) | direct-listen waiver or regenerate audio before broad rollout | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |
| HN4-015 script:1 | それは心配ですね。 | それは新米です。 | e812f2e7-4e5e-4e02-b566-47893239c20c script:1 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/script-line-1.mp3) | direct-listen waiver or regenerate audio before broad rollout | `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md` |

## CSV Review Columns

The companion CSV leaves `regeneration_status`, `new_audio_url`,
`post_regen_verdict`, and `post_regen_notes` blank. Fill these only
after actual regeneration or an approved waiver step.

## Decision

Broad/full N4 rollout remains on hold while any `FLAG`, `PENDING`,
`FAIL`, or invalid verdict remains. This handoff reduces ambiguity for
the next execution slice but does not clear the gate by itself.
