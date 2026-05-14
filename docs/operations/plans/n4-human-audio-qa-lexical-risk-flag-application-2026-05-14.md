# N4 Human Audio QA Lexical-Risk FLAG Application

Date: 2026-05-14
Scope: 8 `LEXICAL_RISK` script rows from the N4 pilot human audio QA packets
Status: Applied as conservative `FLAG` verdicts

## Review Boundary

This is a delegated AI-assisted conservative blocker pass, not a native-speaker
or direct-listening `PASS` review.

ASSUMPTION: The owner delegated AI-assisted triage for rows where STT/source
lexical divergence suggests possible wrong-word audio. These rows should remain
blocked until regeneration, direct listening, or an explicit waiver confirms the
audio is acceptable for broad rollout.

## Inputs

- Source batch:
  `docs/operations/plans/n4-human-audio-qa-lexical-risk-review-2026-05-14.csv`
- Reviewed update CSV:
  `docs/operations/plans/n4-human-audio-qa-lexical-risk-flags-reviewed-2026-05-14.csv`
- Apply command:
  `cd apps/api && uv run python scripts/apply_n4_audio_qa_verdicts.py --csv-input ../../docs/operations/plans/n4-human-audio-qa-lexical-risk-flags-reviewed-2026-05-14.csv --write`

Applied note:

`Delegated AI-assisted FLAG: STT/source lexical divergence suggests possible wrong-word audio; regenerate or direct-listen before broad rollout; not native-speaker review.`

## Applied Targets

| Target | Packet | Source text | STT transcript | Similarity | Applied verdict |
|---|---|---|---|---|---|
| HN4-001 script:3 | `n4-pilot-human-audio-qa-ch01-2026-05-13.md` | 分かりました。丁寧に確認します。 | わかりました。定時に確認します。 | 0.759 | FLAG |
| HN4-003 script:1 | `n4-pilot-human-audio-qa-ch01-2026-05-13.md` | じゃあ、会議に間に合わないかもしれませんね。 | じゃあ、会計に値に合わないかもしれないですね。 | 0.732 | FLAG |
| HN4-004 script:3 | `n4-pilot-human-audio-qa-ch01-2026-05-13.md` | 諦めないで、急いで行きましょう。 | 始めないで競いに行きましょう | 0.786 | FLAG |
| HN4-006 script:0 | `n4-pilot-human-audio-qa-ch02-2026-05-13.md` | 湖の深さを地図で確認しました。 | 骨の傘を実で確認しました。 | 0.692 | FLAG |
| HN4-006 script:2 | `n4-pilot-human-audio-qa-ch02-2026-05-13.md` | はい。線の太さや細さも見られます。 | はい。不当操作や操作もみられます。 | 0.533 | FLAG |
| HN4-008 script:0 | `n4-pilot-human-audio-qa-ch02-2026-05-13.md` | 返事が遅れてすみません。 | 半時が遅れてすみません。 | 0.783 | FLAG |
| HN4-010 script:3 | `n4-pilot-human-audio-qa-ch02-2026-05-13.md` | 荷物が届くと、メールが来ます。 | 何か届くとメールが来ます。 | 0.800 | FLAG |
| HN4-011 script:1 | `n4-pilot-human-audio-qa-ch03-2026-05-13.md` | 厚い紙と薄い紙がありますね。 | 石と薄い石があります。 | 0.696 | FLAG |

## Post-Apply Verdict State

`scripts/report_n4_audio_qa_verdicts.py` after application:

```text
packets 3
targets 99
pass 26
pending 65
flag 8
fail 0
waived 0
invalid 0
packet_details
- ch01: total=45 pass=12 pending=30 flag=3 fail=0 waived=0 invalid=0
- ch02: total=45 pass=13 pending=28 flag=4 fail=0 waived=0 invalid=0
- ch03: total=9 pass=1 pending=7 flag=1 fail=0 waived=0 invalid=0
blockers
- PENDING_VERDICTS: 65 target(s) still need human verdicts
- FLAG_VERDICTS: 8 target(s) need waiver or regeneration before broad rollout
```

## Rollout Decision

Broad/full N4 rollout remains on hold. The 8 lexical-risk rows now have
explicit blocker verdicts instead of ambiguous `PENDING` rows, while 65 other
targets still need review verdicts.
