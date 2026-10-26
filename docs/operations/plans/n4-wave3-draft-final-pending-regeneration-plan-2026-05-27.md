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
| Current PASS verdicts | 37 |
| Current PENDING verdicts | 8 |
| Current FLAG verdicts | 0 |
| Current FAIL verdicts | 0 |
| Source verdict filter | PENDING |
| Regeneration manifest rows | 8 |
| Script-line rows | 7 |
| Question-prompt rows | 1 |

## Packet Distribution

| Packet | Selected targets |
|---|---:|
| `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` | 8 |

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
| HN4-018 script:2 | 別の機械なら操作が簡単そうです。 | 別の機会なら操作が簡単そうです。 | b68d0a77-31f9-4061-8e22-baedb02367f7 script:2 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-2.mp3) | regenerate audio, then STT audit before setting PASS or FLAG | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-019 script:0 | 明日の会議は三時から始まるそうです。 | 明日の会議は3時から始まるそうです。 | 50d21797-c2c3-40ed-8641-db05efa0578d script:0 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-0.mp3) | regenerate audio, then STT audit before setting PASS or FLAG | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-019 question:4 | 들은 정보를 전달할 때 알맞은 표현은? | 聞いた情報を伝えるとき、適切な表現は | 50d21797-c2c3-40ed-8641-db05efa0578d question:4 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-4.mp3) | regenerate audio, then STT audit before setting PASS or FLAG | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-020 script:0 | 約束は守るものです。 | 約束は守るもの。 | 8d0b1638-2521-4556-964f-29023d1dbcef script:0 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-0.mp3) | regenerate audio, then STT audit before setting PASS or FLAG | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-020 script:2 | 挨拶は普通、先にするものです。 | 挨拶は普通1000にするものです。 | 8d0b1638-2521-4556-964f-29023d1dbcef script:2 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-2.mp3) | regenerate audio, then STT audit before setting PASS or FLAG | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-021 script:0 | 予約したので、席はあるはずです。 | 予約したので昔はあるはずです。 | 92a62f1e-1a2f-4b54-897f-50ce13c2696a script:0 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-0.mp3) | regenerate audio, then STT audit before setting PASS or FLAG | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-021 script:2 | 会議の予定は午後に決まるはずです。 | 会議の予定は午後二時に決まるはずです。 | 92a62f1e-1a2f-4b54-897f-50ce13c2696a script:2 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-2.mp3) | regenerate audio, then STT audit before setting PASS or FLAG | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-021 script:3 | 準備はできそうですね。 | 準備はできそうね | 92a62f1e-1a2f-4b54-897f-50ce13c2696a script:3 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-3.mp3) | regenerate audio, then STT audit before setting PASS or FLAG | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |

## CSV Review Columns

The companion CSV leaves `regeneration_status`, `new_audio_url`,
`post_regen_verdict`, and `post_regen_notes` blank. Fill these only
after actual regeneration or an approved waiver step.

## Decision

Broad/full N4 rollout remains on hold while any `FLAG`, `PENDING`,
`FAIL`, or invalid verdict remains. This handoff reduces ambiguity for
the next execution slice but does not clear the gate by itself.
