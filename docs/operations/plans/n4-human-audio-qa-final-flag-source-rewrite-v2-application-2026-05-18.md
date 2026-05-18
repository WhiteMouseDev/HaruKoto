# N4 Final FLAG Source Rewrite v2 Application

> Status: SOURCE REWRITE V2 APPLIED - rollout still HOLD
> Scope: the two N4 script-line rows that remained `FLAG` after final same-source regeneration
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: The source rewrite v2 wording is the safer product source for the
remaining two targets because same-source regeneration repeatedly produced STT
divergence. However, STT mismatch after regeneration is not sufficient evidence
to clear a row to `PASS`.

## Source Changes

| Target | Previous source | Source rewrite v2 | Korean/context |
|---|---|---|---|
| HN4-006 script:0 | `水の深さを確認しました。` | `この川の深さを確認しました。` | 이 강의 깊이를 확인했습니다. |
| HN4-011 script:1 | `厚さが違う紙がありますね。` | `紙の厚さが違いますね。` | 종이의 두께가 다르네요. |

## Regeneration Result

| Target | Audio run | Machine probe | STT signal | Verdict |
|---|---|---:|---|---|
| HN4-006 script:0 | `20260518T021000Z` | PASS | `TRANSCRIPTION_TEXT_MISMATCH:この刃の重さを確認しました。` | FLAG |
| HN4-011 script:1 | `20260518T021000Z` | PASS | `TRANSCRIPTION_TEXT_MISMATCH:雉の網坂違います。` | FLAG |

## Question Prompt TTS Refresh

HN4-006 question prompts also changed from the previous lake/water context to
the river context, so their cached runtime TTS rows were refreshed without
changing the human review verdict.

| Target | New text | Audio run | Packet verdict |
|---|---|---|---|
| HN4-006 question:3 | `川の深___を確認します。 (강의 깊이를 확인합니다.)` | `20260518T021500Z` | PENDING |
| HN4-006 question:5 | `'강의 깊이를 확인했습니다'를 배열하세요.` | `20260518T021500Z` | PENDING |

## Packet Summary After Application

| Metric | Result |
|---|---:|
| Packets | 3 |
| Targets | 99 |
| PASS | 35 |
| PENDING | 62 |
| FLAG | 2 |
| FAIL | 0 |
| WAIVED | 0 |
| Invalid verdicts | 0 |

## Artifacts

- `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v2-regeneration-plan-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v2-regeneration-dry-run-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v2-regeneration-results-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v2-post-regeneration-review-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v2-post-regeneration-recommendations-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v2-post-regeneration-audit-2026-05-18.md`
- `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v2-question-tts-regeneration-plan-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v2-question-tts-regeneration-dry-run-2026-05-18.csv`
- `docs/operations/plans/n4-human-audio-qa-final-flag-source-rewrite-v2-question-tts-regeneration-results-2026-05-18.csv`

## Decision

Keep both rows as `FLAG`. The source content is now cleaner and DB/TTS are
updated, but broad N4 audio rollout remains blocked until these two rows are
cleared by direct listening review, another provider/voice pass, or an explicit
waiver.
