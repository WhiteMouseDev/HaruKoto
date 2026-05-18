# N4 FLAG Post-Regeneration Verdict Application

> Status: 1 PASS applied, 7 FLAG notes refreshed, 8 regenerated audio links synced
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: The project owner delegated this post-regeneration review because
no human/native-speaker reviewer is currently available. Only the row with
`machine pass + exact STT/source match` was moved to `PASS`; regenerated rows
with remaining STT divergence stayed `FLAG`.

## Inputs

- Audit report: `docs/operations/plans/n4-human-audio-qa-flag-post-regeneration-audit-2026-05-18.md`
- Apply CSV: `docs/operations/plans/n4-human-audio-qa-flag-post-regeneration-recommendations-2026-05-18.csv`
- Review CSV source: `docs/operations/plans/n4-human-audio-qa-flag-post-regeneration-review-2026-05-14.csv`
- Regeneration result source: `docs/operations/plans/n4-human-audio-qa-flag-regeneration-results-2026-05-14.csv`

## Apply Command

```bash
cd apps/api && uv run python scripts/apply_n4_audio_qa_verdicts.py \
  --csv-input ../../docs/operations/plans/n4-human-audio-qa-flag-post-regeneration-recommendations-2026-05-18.csv \
  --write
```

## Apply Result

| Metric | Count |
|---|---:|
| CSV updates | 8 |
| Matched packet rows | 8 |
| Changed packet rows | 8 |
| Regenerated audio links synced | 8 |
| Applied PASS | 1 |
| Retained FLAG | 7 |

Changed packets:

- `docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md`
- `docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md`
- `docs/operations/plans/n4-pilot-human-audio-qa-ch03-2026-05-13.md`

## PASS Target

| Target | Japanese text | Evidence |
|---|---|---|
| HN4-008 script:0 | 返事が遅れてすみません。 | MP3 probe passed and STT matched source exactly |

All 8 packet rows now point at the regenerated `script-line-*-regen-20260514T083500Z.mp3`
audio URLs used by the audit.

## Remaining FLAG Targets

| Target | Japanese text | Remaining signal |
|---|---|---|
| HN4-001 script:3 | 分かりました。丁寧に確認します。 | STT transcript: 分かりました。店主に確認します。 |
| HN4-003 script:1 | じゃあ、会議に間に合わないかもしれませんね。 | STT transcript: じゃ、会議に間に合わないかもしれませんね。 |
| HN4-004 script:3 | 諦めないで、急いで行きましょう。 | STT transcript: ひじめないで 清いでいきましょう |
| HN4-006 script:0 | 湖の深さを地図で確認しました。 | STT transcript: このマーサを実で確認しました。 |
| HN4-006 script:2 | はい。線の太さや細さも見られます。 | STT transcript: はい、線の太さや磯さも見られる。 |
| HN4-010 script:3 | 荷物が届くと、メールが来ます。 | STT transcript: 何もつか届くとミールが来ます |
| HN4-011 script:1 | 厚い紙と薄い紙がありますね。 | STT transcript: 藍石と薄石があります |

## Post-Apply Verdict Report

`scripts/report_n4_audio_qa_verdicts.py` reports:

- `targets 99`
- `pass 30`
- `pending 62`
- `flag 7`
- `fail 0`
- blocker: `PENDING_VERDICTS: 62 target(s) still need human verdicts`
- blocker: `FLAG_VERDICTS: 7 target(s) need waiver or regeneration before broad rollout`

## Decision

The regenerated audio batch improved one row enough for delegated AI-assisted
`PASS`, but did not clear the FLAG bucket. Broad N4 audio rollout remains
blocked by 62 pending rows and 7 regenerated rows that still need another
regeneration pass, direct listening review, or explicit waiver.
