# N4 TTS Audio QA Machine Report

> Status: BLOCK
> Scope: generated lesson script-line and question-prompt TTS targets
> Boundary: machine/STT evidence only; human audio verdicts remain required

## Command

```bash
uv run python scripts/audit_n4_pilot_tts_audio_quality.py --level N4 --include-unpublished --lesson-no 17 --lesson-no 18 --lesson-no 19 --lesson-no 20 --lesson-no 21 --transcribe --transcription-timeout-seconds 20.0 --markdown-output ../../docs/operations/plans/n4-wave3-draft-tts-stt-assist-run-2026-05-27.md
```

## Summary

| Metric | Result |
|---|---:|
| Total targets | 45 |
| Machine pass | 27 |
| Blocked targets | 18 |
| Warning count | 21 |
| Transcribed targets | 27 |
| STT exact matches | 6 |
| STT mismatches | 21 |
| STT errors | 18 |
| Duration min | 1.437s |
| Duration max | 7.288s |
| Duration average | 3.404s |
| Total audio duration | 153.184s |

## Provider Models

- `elevenlabs/eleven_multilingual_v2`: 45

## Blockers

- HN4-019 question:4: TRANSCRIPTION_FAILED:TimeoutError:
- HN4-020 script:1: TRANSCRIPTION_FAILED:TimeoutError:
- HN4-020 script:2: TRANSCRIPTION_FAILED:TimeoutError:
- HN4-020 script:3: TRANSCRIPTION_FAILED:TimeoutError:
- HN4-020 question:1: TRANSCRIPTION_FAILED:TimeoutError:
- HN4-020 question:2: TRANSCRIPTION_FAILED:TimeoutError:
- HN4-020 question:3: TRANSCRIPTION_FAILED:TimeoutError:
- HN4-020 question:4: TRANSCRIPTION_FAILED:TimeoutError:
- HN4-020 question:5: TRANSCRIPTION_FAILED:TimeoutError:
- HN4-021 script:0: TRANSCRIPTION_FAILED:TimeoutError:
- HN4-021 script:1: TRANSCRIPTION_FAILED:TimeoutError:
- HN4-021 script:2: TRANSCRIPTION_FAILED:TimeoutError:
- HN4-021 script:3: TRANSCRIPTION_FAILED:TimeoutError:
- HN4-021 question:1: TRANSCRIPTION_FAILED:TimeoutError:
- HN4-021 question:2: TRANSCRIPTION_FAILED:TimeoutError:
- HN4-021 question:3: TRANSCRIPTION_FAILED:TimeoutError:
- HN4-021 question:4: TRANSCRIPTION_FAILED:TimeoutError:
- HN4-021 question:5: TRANSCRIPTION_FAILED:TimeoutError:

## Review-Priority Warnings

- HN4-017 script:1: TRANSCRIPTION_TEXT_MISMATCH:忙しい
- HN4-017 question:1: TRANSCRIPTION_TEXT_MISMATCH:サウジ
- HN4-017 question:2: TRANSCRIPTION_TEXT_MISMATCH:シータクエソン
- HN4-017 question:3: TRANSCRIPTION_TEXT_MISMATCH:掃除をし、なつじを、洗濯をし、にぞうをします。
- HN4-017 question:4: TRANSCRIPTION_TEXT_MISMATCH:文脈さん準備に該当するマルは来週のあやをしたりします。
- HN4-017 question:5: TRANSCRIPTION_TEXT_MISMATCH:チョンソをハゴナ、パレロハゴナ、ハムニダを配列ハセヨ。
- HN4-018 script:0: TRANSCRIPTION_TEXT_MISMATCH:この議会は壊れそう。
- HN4-018 script:2: TRANSCRIPTION_TEXT_MISMATCH:別の機会なら操作が簡単そうです。
- HN4-018 script:3: TRANSCRIPTION_TEXT_MISMATCH:てんたかさんも大変そうですね。早めに相談しましょう。
- HN4-018 question:1: TRANSCRIPTION_TEXT_MISMATCH:チゲを釣る
- HN4-018 question:2: TRANSCRIPTION_TEXT_MISMATCH:ウリエトシン
- HN4-018 question:3: TRANSCRIPTION_TEXT_MISMATCH:この機械は壊れいつかです
- HN4-018 question:4: TRANSCRIPTION_TEXT_MISMATCH:目の前の状態を見て推測するとき、알맞은 표현은
- HN4-018 question:5: TRANSCRIPTION_TEXT_MISMATCH:この機械は故障しそうですを配列してください
- HN4-019 script:0: TRANSCRIPTION_TEXT_MISMATCH:明日の会議は3時から始まるそうです。
- HN4-019 script:3: TRANSCRIPTION_TEXT_MISMATCH:てくてはさおむそうですから早く行きましょう。
- HN4-019 question:1: TRANSCRIPTION_TEXT_MISMATCH:ゆていえいえん
- HN4-019 question:2: TRANSCRIPTION_TEXT_MISMATCH:ドプロエトン
- HN4-019 question:3: TRANSCRIPTION_TEXT_MISMATCH:会議は3時から始まるです。
- HN4-019 question:5: TRANSCRIPTION_TEXT_MISMATCH:「しおむん しゅぷだご はみだ」をべよるはせよ
- HN4-020 script:0: TRANSCRIPTION_TEXT_MISMATCH:約束は守るもの。

## STT Mismatches

| Target | Source text | STT transcript | Strict blocker mode | Audio |
|---|---|---|---|---|
| HN4-017 script:1 | 忙しいですね。 | 忙しい | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/script-line-1.mp3 |
| HN4-017 question:1 | 掃除의 뜻은? | サウジ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-1.mp3 |
| HN4-017 question:2 | 洗濯의 뜻은? | シータクエソン | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-2.mp3 |
| HN4-017 question:3 | 掃除をし___、洗濯をし___します。 | 掃除をし、なつじを、洗濯をし、にぞうをします。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-3.mp3 |
| HN4-017 question:4 | 문맥상 '준비'에 해당하는 말은? 来週の___をしたりします。 | 文脈さん準備に該当するマルは来週のあやをしたりします。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-4.mp3 |
| HN4-017 question:5 | '청소를 하거나 빨래를 하거나 합니다'를 배열하세요. | チョンソをハゴナ、パレロハゴナ、ハムニダを配列ハセヨ。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/c66e28bc-0e77-4989-83d4-148611906230/question-5.mp3 |
| HN4-018 script:0 | この機械は壊れそうです。 | この議会は壊れそう。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-0.mp3 |
| HN4-018 script:2 | 別の機械なら操作が簡単そうです。 | 別の機会なら操作が簡単そうです。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-2.mp3 |
| HN4-018 script:3 | 田中さんも大変そうです。早めに相談しましょう。 | てんたかさんも大変そうですね。早めに相談しましょう。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/script-line-3.mp3 |
| HN4-018 question:1 | 機械의 뜻은? | チゲを釣る | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-1.mp3 |
| HN4-018 question:2 | 無理의 뜻은? | ウリエトシン | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-2.mp3 |
| HN4-018 question:3 | この機械は壊れ___です。 | この機械は壊れいつかです | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-3.mp3 |
| HN4-018 question:4 | 눈앞의 상태를 보고 추측할 때 알맞은 표현은? | 目の前の状態を見て推測するとき、알맞은 표현은 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-4.mp3 |
| HN4-018 question:5 | '이 기계는 고장 날 것 같습니다'를 배열하세요. | この機械は故障しそうですを配列してください | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/b68d0a77-31f9-4061-8e22-baedb02367f7/question-5.mp3 |
| HN4-019 script:0 | 明日の会議は三時から始まるそうです。 | 明日の会議は3時から始まるそうです。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-0.mp3 |
| HN4-019 script:3 | 受付は混むそうですから、早く行きましょう。 | てくてはさおむそうですから早く行きましょう。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/script-line-3.mp3 |
| HN4-019 question:1 | 予定의 뜻은? | ゆていえいえん | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-1.mp3 |
| HN4-019 question:2 | 受付의 뜻은? | ドプロエトン | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-2.mp3 |
| HN4-019 question:3 | 会議は三時から始まる___です。 | 会議は3時から始まるです。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-3.mp3 |
| HN4-019 question:5 | '시험은 쉽다고 합니다'를 배열하세요. | 「しおむん しゅぷだご はみだ」をべよるはせよ | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/50d21797-c2c3-40ed-8641-db05efa0578d/question-5.mp3 |
| HN4-020 script:0 | 約束は守るものです。 | 約束は守るもの。 | no | https://storage.googleapis.com/harukoto-storage/tts/lesson/8d0b1638-2521-4556-964f-29023d1dbcef/script-line-0.mp3 |

## Decision

BLOCK: resolve machine/STT blockers before considering broader rollout.
