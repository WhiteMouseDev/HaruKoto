# N4 FLAG Second-Pass Regeneration Application

> Status: 1 PASS applied, 6 FLAG notes refreshed, 7 regenerated audio links synced
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: The project owner delegated this second-pass review because no
human/native-speaker reviewer is currently available. Only the row with
`machine pass + exact STT/source match` was moved to `PASS`; regenerated rows
with remaining STT divergence stayed `FLAG`.

## Inputs

- Second-pass manifest: `docs/operations/plans/n4-human-audio-qa-flag-regeneration-plan-second-pass-2026-05-18.csv`
- Dry-run result: `docs/operations/plans/n4-human-audio-qa-flag-regeneration-second-pass-dry-run-2026-05-18.csv`
- Dry-run check result: `docs/operations/plans/n4-human-audio-qa-flag-regeneration-second-pass-dry-run-check-2026-05-18.csv`
- Execution result: `docs/operations/plans/n4-human-audio-qa-flag-regeneration-second-pass-results-2026-05-18.csv`
- Audit report: `docs/operations/plans/n4-human-audio-qa-flag-second-pass-audit-2026-05-18.md`
- Apply CSV: `docs/operations/plans/n4-human-audio-qa-flag-second-pass-recommendations-2026-05-18.csv`

## Regeneration Command

```bash
cd apps/api && uv run python scripts/regenerate_n4_audio_qa_flagged_tts.py \
  --manifest docs/operations/plans/n4-human-audio-qa-flag-regeneration-plan-second-pass-2026-05-18.csv \
  --run-id 20260518T004000Z \
  --execute \
  --continue-on-error \
  --result-output /Users/kimkunwoo/WhiteMouseDev/japanese/docs/operations/plans/n4-human-audio-qa-flag-regeneration-second-pass-results-2026-05-18.csv
```

## Regeneration Result

| Metric | Count |
|---|---:|
| Planned targets | 7 |
| Regenerated | 7 |
| Failed | 0 |
| Run id | 20260518T004000Z |

## Audit Result

| Metric | Count |
|---|---:|
| Machine pass | 7 |
| STT exact matches | 1 |
| STT mismatches | 6 |
| Recommended PASS | 1 |
| Recommended FLAG | 6 |

## Apply Command

```bash
cd apps/api && uv run python scripts/apply_n4_audio_qa_verdicts.py \
  --csv-input ../../docs/operations/plans/n4-human-audio-qa-flag-second-pass-recommendations-2026-05-18.csv \
  --write
```

## Applied PASS Target

| Target | Japanese text | Evidence |
|---|---|---|
| HN4-003 script:1 | じゃあ、会議に間に合わないかもしれませんね。 | MP3 probe passed and STT matched source exactly |

## Remaining FLAG Targets

| Target | Japanese text | Remaining signal |
|---|---|---|
| HN4-001 script:3 | 分かりました。丁寧に確認します。 | STT transcript: わかりました。艇中に確認します。 |
| HN4-004 script:3 | 諦めないで、急いで行きましょう。 | STT transcript: 責めないで築いでいきましょう |
| HN4-006 script:0 | 湖の深さを地図で確認しました。 | STT transcript: 小野真央を実で確認しました。 |
| HN4-006 script:2 | はい。線の太さや細さも見られます。 | STT transcript: はい、洗脳邸さや石さもみられます。 |
| HN4-010 script:3 | 荷物が届くと、メールが来ます。 | STT transcript: 何もずが届くとミールが来ます。 |
| HN4-011 script:1 | 厚い紙と薄い紙がありますね。 | STT transcript: 小財地と薄石があります |

## Post-Apply Verdict Report

`scripts/report_n4_audio_qa_verdicts.py` reports:

- `targets 99`
- `pass 31`
- `pending 62`
- `flag 6`
- `fail 0`
- blocker: `PENDING_VERDICTS: 62 target(s) still need human verdicts`
- blocker: `FLAG_VERDICTS: 6 target(s) need waiver or regeneration before broad rollout`

## Decision

The second-pass regeneration cleared one additional FLAG row, but it did not
clear the bucket. Broad N4 audio rollout remains blocked by 62 pending rows and
6 regenerated rows that still need another regeneration pass, direct listening
review, or explicit waiver.
