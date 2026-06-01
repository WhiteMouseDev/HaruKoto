# N4 Audio QA Verdict Regeneration Plan

> Status: REGENERATION HANDOFF - no audio generated
> Boundary: planning artifact only; no TTS provider call, storage write,
> packet verdict update, or native-speaker review is performed here

ASSUMPTION: Existing blocker verdict rows should stay blocking until
they are regenerated and re-reviewed, or explicitly waived after direct
listening. This plan only extracts the exact targets that need that next
step.

## Sources

- Packet: `docs/operations/plans/n4-ch06-pilot-human-audio-qa-ch06-2026-06-01.md`
- Quality signal report: `docs/operations/plans/n4-ch06-script-stt-retry-2026-06-01.md`

## Summary

| Metric | Count |
|---|---:|
| Total review targets | 45 |
| Current PASS verdicts | 0 |
| Current PENDING verdicts | 45 |
| Current FLAG verdicts | 0 |
| Current FAIL verdicts | 0 |
| Source verdict filter | PENDING |
| Regeneration manifest rows | 10 |
| Script-line rows | 10 |
| Question-prompt rows | 0 |

## Packet Distribution

| Packet | Selected targets |
|---|---:|
| `docs/operations/plans/n4-ch06-pilot-human-audio-qa-ch06-2026-06-01.md` | 10 |

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
| HN4-022 script:0 | 後輩に地図を描いてあげました。 | 後輩に地図を絵描いてあげました。 | b9250446-d707-46d4-a461-66e273b8534e script:0 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/script-line-0.mp3) | regenerate audio, then STT audit before setting PASS or FLAG | `docs/operations/plans/n4-ch06-pilot-human-audio-qa-ch06-2026-06-01.md` |
| HN4-022 script:1 | 親切ですね。受付の場所も教えてあげましたか。 | 親切ですね。特定の場所も教えてあげましたか？ | b9250446-d707-46d4-a461-66e273b8534e script:1 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/script-line-1.mp3) | regenerate audio, then STT audit before setting PASS or FLAG | `docs/operations/plans/n4-ch06-pilot-human-audio-qa-ch06-2026-06-01.md` |
| HN4-022 script:3 | 手伝ってあげる時は、相手の気持ちも大事ですね。 | 手伝って開ける時は相手の気持ちも大事ですね。 | b9250446-d707-46d4-a461-66e273b8534e script:3 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b9250446-d707-46d4-a461-66e273b8534e/script-line-3.mp3) | regenerate audio, then STT audit before setting PASS or FLAG | `docs/operations/plans/n4-ch06-pilot-human-audio-qa-ch06-2026-06-01.md` |
| HN4-023 script:1 | 受付の場所も説明してくれましたか。 | 特ねの場所も説明してくれましたか？ | 45466832-238e-429a-af10-e9811dc360d3 script:1 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/45466832-238e-429a-af10-e9811dc360d3/script-line-1.mp3) | regenerate audio, then STT audit before setting PASS or FLAG | `docs/operations/plans/n4-ch06-pilot-human-audio-qa-ch06-2026-06-01.md` |
| HN4-024 script:0 | 受付の人に住所を確認してもらいました。 | とくねの人に住所を確認してもらいました。 | 35093fd4-0511-4bdc-bfe4-e4c25c269654 script:0 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/35093fd4-0511-4bdc-bfe4-e4c25c269654/script-line-0.mp3) | regenerate audio, then STT audit before setting PASS or FLAG | `docs/operations/plans/n4-ch06-pilot-human-audio-qa-ch06-2026-06-01.md` |
| HN4-024 script:3 | 必要なことは受付の人にもう一度確認してもらいましょう。 | 必要なことは、テフの人にもう一度確認してもらいましょう。 | 35093fd4-0511-4bdc-bfe4-e4c25c269654 script:3 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/35093fd4-0511-4bdc-bfe4-e4c25c269654/script-line-3.mp3) | regenerate audio, then STT audit before setting PASS or FLAG | `docs/operations/plans/n4-ch06-pilot-human-audio-qa-ch06-2026-06-01.md` |
| HN4-025 script:1 | それは残念ですね。受付に連絡しましたか。 | それは残念ですね。手札に連絡しましたか？ | b8b159a7-b8d4-45b3-a8d7-a9d07837b991 script:1 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b8b159a7-b8d4-45b3-a8d7-a9d07837b991/script-line-1.mp3) | regenerate audio, then STT audit before setting PASS or FLAG | `docs/operations/plans/n4-ch06-pilot-human-audio-qa-ch06-2026-06-01.md` |
| HN4-026 script:0 | 駅の前で自転車を盗まれました。 | いいの前で自転車を盗まれました。 | ef3004f3-bca8-4621-b7aa-520cdde4e823 script:0 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/script-line-0.mp3) | regenerate audio, then STT audit before setting PASS or FLAG | `docs/operations/plans/n4-ch06-pilot-human-audio-qa-ch06-2026-06-01.md` |
| HN4-026 script:1 | 落とし物ではなく、盗まれたんですね。 | 落とし物ではなく盗まれてたんですか | ef3004f3-bca8-4621-b7aa-520cdde4e823 script:1 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/script-line-1.mp3) | regenerate audio, then STT audit before setting PASS or FLAG | `docs/operations/plans/n4-ch06-pilot-human-audio-qa-ch06-2026-06-01.md` |
| HN4-026 script:3 | 近くのカメラの映像がこれから確認されます。 | 近くのカメラの影響がこれから確認されます。 | ef3004f3-bca8-4621-b7aa-520cdde4e823 script:3 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/ef3004f3-bca8-4621-b7aa-520cdde4e823/script-line-3.mp3) | regenerate audio, then STT audit before setting PASS or FLAG | `docs/operations/plans/n4-ch06-pilot-human-audio-qa-ch06-2026-06-01.md` |

## CSV Review Columns

The companion CSV leaves `regeneration_status`, `new_audio_url`,
`post_regen_verdict`, and `post_regen_notes` blank. Fill these only
after actual regeneration or an approved waiver step.

## Decision

Broad/full N4 rollout remains on hold while any `FLAG`, `PENDING`,
`FAIL`, or invalid verdict remains. This handoff reduces ambiguity for
the next execution slice but does not clear the gate by itself.
