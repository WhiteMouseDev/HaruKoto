# N4 Audio QA STT Reconciliation

> Status: TRIAGE ONLY - no verdicts applied
> Boundary: STT mismatch reconciliation only; does not replace listening or native-speaker review

ASSUMPTION: This report helps reduce review ambiguity while preserving
the current verdict gate. It does not set `PASS`, `FLAG`, `FAIL`, or
`WAIVED` on any packet row.

## Sources

- Packet: `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-tts-machine-report-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-tts-stt-assist-run-2026-05-27.md`
- Quality signal report: `docs/operations/plans/n4-wave3-draft-tts-stt-timeout-retry-2026-05-27.md`

## Summary

| Metric | Count |
|---|---:|
| Total review items | 45 |
| Pending review-signal items | 38 |
| P0 machine-warning retained first | 0 |
| P1 STT-only items | 33 |
| Canonical text matches | 0 |
| Near Japanese matches | 6 |
| Mixed/Korean prompt STT-unreliable | 24 |
| Lexical-risk Japanese mismatches | 3 |
| Missing STT transcript | 5 |

## Review Order

1. Listen to `P0_MACHINE_WARNING` rows first because high silence ratio
   can hide pacing or truncation problems even when the audio file exists.
2. Review `LEXICAL_RISK` rows next because the transcript diverges from
   the source enough to suggest possible wrong-word audio.
3. Use `NEAR_JAPANESE_MATCH` and `CANONICAL_MATCH` rows as lower-risk
   candidates for delegated PASS after a spot listen.
4. Treat `MIXED_PROMPT_STT_UNRELIABLE` as a prompt-design/STT limitation;
   decide by direct playback rather than transcript mismatch alone.

## CSV Apply Boundary

The companion CSV leaves `new_verdict` and `new_notes` blank. Fill those
columns only after direct listening or an explicitly delegated review step.


## P0_MACHINE_WARNING

- None

## LEXICAL_RISK

| Bucket | Target | Source text | STT transcript | Similarity | Signals | Recommended action | Audio |
|---|---|---|---|---:|---|---|---|
| LEXICAL_RISK | HN4-017 script:1 | 忙しいですね。 | 忙しい | 0.667 | TRANSCRIPTION_TEXT_MISMATCH:忙しい | listen carefully before PASS; prefer FLAG when the source text is not clearly spoken | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/script-line-1.mp3) |
| LEXICAL_RISK | HN4-018 script:0 | この機械は壊れそうです。 | この議会は壊れそう。 | 0.700 | TRANSCRIPTION_TEXT_MISMATCH:この議会は壊れそう。 | listen carefully before PASS; prefer FLAG when the source text is not clearly spoken | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-0.mp3) |
| LEXICAL_RISK | HN4-019 script:3 | 受付は混むそうですから、早く行きましょう。 | てくてはさおむそうですから早く行きましょう。 | 0.800 | TRANSCRIPTION_TEXT_MISMATCH:てくてはさおむそうですから早く行きましょう。 | listen carefully before PASS; prefer FLAG when the source text is not clearly spoken | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-3.mp3) |

## NEAR_JAPANESE_MATCH

| Bucket | Target | Source text | STT transcript | Similarity | Signals | Recommended action | Audio |
|---|---|---|---|---:|---|---|---|
| NEAR_JAPANESE_MATCH | HN4-018 script:2 | 別の機械なら操作が簡単そうです。 | 別の機会なら操作が簡単そうです。 | 0.933 | TRANSCRIPTION_TEXT_MISMATCH:別の機会なら操作が簡単そうです。 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-2.mp3) |
| NEAR_JAPANESE_MATCH | HN4-019 script:0 | 明日の会議は三時から始まるそうです。 | 明日の会議は3時から始まるそうです。 | 0.944 | TRANSCRIPTION_TEXT_MISMATCH:明日の会議は3時から始まるそうです。 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-0.mp3) |
| NEAR_JAPANESE_MATCH | HN4-020 script:0 | 約束は守るものです。 | 約束は守るもの。 | 0.875 | TRANSCRIPTION_TEXT_MISMATCH:約束は守るもの。 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-0.mp3) |
| NEAR_JAPANESE_MATCH | HN4-021 script:0 | 予約したので、席はあるはずです。 | 予約したので昔はあるはずです。 | 0.929 | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:予約したので昔はあるはずです。 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-0.mp3) |
| NEAR_JAPANESE_MATCH | HN4-021 script:2 | 会議の予定は午後に決まるはずです。 | 会議の予定は午後二時に決まるはずです。 | 0.914 | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:会議の予定は午後二時に決まるはずです。 | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-2.mp3) |
| NEAR_JAPANESE_MATCH | HN4-021 script:3 | 準備はできそうですね。 | 準備はできそうね | 0.889 | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:準備はできそうね | listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-3.mp3) |

## CANONICAL_MATCH

- None

## MIXED_PROMPT_STT_UNRELIABLE

| Bucket | Target | Source text | STT transcript | Similarity | Signals | Recommended action | Audio |
|---|---|---|---|---:|---|---|---|
| MIXED_PROMPT_STT_UNRELIABLE | HN4-017 question:1 | 掃除의 뜻은? | サウジ | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:サウジ | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-1.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-017 question:2 | 洗濯의 뜻은? | シータクエソン | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:シータクエソン | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-2.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-017 question:3 | 掃除をし___、洗濯をし___します。 | 掃除をし、なつじを、洗濯をし、にぞうをします。 | 0.733 | TRANSCRIPTION_TEXT_MISMATCH:掃除をし、なつじを、洗濯をし、にぞうをします。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-3.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-017 question:4 | 문맥상 '준비'에 해당하는 말은? 来週の___をしたりします。 | 文脈さん準備に該当するマルは来週のあやをしたりします。 | 0.417 | TRANSCRIPTION_TEXT_MISMATCH:文脈さん準備に該当するマルは来週のあやをしたりします。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-4.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-017 question:5 | '청소를 하거나 빨래를 하거나 합니다'를 배열하세요. | チョンソをハゴナ、パレロハゴナ、ハムニダを配列ハセヨ。 | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:チョンソをハゴナ、パレロハゴナ、ハムニダを配列ハセヨ。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-5.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-018 question:1 | 機械의 뜻은? | チゲを釣る | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:チゲを釣る | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-1.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-018 question:2 | 無理의 뜻은? | ウリエトシン | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:ウリエトシン | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-2.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-018 question:3 | この機械は壊れ___です。 | この機械は壊れいつかです | 0.857 | TRANSCRIPTION_TEXT_MISMATCH:この機械は壊れいつかです | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-3.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-018 question:4 | 눈앞의 상태를 보고 추측할 때 알맞은 표현은? | 目の前の状態を見て推測するとき、알맞은 표현은 | 0.308 | TRANSCRIPTION_TEXT_MISMATCH:目の前の状態を見て推測するとき、알맞은 표현은 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-4.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-018 question:5 | '이 기계는 고장 날 것 같습니다'를 배열하세요. | この機械は故障しそうですを配列してください | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:この機械は故障しそうですを配列してください | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-5.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-019 question:1 | 予定의 뜻은? | ゆていえいえん | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:ゆていえいえん | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-1.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-019 question:2 | 受付의 뜻은? | ドプロエトン | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:ドプロエトン | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-2.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-019 question:3 | 会議は三時から始まる___です。 | 会議は3時から始まるです。 | 0.923 | TRANSCRIPTION_TEXT_MISMATCH:会議は3時から始まるです。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-3.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-019 question:5 | '시험은 쉽다고 합니다'를 배열하세요. | 「しおむん しゅぷだご はみだ」をべよるはせよ | 0.000 | TRANSCRIPTION_TEXT_MISMATCH:「しおむん しゅぷだご はみだ」をべよるはせよ | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-5.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-020 question:1 | 約束의 뜻은? | 原則、 | 0.000 | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:原則、 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-1.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-020 question:2 | 守る의 뜻은? | モロヘイヤ | 0.000 | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:モロヘイヤ | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-2.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-020 question:3 | 約束は守る___です。 | 約束は守るならです | 0.875 | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:約束は守るならです | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-3.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-020 question:4 | 規則はみんなで___ものですね。 | 規則はみんなで交わらぬものですな | 0.786 | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:規則はみんなで交わらぬものですな | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-4.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-020 question:5 | '약속은 지키는 법입니다'를 배열하세요. | 約束を守る法です。を配列하세요。 | 0.200 | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:約束を守る法です。を配列하세요。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-5.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-021 question:1 | 予約의 뜻은? | 予約恵子 | 0.444 | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:予約恵子 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-1.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-021 question:2 | 届く의 뜻은? | とくえ とくえ | 0.182 | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:とくえ とくえ | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-2.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-021 question:3 | 席はある___です。 | かしわるーさに | 0.154 | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:かしわるーさに | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-3.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-021 question:4 | 資料も今日___はずです。 | 資料も今日は初です。 | 0.889 | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:資料も今日は初です。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-4.mp3) |
| MIXED_PROMPT_STT_UNRELIABLE | HN4-021 question:5 | '자료는 오늘 도착할 것입니다'를 배열하세요. | 資料は今日到着するでしょう。を配列してください。 | 0.000 | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:資料は今日到着するでしょう。を配列してください。 | listen for learner-facing completeness; do not treat STT mismatch alone as a fail | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-5.mp3) |

## NO_STT_TRANSCRIPT

| Bucket | Target | Source text | STT transcript | Similarity | Signals | Recommended action | Audio |
|---|---|---|---|---:|---|---|---|
| NO_STT_TRANSCRIPT | HN4-019 question:4 | 들은 정보를 전달할 때 알맞은 표현은? |  | 0.000 | TRANSCRIPTION_FAILED:TimeoutError: | rerun STT assist or listen manually before setting a verdict | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-4.mp3) |
| NO_STT_TRANSCRIPT | HN4-020 script:1 | はい。規則はみんなで守るものですね。 |  | 0.000 | TRANSCRIPTION_FAILED:TimeoutError: | rerun STT assist or listen manually before setting a verdict | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-1.mp3) |
| NO_STT_TRANSCRIPT | HN4-020 script:2 | 挨拶は普通、先にするものです。 |  | 0.000 | TRANSCRIPTION_FAILED:TimeoutError: | rerun STT assist or listen manually before setting a verdict | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-2.mp3) |
| NO_STT_TRANSCRIPT | HN4-020 script:3 | 社会で必要な考え方ですね。 |  | 0.000 | TRANSCRIPTION_FAILED:TimeoutError: | rerun STT assist or listen manually before setting a verdict | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-3.mp3) |
| NO_STT_TRANSCRIPT | HN4-021 script:1 | 資料も今日届くはずです。 |  | 0.000 | TRANSCRIPTION_FAILED:TimeoutError: | rerun STT assist or listen manually before setting a verdict | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-1.mp3) |

## Decision

Broad/full N4 rollout remains blocked. This triage only narrows the
remaining 38 pending review-signal audio QA rows
into review lanes and does not lower the verdict gate by itself.
