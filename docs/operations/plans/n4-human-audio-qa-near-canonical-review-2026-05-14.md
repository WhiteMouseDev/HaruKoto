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
| Selected review items | 14 |
| Selected buckets | NEAR_JAPANESE_MATCH, CANONICAL_MATCH |

## Selected Bucket Counts

| Bucket | Count |
|---|---:|
| NEAR_JAPANESE_MATCH | 11 |
| CANONICAL_MATCH | 3 |

## CSV Apply Boundary

The companion CSV leaves `new_verdict` and `new_notes` blank. Fill those
columns only after direct listening or an explicitly delegated review step.
Blank rows are ignored by `scripts/apply_n4_audio_qa_verdicts.py`.

## Review Items

| Bucket | Target | Source text | STT transcript | Similarity | Recommended action | Audio | Packet |
|---|---|---|---|---:|---|---|---|
| NEAR_JAPANESE_MATCH | HN4-002 script:0 | 少し頭が痛いです。 | 少し頭が痛い | 0.857 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/script-line-0.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| NEAR_JAPANESE_MATCH | HN4-002 script:2 | 医者に相談したほうがいいですか。 | 医者に相談した方がいいです。 | 0.966 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/script-line-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| NEAR_JAPANESE_MATCH | HN4-004 script:0 | 時間が足りません。駅まで走るしかありません。 | 時間が足りません。江木まで走るしかありません。 | 0.930 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/script-line-0.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| NEAR_JAPANESE_MATCH | HN4-004 script:1 | 次の予定がありますからね。 | 次の予定がありますから | 0.957 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/script-line-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| NEAR_JAPANESE_MATCH | HN4-005 script:1 | 文も翻訳できますか。 | 文も翻訳できます。 | 0.941 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/script-line-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| NEAR_JAPANESE_MATCH | HN4-005 script:2 | はい。授業の予約にも申し込めます。 | はい、授業の予約にも申し込みます。 | 0.933 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/script-line-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| NEAR_JAPANESE_MATCH | HN4-006 script:1 | この川の浅さも分かりますか。 | この歯の舞さも分かりますか | 0.846 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| NEAR_JAPANESE_MATCH | HN4-008 script:2 | 会議が長かったのです。 | 会議が長かった | 0.824 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/script-line-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |
| NEAR_JAPANESE_MATCH | HN4-011 script:0 | ノートを選ぶ前に、紙の厚さを比べています。 | ノートを選ぶ前に コムの厚さを比べています | 0.923 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-0.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md` |
| NEAR_JAPANESE_MATCH | HN4-011 script:2 | はい。この紙の柔らかさも確認します。 | はい、このシビの柔らかさも確認します。 | 0.909 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md` |
| NEAR_JAPANESE_MATCH | HN4-011 script:3 | 厚さと柔らかさを比べて選びましょう。 | 硬さ、柔らかさを比べて選びましょう。 | 0.909 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/script-line-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md` |
| CANONICAL_MATCH | HN4-002 script:1 | 心配ですね。今日は早く寝たほうがいいです。 | 心配ですね。今日は早く寝た方がいいです。 | 1.000 | candidate for delegated PASS after optional spot listen; keep native-speaker boundary in notes | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/script-line-1.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| CANONICAL_MATCH | HN4-002 script:3 | 熱があれば、医者に相談したほうが安心です。 | 熱があれば医者に相談した方が安心です。 | 1.000 | candidate for delegated PASS after optional spot listen; keep native-speaker boundary in notes | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/script-line-3.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md` |
| CANONICAL_MATCH | HN4-010 script:2 | はい。自然な結果を言うときに使います。 | はい、自然な結果を言う時に使います。 | 1.000 | candidate for delegated PASS after optional spot listen; keep native-speaker boundary in notes | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/script-line-2.mp3) | `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md` |

## Decision

Use this focused batch before lower-risk STT lanes. Broad/full N4 rollout
remains blocked until packet verdicts contain no `PENDING`, `FLAG`, `FAIL`,
or invalid values.
