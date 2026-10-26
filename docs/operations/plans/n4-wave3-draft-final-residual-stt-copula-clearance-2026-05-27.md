# N4 Wave 3 Draft Final Residual STT Copula Clearance

> Date: 2026-05-27
> Status: FINAL AI-ASSISTED PASS CSV GENERATED
> Boundary: delegated AI/STT audio QA only; not native-speaker approval

ASSUMPTION: The project owner delegated this final DRAFT audio QA because
no human/native-speaker reviewer is currently available. This clearance
applies only to residual STT mismatches where the regenerated MP3 probe
passes and STT omits only the final polite copula `です`.

## Sources

- `docs/operations/plans/n4-wave3-draft-final-source-rewrite-second-post-regeneration-audit-2026-05-27.md`
- `docs/operations/plans/n4-wave3-draft-final-source-rewrite-second-post-regeneration-recommendations-2026-05-27.csv`
- `docs/operations/plans/n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md`

## Clearance Rows

| Target | Source text | STT transcript | Decision basis |
|---|---|---|---|
| `HN4-020 script:0` | 学校の約束は最後まで守るものです。 | 学校の約束は最後まで守るもの。 | MP3 probe passed; STT preserved the `もの` grammar stem and omitted only final `です`. |
| `HN4-021 script:0` | 予約したので、席はまだあるはずです。 | 予約したので、席はまだあるはず。 | MP3 probe passed; STT preserved the `はず` grammar stem and omitted only final `です`. |

## Apply Command

```bash
cd apps/api
uv run python scripts/apply_n4_audio_qa_verdicts.py \
  --csv-input ../../docs/operations/plans/n4-wave3-draft-final-residual-stt-copula-clearance-2026-05-27.csv \
  --write
```

## Decision

Apply these rows to close the CH05 DRAFT audio QA packet at zero
`PENDING`, `FLAG`, or `FAIL` rows. This does not convert the packet into
native-speaker approval; it records the AI-assisted gate used before an
early product opening.
