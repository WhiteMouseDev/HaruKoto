# N4 Post-Regeneration Audio Audit

> Status: REVIEW
> Scope: regenerated audio URLs from the supplied post-regeneration review CSV
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: The project owner delegated this post-regeneration review because no human/native-speaker reviewer is currently available.

## Command

```bash
uv run python scripts/audit_n4_flag_post_regeneration_audio.py --review-csv ../../docs/operations/plans/n4-human-audio-qa-p0-machine-warning-provider-fallback-post-regeneration-review-2026-05-18.csv --regeneration-results-csv ../../docs/operations/plans/n4-human-audio-qa-p0-machine-warning-provider-fallback-regeneration-results-final-2026-05-18.csv --transcribe --current-verdict PENDING --csv-output ../../docs/operations/plans/n4-human-audio-qa-p0-machine-warning-provider-fallback-post-regeneration-recommendations-2026-05-18.csv --markdown-output ../../docs/operations/plans/n4-human-audio-qa-p0-machine-warning-provider-fallback-post-regeneration-audit-2026-05-18.md
```

## Inputs

- Review CSV: `docs/operations/plans/n4-human-audio-qa-p0-machine-warning-provider-fallback-post-regeneration-review-2026-05-18.csv`
- Regeneration results CSV: `docs/operations/plans/n4-human-audio-qa-p0-machine-warning-provider-fallback-regeneration-results-final-2026-05-18.csv`

## Summary

| Metric | Result |
|---|---:|
| Total targets | 11 |
| Machine pass | 11 |
| Blocked targets | 0 |
| Warning count | 12 |
| Transcribed targets | 11 |
| STT exact matches | 0 |
| STT mismatches | 11 |
| STT errors | 0 |
| Recommended PASS | 0 |
| Recommended FLAG | 11 |
| Unresolved/no recommendation | 0 |

## Recommendations

| Target | Japanese text | STT transcript | Signals | Recommendation | Audio |
|---|---|---|---|---|---|
| HN4-001 question:3 | 名前を書き___. (이름을 쓰세요.) | なまえを | TRANSCRIPTION_TEXT_MISMATCH:なまえを | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/b544d1f5-8089-45f8-b3d9-6428b60a0ece/question-3-regen-20260518T055500Z.mp3) |
| HN4-002 question:4 | 医者に相談___。 (의사와 상담하는 편이 좋습니다.) | ガイさんボイ | TRANSCRIPTION_TEXT_MISMATCH:ガイさんボイ | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/89433566-b321-4f99-ac20-9ffb87e69d6b/question-4-regen-20260518T055500Z.mp3) |
| HN4-003 question:3 | 電車が遅れる___。 (전철이 늦을지도 모릅니다.) | 전철이 늦을지도 | TRANSCRIPTION_TEXT_MISMATCH:전철이 늦을지도 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-3-regen-20260518T055500Z.mp3) |
| HN4-003 question:4 | 間に合わない___。 (시간에 맞지 못할지도 모릅니다.) | カニ合わない | HIGH_SILENCE_RATIO:0.3725, TRANSCRIPTION_TEXT_MISMATCH:カニ合わない | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/82d7334e-c4c4-4102-86ea-7be9b3218bce/question-4-regen-20260518T041500Z.mp3) |
| HN4-004 question:4 | 電車に乗る___。 (전철을 탈 수밖에 없습니다.) | 電車を乗るしかない。 | TRANSCRIPTION_TEXT_MISMATCH:電車を乗るしかない。 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/8368ee77-eeb8-48b2-9c81-2cfd597e5f7a/question-4-regen-20260518T055500Z.mp3) |
| HN4-005 question:4 | 文を翻訳___。 (문장을 번역할 수 있습니다.) | 文を翻訳 マチタ ムンジャンを翻訳することができます | TRANSCRIPTION_TEXT_MISMATCH:文を翻訳 マチタ ムンジャンを翻訳することができます | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/17851e67-db52-41b8-a651-d416251b0ead/question-4-regen-20260518T041500Z.mp3) |
| HN4-006 question:4 | 線の太___を見ます。 (선의 굵기를 봅니다.) | 線の太さを見ます。 | TRANSCRIPTION_TEXT_MISMATCH:線の太さを見ます。 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/question-4-regen-20260518T055500Z.mp3) |
| HN4-008 question:3 | 会議が長かった___。 (회의가 길었던 거예요.) | 会議が長かった | TRANSCRIPTION_TEXT_MISMATCH:会議が長かった | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/78e8b581-c81d-4465-b49d-cf0e4b49db4a/question-3-regen-20260518T055500Z.mp3) |
| HN4-009 question:4 | 就職する___、準備します。 (취직하기 위해 준비합니다.) | 就職する準備 | TRANSCRIPTION_TEXT_MISMATCH:就職する準備 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/3221de04-7925-47d9-880a-2adcabfc58b1/question-4-regen-20260518T055500Z.mp3) |
| HN4-010 question:4 | 信号が青になる___、車が進みます。 | 信号が青になる。車が進む。 | TRANSCRIPTION_TEXT_MISMATCH:信号が青になる。車が進む。 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/1445c28c-bd0c-4c0a-b8f7-2708c51acca7/question-4-regen-20260518T055500Z.mp3) |
| HN4-011 question:3 | 紙の厚___を比べます。 (종이의 두께를 비교합니다.) | 紙の厚みを比較 | TRANSCRIPTION_TEXT_MISMATCH:紙の厚みを比較 | FLAG | [audio](https://storage.googleapis.com/harukoto-storage/tts/lesson/03cfdb15-c916-450c-8168-9052f3e754aa/question-3-regen-20260518T055500Z.mp3) |

## Decision

REVIEW: keep unresolved regenerated rows as `FLAG` until the remaining signals are resolved by another regeneration or direct listening review.
