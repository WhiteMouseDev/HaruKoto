# N4 Wave 2 Draft AI-Assisted Audio Verdicts

> Date: 2026-05-20
> Status: PARTIAL VERDICTS APPLIED
> Boundary: AI-assisted and machine/STT-assisted review only; not native-speaker approval

## Sources

- `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md`
- `docs/operations/plans/n4-wave2-draft-tts-machine-report-2026-05-20.md`
- `docs/operations/plans/n4-wave2-draft-tts-stt-assist-run-2026-05-20.md`
- `docs/operations/plans/n4-wave2-draft-stt-reconciliation-2026-05-20.md`
- `docs/operations/plans/n4-wave2-draft-delegated-pending-clearance-2026-05-20.md`
- `docs/operations/plans/n4-wave2-draft-pass-candidates-2026-05-20.md`

## Decision

Apply 42 AI-assisted `PASS` verdicts and keep 3 rows as `FLAG`.

PASS rows fall into one of these lanes:

- 24 mixed Japanese/Korean/cloze prompt rows where STT mismatch is weak
  evidence and machine audio probe passed.
- 16 script rows with machine audio pass and no parsed STT or machine review
  signal.
- `HN4-016 script:3`, where the STT difference is kana/kanji and punctuation
  normalization rather than a content mismatch.
- `HN4-015 question:4`, where the cloze blank explains the pause and omitted
  blank in STT; the machine probe otherwise passed.

FLAG rows remain because the STT signal points to a plausible lexical audio
risk that should be regenerated or directly listened to before rollout:

| Target | Source | STT signal | Reason |
|---|---|---|---|
| `HN4-013 script:1` | `分からなければ、受付で聞いてみましょう。` | `わからなければ、ふふで聞いてみましょう。` | `受付` may be unclear |
| `HN4-013 script:2` | `案内の紙も読んでみます。` | `案内のおせも読んでみます。` | `紙` may be unclear |
| `HN4-015 script:1` | `それは心配ですね。` | `それは新米です。` | `心配` lexical mismatch |

## Apply Command

```bash
cd apps/api
uv run python scripts/apply_n4_audio_qa_verdicts.py \
  --csv-input ../../docs/operations/plans/n4-wave2-draft-delegated-pending-clearance-2026-05-20.csv \
  --write
uv run python scripts/apply_n4_audio_qa_verdicts.py \
  --csv-input ../../docs/operations/plans/n4-wave2-draft-ai-assisted-verdicts-2026-05-20.csv \
  --write
```

## Expected Verdict State

| Verdict | Count |
|---|---:|
| PASS | 42 |
| FLAG | 3 |
| PENDING | 0 |
| FAIL | 0 |

## Next Gate

Regenerate or directly adjudicate the 3 `FLAG` rows before moving `N4-CH04`
from `DRAFT` to `PILOT`.
