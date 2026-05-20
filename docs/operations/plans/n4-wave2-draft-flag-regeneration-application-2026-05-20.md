# N4 Wave 2 Draft FLAG Regeneration Application

> Status: 3 regenerated, 3 remain FLAG
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: The project owner delegated the post-regeneration review because no
human/native-speaker reviewer is currently available. A regenerated row stays
blocking when STT still reports a source mismatch.

## Inputs

- Packet: `docs/operations/plans/n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md`
- Regeneration manifest: `docs/operations/plans/n4-wave2-draft-flag-regeneration-plan-2026-05-20.csv`
- Dry-run result: `docs/operations/plans/n4-wave2-draft-flag-regeneration-dry-run-2026-05-20.csv`
- Published-filter failure record: `docs/operations/plans/n4-wave2-draft-flag-regeneration-published-filter-failed-2026-05-20.csv`
- Execution result: `docs/operations/plans/n4-wave2-draft-flag-regeneration-results-2026-05-20.csv`
- Current DB result snapshot: `docs/operations/plans/n4-wave2-draft-flag-current-db-results-2026-05-20.csv`
- Post-regeneration audit: `docs/operations/plans/n4-wave2-draft-flag-post-regeneration-audit-2026-05-20.md`
- Post-regeneration recommendations: `docs/operations/plans/n4-wave2-draft-flag-post-regeneration-recommendations-2026-05-20.csv`

## Harness Update

`scripts/regenerate_n4_audio_qa_flagged_tts.py` now supports
`--include-unpublished`, matching the existing DRAFT-only behavior in the N4
TTS generation and audio packet scripts. The default path still requires
`is_published=true`; DRAFT regeneration must opt in explicitly.

The first execution without `--include-unpublished` failed before TTS/provider
calls because the Chapter 4 lessons are intentionally DRAFT:

| Metric | Count |
|---|---:|
| Planned targets | 3 |
| Regenerated | 0 |
| Failed before generation | 3 |

## Regeneration Command

```bash
cd apps/api
uv run python scripts/regenerate_n4_audio_qa_flagged_tts.py \
  --manifest ../../docs/operations/plans/n4-wave2-draft-flag-regeneration-plan-2026-05-20.csv \
  --include-unpublished \
  --run-id 20260520T104500Z \
  --result-output ../../docs/operations/plans/n4-wave2-draft-flag-regeneration-results-2026-05-20.csv \
  --execute \
  --continue-on-error
```

## Regeneration Result

| Metric | Count |
|---|---:|
| Planned targets | 3 |
| Regenerated | 3 |
| Failed | 0 |
| Run id | `20260520T104500Z` |

## Post-Regeneration Audit

| Metric | Count |
|---|---:|
| Machine pass | 3 |
| STT exact matches | 0 |
| STT mismatches | 3 |
| Recommended PASS | 0 |
| Recommended FLAG | 3 |

## Remaining FLAG Targets

| Target | Japanese text | Post-regeneration STT signal |
|---|---|---|
| `HN4-013 script:1` | 分からなければ、受付で聞いてみましょう。 | 分からなければ 手ホクで聞いてみましょう。 |
| `HN4-013 script:2` | 案内の紙も読んでみます。 | 案内の下を読んでみます。 |
| `HN4-015 script:1` | それは心配ですね。 | それは心配です |

## Applied Packet State

The packet now points these three rows at the regenerated audio URLs and keeps
their verdicts as `FLAG`. `scripts/report_n4_audio_qa_verdicts.py` reports:

- `targets 45`
- `pass 42`
- `pending 0`
- `flag 3`
- `fail 0`
- blocker: `FLAG_VERDICTS: 3 target(s) need waiver or regeneration before broad rollout`

## Decision

Broad/full N4 rollout remains blocked. The next useful step is a small source
rewrite for these three DRAFT script lines, followed by another targeted TTS
regeneration and STT-assisted audit. This is preferable to repeatedly
regenerating the same hard-to-transcribe wording.
