# N4 Audio QA Delegated Pending Clearance

> Status: MIXED-PROMPT PASS CSV GENERATED
> Boundary: delegated AI-assisted verdicts only; not native-speaker approval

ASSUMPTION: A `MIXED_PROMPT_STT_UNRELIABLE` row has Japanese/Korean,
cloze blanks, or Korean arrangement instructions that make single-language
STT mismatch weak evidence. Rows with `HIGH_SILENCE_RATIO` machine warnings
or script-line near matches are intentionally held.

## Sources

- Packet: `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-tts-machine-report-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-tts-stt-assist-run-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-tts-stt-timeout-retry-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-lexical-risk-stt-retry-2026-05-27.md`

## Summary

| Metric | Count |
|---|---:|
| Total review items | 45 |
| Pending review-signal items evaluated | 35 |
| Delegated PASS rows in CSV | 24 |
| Held rows left pending | 11 |

## Held Bucket Counts

| Bucket | Count |
|---|---:|
| NEAR_JAPANESE_MATCH | 6 |
| NO_STT_TRANSCRIPT | 5 |

## CSV Apply Contract

The companion CSV is compatible with
`scripts/apply_n4_audio_qa_verdicts.py --csv-input`. Only rows that meet
the mixed-prompt criteria receive `new_verdict=PASS`; held rows keep blank
`new_verdict` and `new_notes` so the apply script ignores them.

## Delegated PASS Rows

| Target | Bucket | Source text | STT transcript | Similarity | Decision | Audio | Packet |
|---|---|---|---|---:|---|---|---|
| HN4-017 question:1 | MIXED_PROMPT_STT_UNRELIABLE | 掃除의 뜻은? | サウジ | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-1.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-017 question:2 | MIXED_PROMPT_STT_UNRELIABLE | 洗濯의 뜻은? | シータクエソン | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-2.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-017 question:3 | MIXED_PROMPT_STT_UNRELIABLE | 掃除をし___、洗濯をし___します。 | 掃除をし、なつじを、洗濯をし、にぞうをします。 | 0.733 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-3.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-017 question:4 | MIXED_PROMPT_STT_UNRELIABLE | 문맥상 '준비'에 해당하는 말은? 来週の___をしたりします。 | 文脈さん準備に該当するマルは来週のあやをしたりします。 | 0.417 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-4.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-017 question:5 | MIXED_PROMPT_STT_UNRELIABLE | '청소를 하거나 빨래를 하거나 합니다'를 배열하세요. | チョンソをハゴナ、パレロハゴナ、ハムニダを配列ハセヨ。 | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-5.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-018 question:1 | MIXED_PROMPT_STT_UNRELIABLE | 機械의 뜻은? | チゲを釣る | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-1.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-018 question:2 | MIXED_PROMPT_STT_UNRELIABLE | 無理의 뜻은? | ウリエトシン | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-2.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-018 question:3 | MIXED_PROMPT_STT_UNRELIABLE | この機械は壊れ___です。 | この機械は壊れいつかです | 0.857 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-3.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-018 question:4 | MIXED_PROMPT_STT_UNRELIABLE | 눈앞의 상태를 보고 추측할 때 알맞은 표현은? | 目の前の状態を見て推測するとき、알맞은 표현은 | 0.308 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-4.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-018 question:5 | MIXED_PROMPT_STT_UNRELIABLE | '이 기계는 고장 날 것 같습니다'를 배열하세요. | この機械は故障しそうですを配列してください | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-5.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-019 question:1 | MIXED_PROMPT_STT_UNRELIABLE | 予定의 뜻은? | ゆていえいえん | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-1.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-019 question:2 | MIXED_PROMPT_STT_UNRELIABLE | 受付의 뜻은? | ドプロエトン | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-2.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-019 question:3 | MIXED_PROMPT_STT_UNRELIABLE | 会議は三時から始まる___です。 | 会議は3時から始まるです。 | 0.923 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-3.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-019 question:5 | MIXED_PROMPT_STT_UNRELIABLE | '시험은 쉽다고 합니다'를 배열하세요. | 「しおむん しゅぷだご はみだ」をべよるはせよ | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-5.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-020 question:1 | MIXED_PROMPT_STT_UNRELIABLE | 約束의 뜻은? | 原則、 | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-1.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-020 question:2 | MIXED_PROMPT_STT_UNRELIABLE | 守る의 뜻은? | モロヘイヤ | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-2.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-020 question:3 | MIXED_PROMPT_STT_UNRELIABLE | 約束は守る___です。 | 約束は守るならです | 0.875 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-3.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-020 question:4 | MIXED_PROMPT_STT_UNRELIABLE | 規則はみんなで___ものですね。 | 規則はみんなで交わらぬものですな | 0.786 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-4.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-020 question:5 | MIXED_PROMPT_STT_UNRELIABLE | '약속은 지키는 법입니다'를 배열하세요. | 約束を守る法です。を配列하세요。 | 0.200 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-5.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-021 question:1 | MIXED_PROMPT_STT_UNRELIABLE | 予約의 뜻은? | 予約恵子 | 0.444 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-1.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-021 question:2 | MIXED_PROMPT_STT_UNRELIABLE | 届く의 뜻은? | とくえ とくえ | 0.182 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-2.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-021 question:3 | MIXED_PROMPT_STT_UNRELIABLE | 席はある___です。 | かしわるーさに | 0.154 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-3.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-021 question:4 | MIXED_PROMPT_STT_UNRELIABLE | 資料も今日___はずです。 | 資料も今日は初です。 | 0.889 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-4.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-021 question:5 | MIXED_PROMPT_STT_UNRELIABLE | '자료는 오늘 도착할 것입니다'를 배열하세요. | 資料は今日到着するでしょう。を配列してください。 | 0.000 | PASS | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-5.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |

## Held Rows

These rows remain pending because they require listening or regeneration
judgment beyond the mixed-prompt STT false-positive rule.

| Target | Bucket | Source text | STT transcript | Similarity | Decision | Audio | Packet |
|---|---|---|---|---:|---|---|---|
| HN4-018 script:2 | NEAR_JAPANESE_MATCH | 別の機械なら操作が簡単そうです。 | 別の機会なら操作が簡単そうです。 | 0.933 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-2.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-019 script:0 | NEAR_JAPANESE_MATCH | 明日の会議は三時から始まるそうです。 | 明日の会議は3時から始まるそうです。 | 0.944 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-0.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-020 script:0 | NEAR_JAPANESE_MATCH | 約束は守るものです。 | 約束は守るもの。 | 0.875 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-0.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-021 script:0 | NEAR_JAPANESE_MATCH | 予約したので、席はあるはずです。 | 予約したので昔はあるはずです。 | 0.929 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-0.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-021 script:2 | NEAR_JAPANESE_MATCH | 会議の予定は午後に決まるはずです。 | 会議の予定は午後二時に決まるはずです。 | 0.914 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-2.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-021 script:3 | NEAR_JAPANESE_MATCH | 準備はできそうですね。 | 準備はできそうね | 0.889 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-3.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-019 question:4 | NO_STT_TRANSCRIPT | 들은 정보를 전달할 때 알맞은 표현은? |  | 0.000 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-4.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-020 script:1 | NO_STT_TRANSCRIPT | はい。規則はみんなで守るものですね。 |  | 0.000 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-1.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-020 script:2 | NO_STT_TRANSCRIPT | 挨拶は普通、先にするものです。 |  | 0.000 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-2.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-020 script:3 | NO_STT_TRANSCRIPT | 社会で必要な考え方ですね。 |  | 0.000 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-3.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| HN4-021 script:1 | NO_STT_TRANSCRIPT | 資料も今日届くはずです。 |  | 0.000 | HOLD | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-1.mp3) | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |

## Decision

Apply the CSV to clear mixed-prompt STT false positives first.
Broad/full N4 rollout remains blocked until the held rows are reviewed or regenerated.
