# N4 Audio QA Review Queue

> Status: REVIEW QUEUE - no remaining verdict blockers
> Boundary: prioritization artifact only; does not approve rollout

ASSUMPTION: This queue orders review work but does not replace listening,
native-speaker review, or explicit `PASS` / `FLAG` / `FAIL` verdicts.

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
| Total review items | 45 |
| PENDING | 0 |
| PASS | 45 |
| FLAG | 0 |
| FAIL | 0 |
| WAIVED | 0 |
| Review-signal items | 39 |
| P0 machine-warning items | 0 |
| STT-mismatch signal items | 36 |

## P0 Review First

- None

## P1 STT Mismatch Review

- None

## P2 Remaining Pending

- None

## P3 Resolved Or Waived

| Priority | Target | Japanese text | Korean/context | Audio | Review signals | Verdict | Packet |
|---|---|---|---|---|---|---|---|
| P3 resolved | HN4-017 script:0 | 週末は掃除をしたり、洗濯をしたりします。 | 주말에는 청소를 하거나 빨래를 하거나 합니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/script-line-0.mp3) | - | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-017 script:1 | 忙しいですね。 | 바쁘네요. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/script-line-1-regen-n4ch05-lexical-20260527.mp3) | TRANSCRIPTION_TEXT_MISMATCH:忙しい | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-017 script:2 | はい。来週の準備をしたり、部屋を片付けたりします。 | 네. 다음 주 준비를 하거나 방을 정리하거나 합니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/script-line-2.mp3) | - | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-017 script:3 | 生活の習慣を話す時に便利ですね。 | 생활 습관을 말할 때 편리하네요. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/script-line-3.mp3) | - | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-017 question:1 | 掃除의 뜻은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-1.mp3) | TRANSCRIPTION_TEXT_MISMATCH:サウジ | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-017 question:2 | 洗濯의 뜻은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-2.mp3) | TRANSCRIPTION_TEXT_MISMATCH:シータクエソン | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-017 question:3 | 掃除をし___、洗濯をし___します。 |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-3.mp3) | TRANSCRIPTION_TEXT_MISMATCH:掃除をし、なつじを、洗濯をし、にぞうをします。 | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-017 question:4 | 문맥상 '준비'에 해당하는 말은? 来週の___をしたりします。 |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-4.mp3) | TRANSCRIPTION_TEXT_MISMATCH:文脈さん準備に該当するマルは来週のあやをしたりします。 | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-017 question:5 | '청소를 하거나 빨래를 하거나 합니다'를 배열하세요. |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-5.mp3) | TRANSCRIPTION_TEXT_MISMATCH:チョンソをハゴナ、パレロハゴナ、ハムニダを配列ハセヨ。 | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-018 script:0 | この古い機械は壊れそうですから、会議では使わないでください。 | 이 오래된 기계는 고장 날 것 같으니, 회의에서는 쓰지 말아 주세요. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-0-regen-n4ch05-rewrite2-20260527.mp3) | TRANSCRIPTION_TEXT_MISMATCH:この議会は壊れそう。, TRANSCRIPTION_TEXT_MISMATCH:この議会は壊れそう | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-018 script:1 | 会議で使うのは無理そうですね。 | 회의에서 쓰기는 무리일 것 같네요. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-1.mp3) | - | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-018 script:2 | 別の機械なら操作が簡単そうです。 | 다른 기계라면 조작이 간단해 보입니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-2.mp3) | TRANSCRIPTION_TEXT_MISMATCH:別の機会なら操作が簡単そうです。 | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-018 script:3 | この操作は大変そうです。早めに相談しましょう。 | 이 조작은 힘들어 보입니다. 일찍 상담합시다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-3-regen-n4ch05-cleanup-20260527.mp3) | TRANSCRIPTION_TEXT_MISMATCH:てんたかさんも大変そうですね。早めに相談しましょう。 | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-018 question:1 | 機械의 뜻은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-1.mp3) | TRANSCRIPTION_TEXT_MISMATCH:チゲを釣る | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-018 question:2 | 無理의 뜻은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-2.mp3) | TRANSCRIPTION_TEXT_MISMATCH:ウリエトシン | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-018 question:3 | この機械は壊れ___です。 |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-3.mp3) | TRANSCRIPTION_TEXT_MISMATCH:この機械は壊れいつかです | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-018 question:4 | 눈앞의 상태를 보고 추측할 때 알맞은 표현은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-4.mp3) | TRANSCRIPTION_TEXT_MISMATCH:目の前の状態を見て推測するとき、알맞은 표현은 | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-018 question:5 | '이 기계는 고장 날 것 같습니다'를 배열하세요. |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-5.mp3) | TRANSCRIPTION_TEXT_MISMATCH:この機械は故障しそうですを配列してください | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-019 script:0 | 明日の会議は三時から始まるそうです。 | 내일 회의는 세 시부터 시작한다고 합니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-0.mp3) | TRANSCRIPTION_TEXT_MISMATCH:明日の会議は3時から始まるそうです。 | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-019 script:1 | 予定が変わるそうですね。 | 예정이 바뀐다고 하네요. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-1.mp3) | - | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-019 script:2 | 試験は思ったより簡単だそうです。 | 시험은 생각보다 쉽다고 합니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-2.mp3) | - | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-019 script:3 | 受付は混むそうですから、早く行きましょう。 | 접수는 붐빈다고 하니, 일찍 갑시다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-3-regen-n4ch05-gemini-20260527.mp3) | TRANSCRIPTION_TEXT_MISMATCH:てくてはさおむそうですから早く行きましょう。, TRANSCRIPTION_TEXT_MISMATCH:てくてはさおむそうですから早く行きましょう | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-019 question:1 | 予定의 뜻은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-1.mp3) | TRANSCRIPTION_TEXT_MISMATCH:ゆていえいえん | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-019 question:2 | 受付의 뜻은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-2.mp3) | TRANSCRIPTION_TEXT_MISMATCH:ドプロエトン | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-019 question:3 | 会議は三時から始まる___です。 |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-3.mp3) | TRANSCRIPTION_TEXT_MISMATCH:会議は3時から始まるです。 | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-019 question:4 | 들은 정보를 전달할 때 알맞은 표현은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-4.mp3) | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:聞いた情報を伝えるとき、適切な表現は | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-019 question:5 | '시험은 쉽다고 합니다'를 배열하세요. |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-5.mp3) | TRANSCRIPTION_TEXT_MISMATCH:「しおむん しゅぷだご はみだ」をべよるはせよ | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-020 script:0 | 学校の約束は最後まで守るものです。 | 학교의 약속은 끝까지 지키는 법입니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-0-regen-n4ch05-final-rewrite2-20260527.mp3) | TRANSCRIPTION_TEXT_MISMATCH:約束は守るもの。 | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-020 script:1 | はい。規則はみんなで守るものですね。 | 네. 규칙은 모두 함께 지키는 법이네요. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-1.mp3) | TRANSCRIPTION_FAILED:TimeoutError: | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-020 script:2 | 挨拶は普通、先にするものです。 | 인사는 보통 먼저 하는 법입니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-2-regen-n4ch05-final-gemini-20260527.mp3) | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:挨拶は普通1000にするものです。 | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-020 script:3 | 社会で必要な考え方ですね。 | 사회에서 필요한 사고방식이네요. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-3.mp3) | TRANSCRIPTION_FAILED:TimeoutError: | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-020 question:1 | 約束의 뜻은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-1.mp3) | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:原則、 | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-020 question:2 | 守る의 뜻은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-2.mp3) | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:モロヘイヤ | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-020 question:3 | 学校の約束は最後まで守る___です。 |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-3.mp3) | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:約束は守るならです | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-020 question:4 | 規則はみんなで___ものですね。 |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-4.mp3) | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:規則はみんなで交わらぬものですな | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-020 question:5 | '학교의 약속은 끝까지 지키는 법입니다'를 배열하세요. |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/question-5.mp3) | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:約束を守る法です。を配列하세요。 | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-021 script:0 | 予約したので、席はまだあるはずです。 | 예약했으니 자리는 아직 있을 것입니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-0-regen-n4ch05-final-rewrite2-20260527.mp3) | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:予約したので昔はあるはずです。 | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-021 script:1 | 資料も今日届くはずです。 | 자료도 오늘 도착할 것입니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-1.mp3) | TRANSCRIPTION_FAILED:TimeoutError: | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-021 script:2 | 会議の予定は午後に決まるはずです。 | 회의 예정은 오후에 정해질 것입니다. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-2-regen-n4ch05-final-20260527.mp3) | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:会議の予定は午後二時に決まるはずです。 | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-021 script:3 | 準備はもうすぐできそうですね。 | 준비는 곧 될 것 같네요. | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/script-line-3-regen-n4ch05-final-rewrite-20260527.mp3) | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:準備はできそうね | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-021 question:1 | 予約의 뜻은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-1.mp3) | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:予約恵子 | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-021 question:2 | 届く의 뜻은? |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-2.mp3) | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:とくえ とくえ | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-021 question:3 | 席はまだある___です。 |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-3.mp3) | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:かしわるーさに | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-021 question:4 | 資料も今日___はずです。 |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-4.mp3) | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:資料も今日は初です。 | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |
| P3 resolved | HN4-021 question:5 | '자료는 오늘 도착할 것입니다'를 배열하세요. |  | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/92a62f1e-1a2f-4b54-897f-50ce13c2696a/question-5.mp3) | TRANSCRIPTION_FAILED:TimeoutError:, TRANSCRIPTION_TEXT_MISMATCH:資料は今日到着するでしょう。を配列してください。 | PASS | `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md` |

## Decision

Use this queue to review P0 machine/verdict blocker rows first, then P1
STT mismatch rows, then remaining pending packet rows. STT mismatches are
review-priority signals, not automatic audio-fail verdicts. Broad/full N4
rollout remains blocked until the packet verdict tracker has no `PENDING`,
`FLAG`, `FAIL`, or invalid verdict values.
