# N4 Audio QA Bucket Review Batch

> Status: FOCUSED REVIEW BATCH - no verdicts applied
> Boundary: listening/inspection aid only; does not replace native-speaker review

ASSUMPTION: This batch narrows the next review pass to the selected STT
reconciliation bucket(s). It does not set `PASS`, `FLAG`, `FAIL`, or
`WAIVED` on any packet row.

## Sources

- Packet: `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md`
- Packet: `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md`
- Packet: `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md`
- Quality signal report: `docs/operations/plans/n4-pilot-tts-machine-report-2026-05-14.md`
- Quality signal report: `docs/operations/plans/n4-pilot-tts-stt-assist-run-2026-05-14.md`

## Summary

| Metric | Count |
|---|---:|
| Total review items | 99 |
| Pending review-signal items | 73 |
| Selected review items | 8 |
| Selected buckets | LEXICAL_RISK |

## Selected Bucket Counts

| Bucket | Count |
|---|---:|
| LEXICAL_RISK | 8 |

## CSV Apply Boundary

The companion CSV leaves `new_verdict` and `new_notes` blank. Fill those
columns only after direct listening or an explicitly delegated review step.
Blank rows are ignored by `scripts/apply_n4_audio_qa_verdicts.py`.

## Review Items

| Bucket | Target | Source text | STT transcript | Similarity | Recommended action | Audio | Packet |
|---|---|---|---|---:|---|---|---|
| LEXICAL_RISK | HN4-001 script:3 | 分かりました。丁寧に確認します。 | わかりました。定時に確認します。 | 0.759 | listen carefully before PASS; prefer FLAG when the source text is not clearly spoken | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/script-line-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| LEXICAL_RISK | HN4-003 script:1 | じゃあ、会議に間に合わないかもしれませんね。 | じゃあ、会計に値に合わないかもしれないですね。 | 0.732 | listen carefully before PASS; prefer FLAG when the source text is not clearly spoken | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/script-line-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| LEXICAL_RISK | HN4-004 script:3 | 諦めないで、急いで行きましょう。 | 始めないで競いに行きましょう | 0.786 | listen carefully before PASS; prefer FLAG when the source text is not clearly spoken | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/script-line-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| LEXICAL_RISK | HN4-006 script:0 | 湖の深さを地図で確認しました。 | 骨の傘を実で確認しました。 | 0.692 | listen carefully before PASS; prefer FLAG when the source text is not clearly spoken | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-0.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| LEXICAL_RISK | HN4-006 script:2 | はい。線の太さや細さも見られます。 | はい。不当操作や操作もみられます。 | 0.533 | listen carefully before PASS; prefer FLAG when the source text is not clearly spoken | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| LEXICAL_RISK | HN4-008 script:0 | 返事が遅れてすみません。 | 半時が遅れてすみません。 | 0.783 | listen carefully before PASS; prefer FLAG when the source text is not clearly spoken | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/script-line-0.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| LEXICAL_RISK | HN4-010 script:3 | 荷物が届くと、メールが来ます。 | 何か届くとメールが来ます。 | 0.800 | listen carefully before PASS; prefer FLAG when the source text is not clearly spoken | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/script-line-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| LEXICAL_RISK | HN4-011 script:1 | 厚い紙と薄い紙がありますね。 | 石と薄い石があります。 | 0.696 | listen carefully before PASS; prefer FLAG when the source text is not clearly spoken | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md` |

## Decision

Use this focused batch before lower-risk STT lanes. Broad/full N4 rollout
remains blocked until packet verdicts contain no `PENDING`, `FLAG`, `FAIL`,
or invalid values.
