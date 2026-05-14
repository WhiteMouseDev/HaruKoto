# N4 Audio QA Delegated AI PASS Application

> Status: 26 AI-assisted PASS verdicts applied
> Boundary: delegated AI audio QA only; not native-speaker review

ASSUMPTION: The project owner delegated this PASS application because no
human/native-speaker reviewer is currently available. Each applied row had
`machine pass + no parsed machine/STT review signal` evidence and was kept
separate from P0/P1 rows with review signals.

## Inputs

- Candidate template: `docs/operations/plans/n4-human-audio-qa-pass-candidates-2026-05-14.csv`
- Candidate HTML: `docs/operations/plans/n4-human-audio-qa-pass-candidates-2026-05-14.html`
- Reviewed apply CSV: `docs/operations/plans/n4-human-audio-qa-pass-candidates-reviewed-2026-05-14.csv`
- Apply command: `cd apps/api && uv run python scripts/apply_n4_audio_qa_verdicts.py --csv-input ../../docs/operations/plans/n4-human-audio-qa-pass-candidates-reviewed-2026-05-14.csv --write`

## Summary

| Metric | Count |
|---|---:|
| Applied PASS verdicts | 26 |
| Remaining PENDING verdicts | 73 |
| FLAG verdicts | 0 |
| FAIL verdicts | 0 |
| P0 machine-warning rows still pending | 11 |
| P1 STT-mismatch rows still pending | 62 |

## Applied Verdict Note

Every applied row uses this note:

> Delegated AI-assisted PASS: machine pass + no parsed machine/STT review signal; not native-speaker review.

## Applied Targets

### `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md`

| Target | Japanese text | Audio |
|---|---|---|
| HN4-001 script:0 | 宿題を出す前に、名前を書きなさい。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/script-line-0.mp3) |
| HN4-001 script:1 | はい、ここに書けばいいですか。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/script-line-1.mp3) |
| HN4-001 script:2 | はい。それから、規則をもう一度確認しなさい。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/script-line-2.mp3) |
| HN4-002 question:5 | '오늘은 일찍 자는 편이 좋습니다'를 배열하세요. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-5.mp3) |
| HN4-003 script:0 | 台風で電車が遅れるかもしれません。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/script-line-0.mp3) |
| HN4-003 script:2 | 最近、天気がよく変わります。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/script-line-2.mp3) |
| HN4-003 script:3 | 少し心配ですが、早めに出発します。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/script-line-3.mp3) |
| HN4-003 question:5 | '전철이 늦을지도 모릅니다'를 배열하세요. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-5.mp3) |
| HN4-004 script:2 | タクシーは高いので、電車に乗るしかありません。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/script-line-2.mp3) |
| HN4-005 script:0 | このアプリで漢字を調べられます。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/script-line-0.mp3) |
| HN4-005 script:3 | それなら自信を持って勉強できます。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/script-line-3.mp3) |
| HN4-005 question:5 | '이 앱으로 한자를 찾아볼 수 있습니다'를 배열하세요. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-5.mp3) |

### `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md`

| Target | Japanese text | Audio |
|---|---|---|
| HN4-006 script:3 | 情報の正しさも大切ですね。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-3.mp3) |
| HN4-007 script:0 | 週末のイベントに参加しようと思っています。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/script-line-0.mp3) |
| HN4-007 script:1 | 私は友達に案内を送ろうと思っています。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/script-line-1.mp3) |
| HN4-007 script:2 | 資料も集めようと思います。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/script-line-2.mp3) |
| HN4-007 script:3 | 新しい先生を紹介しようと思います。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/faeff614-2038-49b4-8c6c-4915d50cecf8/script-line-3.mp3) |
| HN4-008 script:1 | 何か理由があったんですか。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/script-line-1.mp3) |
| HN4-008 script:3 | そうだったんですね。連絡ありがとうございます。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/script-line-3.mp3) |
| HN4-009 script:0 | 面接のために、自己紹介を練習しています。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/script-line-0.mp3) |
| HN4-009 script:1 | 就職するために、準備しているんですね。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/script-line-1.mp3) |
| HN4-009 script:2 | はい。新しい技術も勉強しています。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/script-line-2.mp3) |
| HN4-009 script:3 | 教育のためにも役に立ちそうです。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/script-line-3.mp3) |
| HN4-010 script:0 | このボタンを押すと、画面が変わります。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/script-line-0.mp3) |
| HN4-010 script:1 | 信号が青になると、車が進みますね。 | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/script-line-1.mp3) |

### `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md`

| Target | Japanese text | Audio |
|---|---|---|
| HN4-011 question:5 | '종이의 두께를 비교합니다'를 배열하세요. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-5.mp3) |

## Post-Apply Verdict Report

After applying these rows, `report_n4_audio_qa_verdicts.py` reports:

- `targets 99`
- `pass 26`
- `pending 73`
- `flag 0`
- `fail 0`
- blocker: `PENDING_VERDICTS: 73 target(s) still need human verdicts`

## Decision

The 26 no-signal candidate rows are no longer broad-rollout blockers by
verdict state. Broad/full N4 rollout remains blocked by the 73 pending P0/P1
rows and by native-speaker review when available.
