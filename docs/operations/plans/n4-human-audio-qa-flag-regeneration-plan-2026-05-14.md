# N4 Audio QA FLAG Regeneration Plan

> Status: REGENERATION HANDOFF - no audio generated
> Boundary: planning artifact only; no TTS provider call, storage write,
> packet verdict update, or native-speaker review is performed here

ASSUMPTION: Existing `FLAG` rows should stay blocking until they are
regenerated and re-reviewed, or explicitly waived after direct listening.
This plan only extracts the exact targets that need that next step.

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
| Current PASS verdicts | 29 |
| Current PENDING verdicts | 62 |
| Current FLAG verdicts | 8 |
| Current FAIL verdicts | 0 |
| Regeneration manifest rows | 8 |
| Script-line rows | 8 |
| Question-prompt rows | 0 |

## Packet Distribution

| Packet | FLAG targets |
|---|---:|
| `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` | 3 |
| `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` | 4 |
| `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md` | 1 |

## Execution Boundary

`scripts/generate_n4_pilot_tts_batch.py` currently generates missing TTS
coverage only. Do not expect it to replace these `FLAG` rows because
their current audio records already exist. A targeted replacement path
must either create a new audio object and update the matching `tts_audio`
record, or record an explicit direct-listening waiver.

## Manifest

| Target | Source text | STT transcript | Lesson target | Current audio | Action | Packet |
|---|---|---|---|---|---|---|
| HN4-001 script:3 | 分かりました。丁寧に確認します。 | わかりました。定時に確認します。 | b544d1f5-8089-45f8-b3d9-6428b60a0ece script:3 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/script-line-3.mp3) | regenerate audio, then listen before clearing FLAG | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-003 script:1 | じゃあ、会議に間に合わないかもしれませんね。 | じゃあ、会計に値に合わないかもしれないですね。 | 82d7334e-c4c4-4102-86ea-7be9b3218bce script:1 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/script-line-1.mp3) | regenerate audio, then listen before clearing FLAG | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-004 script:3 | 諦めないで、急いで行きましょう。 | 始めないで競いに行きましょう | 8368ee77-eeb8-48b2-9c81-2cfd597e5f7a script:3 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/script-line-3.mp3) | regenerate audio, then listen before clearing FLAG | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| HN4-006 script:0 | 湖の深さを地図で確認しました。 | 骨の傘を実で確認しました。 | 94d8d321-17c6-4fa1-8c50-af29c08e9c22 script:0 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-0.mp3) | regenerate audio, then listen before clearing FLAG | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-006 script:2 | はい。線の太さや細さも見られます。 | はい。不当操作や操作もみられます。 | 94d8d321-17c6-4fa1-8c50-af29c08e9c22 script:2 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-2.mp3) | regenerate audio, then listen before clearing FLAG | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-008 script:0 | 返事が遅れてすみません。 | 半時が遅れてすみません。 | 78e8b581-c81d-4465-b49d-cf0e4b49db4a script:0 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/script-line-0.mp3) | regenerate audio, then listen before clearing FLAG | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-010 script:3 | 荷物が届くと、メールが来ます。 | 何か届くとメールが来ます。 | 1445c28c-bd0c-4c0a-b8f7-2708c51acca7 script:3 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/script-line-3.mp3) | regenerate audio, then listen before clearing FLAG | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| HN4-011 script:1 | 厚い紙と薄い紙がありますね。 | 石と薄い石があります。 | 03cfdb15-c916-450c-8168-9052f3e754aa script:1 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-1.mp3) | regenerate audio, then listen before clearing FLAG | `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md` |

## CSV Review Columns

The companion CSV leaves `regeneration_status`, `new_audio_url`,
`post_regen_verdict`, and `post_regen_notes` blank. Fill these only
after actual regeneration or an approved waiver step.

## Decision

Broad/full N4 rollout remains on hold while any `FLAG`, `PENDING`,
`FAIL`, or invalid verdict remains. This handoff reduces ambiguity for
the next execution slice but does not clear the gate by itself.
