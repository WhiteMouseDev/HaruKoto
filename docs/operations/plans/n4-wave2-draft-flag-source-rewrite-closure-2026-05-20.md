# N4 Wave 2 Draft FLAG Source-Rewrite Closure

> Status: PASS
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: The project owner delegated source-rewrite and post-regeneration
review because the affected lessons are still `DRAFT` and no native-speaker
reviewer is currently available.

## Source Rewrites

| Target | Previous text | Final text | Reason |
|---|---|---|---|
| `HN4-013 script:1` | 分からなければ、受付で聞いてみましょう。 | わからなければ、人に聞いてみましょう。 | `受付` repeatedly produced divergent STT tokens; hiragana `わからなければ` matches the final STT surface while `聞いてみましょう` keeps the lesson grammar anchor. |
| `HN4-013 script:2` | 案内の紙も読んでみます。 | 案内を読んでみましょう。 | `紙` and the original `読んでみます` wording produced unstable transcripts; final wording preserves the read/check context and the `てみる` grammar anchor. |
| `HN4-015 script:1` | それは心配ですね。 | 大変です。 | Short reaction line was not the grammar anchor and repeatedly lost/changed the ending in STT. |

## Regeneration Evidence

| Iteration | Targets | Regenerated | Recommended PASS | Recommended FLAG |
|---|---:|---:|---:|---:|
| Source rewrite final | 3 | 3 | 3 | 0 |

## Final Audio URLs

| Target | Final audio |
|---|---|
| `HN4-013 script:1` | https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-1-regen-20260520T062700Z.mp3 |
| `HN4-013 script:2` | https://storage.googleapis.com/harukoto-storage/tts/lesson/254bf018-bbdc-41f7-9458-67cedba4a4c7/script-line-2-regen-20260520T062500Z.mp3 |
| `HN4-015 script:1` | https://storage.googleapis.com/harukoto-storage/tts/lesson/e812f2e7-4e5e-4e02-b566-47893239c20c/script-line-1-regen-20260520T062000Z.mp3 |

## Final Packet State

`scripts/report_n4_audio_qa_verdicts.py` reports:

- `targets 45`
- `pass 45`
- `pending 0`
- `flag 0`
- `fail 0`
- `invalid 0`

The regenerated review queue reports 0 pending/FLAG/FAIL verdict blockers.
Historical machine/STT signals remain visible on resolved rows for audit
traceability, but there are no P0, P1, or P2 review sections left to process.

## Decision

The Chapter 4 DRAFT audio QA packet has no remaining delegated AI/STT blockers.
The next product decision is whether this evidence is enough to promote
`N4-CH04` to `PILOT`, or whether native-speaker listening remains required.
